import { readTransactions, saveTransaction } from './storage'
import type { OfflineStatus, OfflineTransaction } from './types'

const ACTIVE: OfflineStatus[] = ['pending', 'syncing', 'conflict', 'failed']

export async function enqueue(transaction: OfflineTransaction): Promise<void> {
  const existing = await readTransactions()
  // Same UUID / idempotency key → already processed (or already queued). Do not duplicate.
  if (existing.some((item) => {
    if (item.uuid === transaction.uuid) return true
    const existingKey = item.idempotencyKey || item.uuid
    return existingKey === transaction.idempotencyKey
  })) {
    return
  }
  await saveTransaction(transaction)
}

export async function listTransactions(): Promise<OfflineTransaction[]> {
  const rows = await readTransactions()
  return rows.sort((a, b) => a.createdAt.localeCompare(b.createdAt))
}

export async function listActive(): Promise<OfflineTransaction[]> {
  return (await listTransactions()).filter((item) => ACTIVE.includes(item.status))
}

export async function updateTransaction(transaction: OfflineTransaction): Promise<void> {
  await saveTransaction({ ...transaction, updatedAt: new Date().toISOString() })
}
