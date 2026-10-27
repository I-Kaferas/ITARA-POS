import type { LocalStockMovement, OfflineTransaction } from './types'

const DB_NAME = 'itara-pos-offline'
const DB_VERSION = 2
const FALLBACK_KEY = 'itara.offline.store'

type SnapshotRow = { key: string; value: unknown }

type FallbackStore = {
  transactions: OfflineTransaction[]
  snapshots: Record<string, unknown>
  stockMovements: LocalStockMovement[]
}

let database: IDBDatabase | null = null
let useFallback = false
let opening: Promise<void> | null = null
/** Resolves when the last closed connection has fully settled. */
let closedWait: Promise<void> | null = null
let closedResolve: (() => void) | null = null
/** Serializes IDB work so close/reopen cannot race mid-transaction. */
let chain: Promise<unknown> = Promise.resolve()

function emptyFallback(): FallbackStore {
  return { transactions: [], snapshots: {}, stockMovements: [] }
}

function readFallback(): FallbackStore {
  try {
    const raw = localStorage.getItem(FALLBACK_KEY)
    if (!raw) return emptyFallback()
    const parsed = JSON.parse(raw) as FallbackStore
    return {
      transactions: Array.isArray(parsed.transactions) ? parsed.transactions : [],
      snapshots: parsed.snapshots && typeof parsed.snapshots === 'object' ? parsed.snapshots : {},
      stockMovements: Array.isArray(parsed.stockMovements) ? parsed.stockMovements : [],
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
    request.onerror = () => reject(request.error ?? new Error('IndexedDB request failed'))
  })
}

function isClosingError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error ?? '')
  const name = error instanceof DOMException || error instanceof Error ? error.name : ''
  return (
    name === 'InvalidStateError'
    || /connection is closing|database connection is closing|InvalidStateError/i.test(message)
  )
}

function beginCloseWait() {
  if (closedWait) return
  closedWait = new Promise<void>((resolve) => {
    closedResolve = resolve
  })
}

function finishCloseWait() {
  closedResolve?.()
  closedResolve = null
  closedWait = null
}

function invalidateDatabase() {
  const db = database
  database = null
  opening = null
  if (!db) {
    finishCloseWait()
    return
  }
  beginCloseWait()
  try {
    db.onclose = () => {
      finishCloseWait()
    }
    db.onversionchange = null
    db.close()
  } catch {
    finishCloseWait()
  }
  // If onclose never fires (some browsers), unblock reopen shortly.
  if (typeof window !== 'undefined') {
    window.setTimeout(() => {
      if (closedResolve) finishCloseWait()
    }, 150)
  } else {
    finishCloseWait()
  }
}

function bindDatabase(db: IDBDatabase) {
  database = db
  db.onversionchange = () => {
    invalidateDatabase()
  }
  db.onclose = () => {
    if (database === db) {
      database = null
      opening = null
    }
    finishCloseWait()
  }
}

async function openDatabase(): Promise<void> {
  if (database || useFallback) return
  if (closedWait) await closedWait
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
        if (!db.objectStoreNames.contains('stock_movements')) {
          const stock = db.createObjectStore('stock_movements', { keyPath: 'id' })
          stock.createIndex('saleUuid', 'saleUuid')
          stock.createIndex('status', 'status')
        }
      }
      request.onsuccess = () => {
        bindDatabase(request.result)
        resolve()
      }
      request.onerror = () => {
        useFallback = true
        opening = null
        resolve()
      }
      request.onblocked = () => {
        // Another tab holds an old connection; keep waiting for success/error.
      }
    }).finally(() => {
      // Allow a later reopen if this attempt left no live connection.
      if (!database && !useFallback) opening = null
    })
  }
  await opening
}

async function ensureDatabase(): Promise<void> {
  if (database) {
    try {
      // Touch the connection; a closing DB throws here.
      void database.objectStoreNames.length
      return
    } catch {
      invalidateDatabase()
    }
  }
  await openDatabase()
}

function txStore(mode: IDBTransactionMode) {
  const db = database
  if (!db) throw new Error('Offline store is not open')
  return db.transaction('transactions', mode).objectStore('transactions')
}

function snapshotStore(mode: IDBTransactionMode) {
  const db = database
  if (!db) throw new Error('Offline store is not open')
  return db.transaction('snapshots', mode).objectStore('snapshots')
}

async function withStore<T>(run: () => Promise<T>): Promise<T> {
  const execute = async (): Promise<T> => {
    await ensureDatabase()
    try {
      return await run()
    } catch (error) {
      if (!isClosingError(error) || useFallback) throw error
      invalidateDatabase()
      await ensureDatabase()
      if (useFallback || !database) {
        // Prefer fallback over surfacing a transient close race.
        if (!useFallback) useFallback = true
        return await run()
      }
      return await run()
    }
  }

  const next = chain.then(execute, execute)
  chain = next.then(
    () => undefined,
    () => undefined,
  )
  return next
}

export async function saveTransaction(transaction: OfflineTransaction): Promise<void> {
  await withStore(async () => {
    if (useFallback || !database) {
      const store = readFallback()
      const index = store.transactions.findIndex((item) => item.uuid === transaction.uuid)
      if (index >= 0) store.transactions[index] = transaction
      else store.transactions.push(transaction)
      writeFallback(store)
      return
    }
    await requestToPromise(txStore('readwrite').put(transaction))
  })
}

export async function readTransactions(): Promise<OfflineTransaction[]> {
  const rows = await withStore(async () => {
    if (useFallback || !database) return readFallback().transactions
    return (await requestToPromise(txStore('readonly').getAll())) as OfflineTransaction[]
  })
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
  await withStore(async () => {
    if (useFallback || !database) {
      const store = readFallback()
      store.snapshots[key] = value
      writeFallback(store)
      return
    }
    const row: SnapshotRow = { key, value }
    await requestToPromise(snapshotStore('readwrite').put(row))
  })
}

export async function readSnapshot<T>(key: string): Promise<T | null> {
  return withStore(async () => {
    if (useFallback || !database) {
      const value = readFallback().snapshots[key]
      return value === undefined ? null : value as T
    }
    const row = await requestToPromise(
      snapshotStore('readonly').get(key),
    ) as SnapshotRow | undefined
    return row ? row.value as T : null
  })
}

function transactionDone(tx: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error ?? new Error('IndexedDB transaction failed'))
    tx.onabort = () => reject(tx.error ?? new Error('IndexedDB transaction aborted'))
  })
}

export async function listStockMovements(): Promise<LocalStockMovement[]> {
  return withStore(async () => {
    if (useFallback || !database) return readFallback().stockMovements
    const store = database.transaction('stock_movements', 'readonly').objectStore('stock_movements')
    return (await requestToPromise(store.getAll())) as LocalStockMovement[]
  })
}

export async function putStockMovements(movements: LocalStockMovement[]): Promise<void> {
  if (!movements.length) return
  await withStore(async () => {
    if (useFallback || !database) {
      const store = readFallback()
      for (const movement of movements) {
        const index = store.stockMovements.findIndex((item) => item.id === movement.id)
        if (index >= 0) store.stockMovements[index] = movement
        else store.stockMovements.push(movement)
      }
      writeFallback(store)
      return
    }
    const tx = database.transaction('stock_movements', 'readwrite')
    const store = tx.objectStore('stock_movements')
    for (const movement of movements) store.put(movement)
    await transactionDone(tx)
  })
}

/** Queues the sale and its stock movements together. Returns false if the sale was already queued. */
export async function saveQueuedSale(
  transaction: OfflineTransaction,
  movements: LocalStockMovement[],
): Promise<boolean> {
  return withStore(async () => {
    if (useFallback || !database) {
      const store = readFallback()
      if (store.transactions.some((item) => item.uuid === transaction.uuid || item.idempotencyKey === transaction.idempotencyKey)) {
        return false
      }
      store.transactions.push(transaction)
      for (const movement of movements) {
        if (!store.stockMovements.some((item) => item.id === movement.id)) store.stockMovements.push(movement)
      }
      writeFallback(store)
      return true
    }
    const tx = database.transaction(['transactions', 'stock_movements'], 'readwrite')
    const sales = tx.objectStore('transactions')
    const existing = await requestToPromise(sales.get(transaction.uuid)) as OfflineTransaction | undefined
    if (existing) {
      await transactionDone(tx)
      return false
    }
    sales.put(transaction)
    const stock = tx.objectStore('stock_movements')
    for (const movement of movements) stock.put(movement)
    await transactionDone(tx)
    return true
  })
}
