import type { OfflineTransaction } from './types'

const DB_NAME = 'itara-pos-offline'
const DB_VERSION = 1
const FALLBACK_KEY = 'itara.offline.store'

type SnapshotRow = { key: string; value: unknown }

type FallbackStore = {
  transactions: OfflineTransaction[]
  snapshots: Record<string, unknown>
}

let database: IDBDatabase | null = null
let useFallback = false
let opening: Promise<void> | null = null

function emptyFallback(): FallbackStore {
  return { transactions: [], snapshots: {} }
}

function readFallback(): FallbackStore {
  try {
    const raw = localStorage.getItem(FALLBACK_KEY)
    if (!raw) return emptyFallback()
    const parsed = JSON.parse(raw) as FallbackStore
    return {
      transactions: Array.isArray(parsed.transactions) ? parsed.transactions : [],
      snapshots: parsed.snapshots && typeof parsed.snapshots === 'object' ? parsed.snapshots : {},
    }
  } catch {
    return emptyFallback()
  }
}

function writeFallback(store: FallbackStore) {
  localStorage.setItem(FALLBACK_KEY, JSON.stringify(store))
}

function requestToPromise<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function openDatabase(): Promise<void> {
  if (database || useFallback) return
  if (!opening) {
    opening = new Promise((resolve) => {
      if (typeof indexedDB === 'undefined') {
        useFallback = true
        resolve()
        return
      }
      const request = indexedDB.open(DB_NAME, DB_VERSION)
      request.onupgradeneeded = () => {
        const db = request.result
        if (!db.objectStoreNames.contains('transactions')) {
          const store = db.createObjectStore('transactions', { keyPath: 'uuid' })
          store.createIndex('status', 'status')
          store.createIndex('createdAt', 'createdAt')
        }
        if (!db.objectStoreNames.contains('snapshots')) {
          db.createObjectStore('snapshots', { keyPath: 'key' })
        }
      }
      request.onsuccess = () => {
        database = request.result
        resolve()
      }
      request.onerror = () => {
        useFallback = true
        resolve()
      }
    })
  }
  await opening
}

function txStore(mode: IDBTransactionMode) {
  if (!database) throw new Error('Offline store is not open')
  return database.transaction('transactions', mode).objectStore('transactions')
}

export async function saveTransaction(transaction: OfflineTransaction): Promise<void> {
  await openDatabase()
  if (useFallback || !database) {
    const store = readFallback()
    const index = store.transactions.findIndex((item) => item.uuid === transaction.uuid)
    if (index >= 0) store.transactions[index] = transaction
    else store.transactions.push(transaction)
    writeFallback(store)
    return
  }
  await requestToPromise(txStore('readwrite').put(transaction))
}

export async function readTransactions(): Promise<OfflineTransaction[]> {
  await openDatabase()
  const rows = useFallback || !database
    ? readFallback().transactions
    : (await requestToPromise(txStore('readonly').getAll())) as OfflineTransaction[]
  return rows
    .map(normalizeTransaction)
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
}

function normalizeTransaction(row: OfflineTransaction): OfflineTransaction {
  return {
    ...row,
    transactionId: row.transactionId ?? row.serverId ?? null,
    idempotencyKey: row.idempotencyKey || row.uuid,
    alreadyProcessed: row.alreadyProcessed === true,
  }
}

export async function saveSnapshot(key: string, value: unknown): Promise<void> {
  await openDatabase()
  if (useFallback || !database) {
    const store = readFallback()
    store.snapshots[key] = value
    writeFallback(store)
    return
  }
  const row: SnapshotRow = { key, value }
  await requestToPromise(database.transaction('snapshots', 'readwrite').objectStore('snapshots').put(row))
}

export async function readSnapshot<T>(key: string): Promise<T | null> {
  await openDatabase()
  if (useFallback || !database) {
    const value = readFallback().snapshots[key]
    return value === undefined ? null : value as T
  }
  const row = await requestToPromise(
    database.transaction('snapshots', 'readonly').objectStore('snapshots').get(key),
  ) as SnapshotRow | undefined
  return row ? row.value as T : null
}
