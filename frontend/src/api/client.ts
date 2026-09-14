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

type ValidationPayload = {
  message?: string
  errors?: Record<string, string[]>
}

function connectionError(): string {
  const locale = localStorage.getItem('pos_locale')
  if (locale === 'en') return 'Connection error'
  if (locale === 'sw') return 'Hitilafu ya muunganisho'
  return 'Erreur de connexion'
}

export function extractApiErrorMessage(error: unknown, fallback = connectionError()): string {
  if (!(error instanceof ApiError)) {
    return error instanceof Error ? error.message : fallback
  }

  const payload = error.payload as ValidationPayload | undefined
  const fieldErrors = payload?.errors
  if (fieldErrors) {
    for (const messages of Object.values(fieldErrors)) {
      if (messages?.[0]) return messages[0]
    }
  }

  return payload?.message ?? error.message ?? fallback
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

export function setAuth(accessToken: string, tenantId: string, refreshToken?: string) {
  localStorage.setItem('pos_token', accessToken)
  localStorage.setItem('pos_tenant_id', tenantId)
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
  const tenantId = getTenantId()
  if (tenantId) setAuth(payload.access_token, tenantId, payload.refresh_token)
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

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }),
  delete: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
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
