import { enqueue, listActive } from './queue'
import { applyOptimistic, cacheKey, extractDocs, hospitalityDocs, rememberHospitality } from './optimistic'
import { classifyWrite, isCacheableRead, isRecord, referencedIds, versionTarget } from './policy'

export { isCacheableRead }
import { readSnapshot, saveSnapshot } from './storage'
import type { OfflineDomain, OfflineTransaction } from './types'
import { isUuid, newUuid } from './uuid'

export interface WriteDecision {
  passthrough: boolean
  response?: unknown
}

type Send = (path: string, method: string, body: unknown, uuid: string) => Promise<unknown>

const listeners = new Set<() => void>()

export function onQueueChanged(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function notify() {
  listeners.forEach((listener) => listener())
}

export function isQueuedResponse(value: unknown): boolean {
  if (!isRecord(value)) return false
  const nested = isRecord(value.data) ? value.data.offline : undefined
  const own = value.offline
  return (isRecord(own) && own.queued === true) || (isRecord(nested) && nested.queued === true)
}

export function isTransientError(error: unknown): boolean {
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return true
  if (error instanceof TypeError) return true
  if (error && typeof error === 'object' && 'status' in error) {
    const status = Number((error as { status: number }).status)
    return status === 0 || status === 502 || status === 503 || status === 504
  }
  return false
}

export async function rememberRead(path: string, body: unknown): Promise<void> {
  if (!isCacheableRead(path)) return
  await saveSnapshot(cacheKey(path), body)
  if (path.startsWith('/hospitality')) await rememberHospitality(path, body)
}

export async function cachedRead(path: string): Promise<unknown | undefined> {
  const exact = await readSnapshot<unknown>(cacheKey(path))
  if (exact !== null) return exact
  if (path.startsWith('/hospitality')) {
    const latest = await readSnapshot<unknown>('hospitality:latest')
    if (latest !== null) return latest
  }
  return undefined
}

export async function interceptWrite(
  method: string,
  path: string,
  body: unknown,
  send: Send,
): Promise<WriteDecision> {
  const classified = classifyWrite(method, path, body)
  if (!classified) return { passthrough: true }

  const source = isRecord(body) ? body : {}
  const uuid = isUuid(source.idempotency_key)
    ? String(source.idempotency_key)
    : isUuid(source.client_uuid)
      ? String(source.client_uuid)
      : newUuid()
  const payload = enrich(classified.domain, classified.operation, source, uuid)
  const entityId = classified.entityId ?? uuid
  const baseVersion = await baseVersionFor(classified.operation, payload)
  const transaction = buildTransaction(uuid, classified.domain, classified.entityType, entityId, classified.operation, payload, baseVersion)

  if (await shouldQueue(payload, uuid)) {
    await enqueue(transaction)
    notify()
    return { passthrough: false, response: await synthetic(transaction) }
  }

  try {
    return { passthrough: false, response: await send(path, method, payload, uuid) }
  } catch (error) {
    if (!isTransientError(error)) throw error
    await enqueue(transaction)
    notify()
    return { passthrough: false, response: await synthetic(transaction) }
  }
}

function enrich(domain: OfflineDomain, operation: string, body: Record<string, unknown>, uuid: string): Record<string, unknown> {
  const payload = { ...body }
  if (domain === 'pos' && (operation === 'create' || operation === 'hold' || operation === 'update')) {
    if (!isUuid(payload.idempotency_key)) payload.idempotency_key = uuid
  }
  if (domain === 'restaurant' || domain === 'hotel') payload.client_uuid = uuid
  if (domain === 'cash_register') {
    payload.client_uuid = uuid
    if (operation === 'movement' && !isUuid(payload.reference_id)) payload.reference_id = uuid
  }
  return payload
}

async function shouldQueue(payload: Record<string, unknown>, uuid: string): Promise<boolean> {
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return true
  const pending = new Set((await listActive()).map((item) => item.uuid))
  return referencedIds(payload).some((id) => id !== uuid && pending.has(id))
}

async function baseVersionFor(operation: string, payload: Record<string, unknown>): Promise<string | null> {
  const code = versionTarget(operation, payload)
  if (!code) return null
  const doc = (await hospitalityDocs()).find((item) => item.id === code)
  return typeof doc?.updated_at === 'string' ? doc.updated_at : null
}

function buildTransaction(
  uuid: string,
  domain: OfflineDomain,
  entityType: string,
  entityId: string,
  operation: string,
  payload: Record<string, unknown>,
  baseVersion: string | null,
): OfflineTransaction {
  const now = new Date().toISOString()
  const idempotencyKey = isUuid(payload.idempotency_key) ? String(payload.idempotency_key) : uuid
  return {
    uuid,
    transactionId: null,
    idempotencyKey,
    domain,
    entityType,
    entityId,
    operation,
    payload,
    storeId: localStorage.getItem('pos_store_id'),
    baseVersion,
    status: 'pending',
    attempts: 0,
    lastError: null,
    conflict: null,
    createdAt: now,
    updatedAt: now,
    nextAttemptAt: null,
    serverId: null,
    alreadyProcessed: false,
  }
}

async function synthetic(transaction: OfflineTransaction): Promise<unknown> {
  const offline = { queued: true, uuid: transaction.uuid }
  if (transaction.domain === 'restaurant' || transaction.domain === 'hotel') {
    const docs = applyOptimistic(await hospitalityDocs(), transaction.payload, transaction.uuid)
    const body = { data: { docs, offline } }
    await saveSnapshot('hospitality:latest', body)
    return body
  }

  if (transaction.entityType === 'customer') {
    return {
      data: {
        id: transaction.uuid,
        name: transaction.payload.name,
        email: transaction.payload.email ?? null,
        phone: transaction.payload.phone ?? null,
        offline,
      },
      offline,
    }
  }

  if (transaction.operation === 'hold' || transaction.operation === 'update' || transaction.operation === 'delete') {
    return { data: { id: transaction.entityId || transaction.uuid, reference: 'LOCAL', offline }, offline }
  }

  if (transaction.operation === 'open' || transaction.operation === 'open_session') {
    const body = {
      data: {
        id: transaction.uuid,
        cash_register_id: transaction.payload.cash_register_id,
        status: 'open',
        opening_balance: transaction.payload.opening_balance ?? 0,
        offline,
      },
      summary: null,
      offline,
    }
    if (transaction.operation === 'open') await saveSnapshot(cacheKey('/me/cashier-shifts/current'), body)
    return body
  }

  if (transaction.operation === 'close' || transaction.operation === 'close_session') {
    const body = { data: null, summary: null, offline }
    if (transaction.operation === 'close') await saveSnapshot(cacheKey('/me/cashier-shifts/current'), body)
    return body
  }

  if (transaction.entityType === 'sale' || transaction.operation === 'create') {
    return {
      data: {
        sale: { id: transaction.uuid, reference: 'LOCAL' },
        receipt: null,
        loyalty: null,
        offline,
      },
      offline,
    }
  }

  return { data: { id: transaction.uuid, offline }, offline }
}
