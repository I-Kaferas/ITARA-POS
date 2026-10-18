/** In-memory GET cache for admin reads (stale-while-revalidate). */

export const READ_FRESH_MS = 45_000
export const READ_STALE_MS = 5 * 60_000

const INVALIDATED_KEY = 'pos_api_cache_invalidated_at'

type MemoryEntry = {
  at: number
  data: unknown
  epoch: number
}

let bustEpoch = 0
const memory = new Map<string, MemoryEntry>()

export function cacheInvalidatedAt(): number {
  if (typeof sessionStorage === 'undefined') return 0
  const raw = sessionStorage.getItem(INVALIDATED_KEY)
  const value = raw ? Number(raw) : 0
  return Number.isFinite(value) ? value : 0
}

export function bustApiReadCache(): void {
  bustEpoch += 1
  memory.clear()
  if (typeof sessionStorage !== 'undefined') {
    sessionStorage.setItem(INVALIDATED_KEY, String(Date.now()))
  }
}

export function peekApiReadCache(key: string): { at: number; data: unknown } | null {
  const entry = memory.get(key)
  if (!entry || entry.epoch !== bustEpoch) return null
  return { at: entry.at, data: entry.data }
}

export function putApiReadCache(key: string, data: unknown, at = Date.now()): void {
  memory.set(key, { at, data, epoch: bustEpoch })
}

export function ageMs(at: number): number {
  return Date.now() - at
}

export function isCacheEntryTrusted(at: number): boolean {
  return at >= cacheInvalidatedAt()
}
