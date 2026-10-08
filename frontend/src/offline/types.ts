export type OfflineDomain = 'pos' | 'restaurant' | 'hotel' | 'cash_register'

export type OfflineStatus = 'pending' | 'syncing' | 'synced' | 'conflict' | 'failed' | 'discarded'

export type ConflictResolution = 'discard' | 'accept_server' | 'keep_local'

export interface OfflineConflict {
  code: string
  message: string
}

export interface OfflineTransaction {
  /** Client-generated UUID for the offline operation. */
  uuid: string
  /** Server transaction / sale id once synced. */
  transactionId: string | null
  /** Key used by the server to reject duplicate writes. */
  idempotencyKey: string
  domain: OfflineDomain
  entityType: string
  entityId: string
  operation: string
  payload: Record<string, unknown>
  storeId: string | null
  baseVersion: string | null
  status: OfflineStatus
  attempts: number
  lastError: string | null
  conflict: OfflineConflict | null
  createdAt: string
  updatedAt: string
  nextAttemptAt: string | null
  serverId: string | null
  alreadyProcessed?: boolean
}

export interface SyncPushResult {
  id: string
  uuid?: string
  transaction_id?: string | null
  idempotency_key?: string
  entity_id: string
  client_uuid?: string
  status: 'synced' | 'conflict' | 'failed' | 'discarded'
  server_id?: string | null
  reference?: string | null
  error?: string | null
  conflict_code?: string | null
  retryable?: boolean
  already_processed?: boolean
  message?: string | null
}
