import { formatApiErrorMessage } from '../errors/resolveApiError'
import { cachedRead, interceptWrite, isCacheableRead, isTransientError, rememberRead } from '../offline/gateway'

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api/v1'

export class ApiError extends Error {
  status: number
  payload?: unknown

  constructor(message: string, status: number, payload?: unknown) {
    super(message)
    this.status = status
    this.payload = payload
  }
}

/** Human, localized message — never technical noise for end users. */
export function extractApiErrorMessage(error: unknown, fallback?: string): string {
  return formatApiErrorMessage(error, fallback)
}

export function getToken(): string | null {
  return localStorage.getItem('pos_token')
}

export function getRefreshToken(): string | null {
  return localStorage.getItem('pos_refresh_token')
}

export function getTenantId(): string | null {
  return localStorage.getItem('pos_tenant_id')
}

export function getStoreId(): string | null {
  return localStorage.getItem('pos_store_id')
}

export function setStoreId(storeId: string) {
  localStorage.setItem('pos_store_id', storeId)
}

export function clearStoreId() {
  localStorage.removeItem('pos_store_id')
}

export function setAuth(accessToken: string, tenantId: string | null, refreshToken?: string) {
  localStorage.setItem('pos_token', accessToken)
  if (tenantId) localStorage.setItem('pos_tenant_id', tenantId)
  else localStorage.removeItem('pos_tenant_id')
  if (refreshToken) localStorage.setItem('pos_refresh_token', refreshToken)
}

export function clearAuth() {
  localStorage.removeItem('pos_token')
  localStorage.removeItem('pos_refresh_token')
  localStorage.removeItem('pos_tenant_id')
  clearStoreId()
}

export function isAuthenticated(): boolean {
  return Boolean(getToken())
}

let refreshPromise: Promise<string | null> | null = null

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = getRefreshToken()
  if (!refreshToken) return null

  const response = await fetch(`${API_BASE}/auth/refresh`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: refreshToken }),
  })

  if (!response.ok) {
    clearAuth()
    return null
  }

  const payload = (await response.json()) as { access_token: string; refresh_token: string }
  setAuth(payload.access_token, getTenantId(), payload.refresh_token)
  return payload.access_token
}

async function request<T>(path: string, options: RequestInit = {}, retryOnUnauthorized = true): Promise<T> {
  const headers = new Headers(options.headers)
  if (!headers.has('Accept')) headers.set('Accept', 'application/json')
  if (!headers.has('Accept-Language')) headers.set('Accept-Language', localStorage.getItem('pos_locale') || 'fr')

  const token = getToken()
  const tenantId = getTenantId()
  const storeId = getStoreId()

  if (token) headers.set('Authorization', `Bearer ${token}`)
  if (tenantId) headers.set('X-Tenant-ID', tenantId)
  if (storeId) headers.set('X-Store-ID', storeId)

  const response = await fetch(`${API_BASE}${path}`, { ...options, headers })

  if (response.status === 401 && retryOnUnauthorized && path !== '/auth/refresh' && getRefreshToken()) {
    if (!refreshPromise) refreshPromise = refreshAccessToken().finally(() => { refreshPromise = null })
    const newToken = await refreshPromise
    if (newToken) return request<T>(path, options, false)
  }

  if (response.status === 204) return undefined as T

  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new ApiError((payload as { message?: string })?.message ?? `HTTP ${response.status}`, response.status, payload)
  }
  return payload as T
}

type WriteOptions = { skipOffline?: boolean }

async function write<T>(method: string, path: string, body?: unknown, options?: WriteOptions): Promise<T> {
  const send = (nextPath: string, nextMethod: string, nextBody: unknown, uuid?: string) => request<T>(nextPath, {
    method: nextMethod,
    headers: {
      ...(nextBody === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...(uuid ? { 'X-Client-UUID': uuid } : {}),
    },
    body: nextBody === undefined ? undefined : JSON.stringify(nextBody),
  })

  if (options?.skipOffline) return send(path, method, body)

  const decision = await interceptWrite(method, path, body, send)
  if (!decision.passthrough) return decision.response as T
  return send(path, method, body)
}

const inflightGets = new Map<string, Promise<unknown>>()

export const api = {
  get: <T>(path: string) => {
    const pending = inflightGets.get(path)
    if (pending) return pending as Promise<T>
    const requestPromise = (async () => {
      if (isCacheableRead(path) && typeof navigator !== 'undefined' && navigator.onLine === false) {
        const cached = await cachedRead(path)
        if (cached !== undefined) return cached as T
      }
      try {
        const data = await request<T>(path)
        void rememberRead(path, data)
        return data
      } catch (error) {
        if (isCacheableRead(path) && isTransientError(error)) {
          const cached = await cachedRead(path)
          if (cached !== undefined) return cached as T
        }
        throw error
      }
    })().finally(() => {
      if (inflightGets.get(path) === requestPromise) inflightGets.delete(path)
    })
    inflightGets.set(path, requestPromise)
    return requestPromise
  },
  post: <T>(path: string, body?: unknown, options?: WriteOptions) => write<T>('POST', path, body, options),
  put: <T>(path: string, body?: unknown, options?: WriteOptions) => write<T>('PUT', path, body, options),
  patch: <T>(path: string, body?: unknown, options?: WriteOptions) => write<T>('PATCH', path, body, options),
  delete: <T>(path: string, options?: WriteOptions) => write<T>('DELETE', path, undefined, options),
  upload: <T>(path: string, formData: FormData) => request<T>(path, { method: 'POST', body: formData }),
  async download(path: string, filename: string) {
    const headers = new Headers({ Accept: 'text/csv' })
    headers.set('Accept-Language', localStorage.getItem('pos_locale') || 'fr')
    const token = getToken()
    const tenantId = getTenantId()
    const storeId = getStoreId()
    if (token) headers.set('Authorization', `Bearer ${token}`)
    if (tenantId) headers.set('X-Tenant-ID', tenantId)
    if (storeId) headers.set('X-Store-ID', storeId)

    const response = await fetch(`${API_BASE}${path}`, { headers })
    if (!response.ok) {
      const payload = await response.json().catch(() => null)
      throw new ApiError((payload as { message?: string })?.message ?? `HTTP ${response.status}`, response.status, payload)
    }
    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    a.click()
    URL.revokeObjectURL(url)
  },
}

export interface ApiListResponse<T> { data: T[] }
export interface ApiItemResponse<T> { data: T }
