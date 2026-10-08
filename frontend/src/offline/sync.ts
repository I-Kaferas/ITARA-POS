import { api } from '../api/client'
import { listTransactions, updateTransaction } from './queue'
import { readSnapshot, saveSnapshot } from './storage'
import type { ConflictResolution, OfflineTransaction, SyncPushResult } from './types'

const REFERENCE_KEYS = [
  'sale_id', 'cashier_shift_id', 'customer_id', 'order_id', 'reservation_id',
  'check_id', 'stay_id', 'room_id', 'table_id',
]

const MAX_ATTEMPTS = 8

export async function flushOfflineQueue(): Promise<void> {
  const idMap = await readIdMap()

  for (let pass = 0; pass < 50; pass += 1) {
    const all = await listTransactions()
    const pendingUuids = new Set(all.filter((item) => item.status === 'pending' || item.status === 'syncing' || item.status === 'failed').map((item) => item.uuid))
    const now = Date.now()
    const original = all.find((item) => {
      if (item.status !== 'pending' && item.status !== 'failed') return false
      if (item.status === 'failed' && item.attempts >= MAX_ATTEMPTS) return false
      if (item.nextAttemptAt && Date.parse(item.nextAttemptAt) > now) return false
      return !dependsOnPending(item, pendingUuids, idMap)
    })
    if (!original) return
    const transaction = rewrite(original, idMap)
    transaction.status = 'syncing'
    transaction.attempts += 1
    await updateTransaction(transaction)
    try {
      const response = await api.post<{ data: { results: SyncPushResult[] } }>('/sync/offline', {
        operations: [{
          id: transaction.uuid,
          client_uuid: transaction.uuid,
          domain: transaction.domain,
          entity_type: transaction.entityType,
          entity_id: transaction.entityId,
          operation: transaction.operation,
          payload: transaction.payload,
          base_version: transaction.baseVersion,
        }],
      }, { skipOffline: true })
      const result = response.data.results[0]
      if (!result) throw new Error('Réponse de synchronisation vide')
      await applyResult(transaction, result, idMap)
    } catch (error) {
      transaction.status = transaction.attempts >= MAX_ATTEMPTS ? 'failed' : 'pending'
      transaction.lastError = error instanceof Error ? error.message : 'Synchronisation impossible'
      transaction.nextAttemptAt = new Date(Date.now() + transaction.attempts * 5000).toISOString()
      scrubPin(transaction)
      await updateTransaction(transaction)
    }
  }
}

export async function resolveOffline(uuid: string, resolution: ConflictResolution): Promise<void> {
  const rows = await listTransactions()
  const transaction = rows.find((item) => item.uuid === uuid)
  const response = await api.post<{ data: SyncPushResult }>('/sync/offline/resolve', {
    client_uuid: uuid,
    resolution,
  }, { skipOffline: true })
  if (!transaction) return
  const idMap = await readIdMap()
  await applyResult(transaction, response.data, idMap)
}

async function applyResult(transaction: OfflineTransaction, result: SyncPushResult, idMap: Record<string, string>): Promise<void> {
  transaction.serverId = result.server_id ?? transaction.serverId
  transaction.transactionId = result.transaction_id ?? result.server_id ?? transaction.transactionId
  transaction.idempotencyKey = result.idempotency_key ?? transaction.idempotencyKey
  transaction.alreadyProcessed = result.already_processed === true
  transaction.lastError = result.error ?? null
  transaction.updatedAt = new Date().toISOString()

  if (result.server_id) {
    idMap[transaction.uuid] = result.server_id
    idMap[transaction.entityId] = result.server_id
    await saveSnapshot('id-map', idMap)
  }

  if (result.status === 'synced' || result.status === 'discarded') {
    transaction.status = result.status
    transaction.conflict = null
    scrubPin(transaction)
  } else if (result.status === 'conflict') {
    transaction.status = 'conflict'
    transaction.conflict = {
      code: result.conflict_code || 'conflict',
      message: result.error || 'Conflit de synchronisation',
    }
  } else if (result.retryable && transaction.attempts < MAX_ATTEMPTS) {
    transaction.status = 'pending'
    transaction.nextAttemptAt = new Date(Date.now() + transaction.attempts * 5000).toISOString()
  } else {
    transaction.status = 'failed'
  }

  await updateTransaction(transaction)
}

function rewrite(transaction: OfflineTransaction, idMap: Record<string, string>): OfflineTransaction {
  const payload = { ...transaction.payload }
  for (const key of REFERENCE_KEYS) {
    const value = payload[key]
    if (typeof value === 'string' && idMap[value]) payload[key] = idMap[value]
  }
  let entityId = transaction.entityId
  if ((transaction.operation === 'update' || transaction.operation === 'delete') && idMap[entityId]) {
    entityId = idMap[entityId]
  }
  return { ...transaction, entityId, payload }
}

function dependsOnPending(transaction: OfflineTransaction, pending: Set<string>, idMap: Record<string, string>): boolean {
  const ids = REFERENCE_KEYS.map((key) => transaction.payload[key]).filter((value): value is string => typeof value === 'string')
  if ((transaction.operation === 'update' || transaction.operation === 'delete') && transaction.entityId !== transaction.uuid) {
    ids.push(transaction.entityId)
  }
  return ids.some((id) => id !== transaction.uuid && pending.has(id) && !idMap[id])
}

async function readIdMap(): Promise<Record<string, string>> {
  const stored = await readSnapshot<Record<string, string>>('id-map')
  return stored ?? {}
}

function scrubPin(transaction: OfflineTransaction) {
  if ('pin' in transaction.payload) {
    const payload = { ...transaction.payload }
    delete payload.pin
    transaction.payload = payload
  }
}
