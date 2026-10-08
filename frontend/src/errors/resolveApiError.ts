import i18n from '../i18n'
import { readStoredLocale, type AppLocale } from '../i18n/locales'

export type ApiErrorPayload = {
  code?: string
  message?: string
  errors?: Record<string, string[]>
  module?: string
  required_permissions?: string[]
}

type ApiErrorLike = Error & {
  status: number
  payload?: unknown
}

function isApiErrorLike(error: unknown): error is ApiErrorLike {
  return Boolean(
    error
    && typeof error === 'object'
    && 'status' in error
    && typeof (error as { status: unknown }).status === 'number'
    && error instanceof Error,
  )
}

export type ResolvedApiError = {
  /** Stable key when known (e.g. errors.forbidden). */
  code: string | null
  /** Human, localized message safe for end users. */
  message: string
  /** HTTP status when available. */
  status: number | null
  /** Field-level messages already localized. */
  fields: Record<string, string>
  /** True when the message came from a known catalog entry. */
  known: boolean
}

/** Backend / Laravel prose → stable i18n keys. */
const LEGACY_MESSAGE_KEYS: Record<string, string> = {
  'unauthenticated.': 'errors.unauthenticated',
  'unauthenticated': 'errors.unauthenticated',
  'forbidden. insufficient permissions.': 'errors.forbidden',
  'forbidden.insufficient permissions.': 'errors.forbidden',
  'module disabled.': 'errors.module_disabled',
  'x-tenant-id header is required.': 'errors.tenant_required',
  'tenant not found.': 'errors.tenant_not_found',
  'tenant is not active.': 'errors.tenant_inactive',
  'forbidden tenant access.': 'errors.tenant_forbidden',
  'store not found.': 'errors.store_not_found',
  'store is not active.': 'errors.store_inactive',
  'forbidden store access.': 'errors.store_forbidden',
  'the given data was invalid.': 'errors.validation',
  'too many attempts.': 'errors.too_many_requests',
  'server error': 'errors.server',
  'server error.': 'errors.server',
}

const STATUS_KEYS: Record<number, string> = {
  0: 'errors.connection',
  400: 'errors.bad_request',
  401: 'errors.unauthenticated',
  403: 'errors.forbidden',
  404: 'errors.not_found',
  408: 'errors.timeout',
  409: 'errors.conflict',
  422: 'errors.validation',
  429: 'errors.too_many_requests',
  500: 'errors.server',
  502: 'errors.unavailable',
  503: 'errors.unavailable',
  504: 'errors.unavailable',
}

const TECHNICAL_PATTERNS = [
  /^HTTP\s+\d{3}$/i,
  /^SQLSTATE/i,
  /stack trace/i,
  /Exception:/i,
  /Illuminate\\/i,
  /Symfony\\/i,
  /at\s+\w+\.\w+\s+\(/i,
  /TypeError:/i,
  /ReferenceError:/i,
  /ECONNREFUSED/i,
  /ENOTFOUND/i,
  /Failed to fetch/i,
  /NetworkError/i,
  /CORS/i,
  /^\s*\{[\s\S]*\}\s*$/,
]

function currentLocale(): AppLocale {
  const fromI18n = i18n.global.locale.value
  if (fromI18n === 'fr' || fromI18n === 'en' || fromI18n === 'sw') return fromI18n
  return readStoredLocale()
}

function translate(key: string, params?: Record<string, unknown>): string | null {
  const locale = currentLocale()
  const te = i18n.global.te
  const t = i18n.global.t
  if (te(key, locale)) return String(t(key, params ?? {}, { locale }))
  if (te(key, 'fr')) return String(t(key, params ?? {}, { locale: 'fr' }))
  return null
}

function looksTechnical(message: string): boolean {
  const trimmed = message.trim()
  if (!trimmed) return true
  if (TECHNICAL_PATTERNS.some((pattern) => pattern.test(trimmed))) return true
  // Long opaque tokens / paths are not useful for cashiers.
  if (trimmed.length > 220) return true
  if (/[\\/][\w.-]+\.(php|ts|js|vue)\b/i.test(trimmed)) return true
  return false
}

function normalizeKeyCandidate(raw: string): string | null {
  const value = raw.trim()
  if (!value) return null

  if (/^(errors|saas|offline)\.[a-z0-9_.]+$/i.test(value)) {
    return value
  }

  const legacy = LEGACY_MESSAGE_KEYS[value.toLowerCase()]
  if (legacy) return legacy

  return null
}

function localizeRaw(raw: string | undefined | null, fallbackKey: string, params?: Record<string, unknown>): {
  message: string
  code: string | null
  known: boolean
} {
  if (!raw) {
    return {
      message: translate(fallbackKey, params) ?? translate('errors.generic') ?? 'Something went wrong.',
      code: fallbackKey,
      known: true,
    }
  }

  const key = normalizeKeyCandidate(raw)
  if (key) {
    const localized = translate(key, params)
    if (localized) return { message: localized, code: key, known: true }
  }

  if (looksTechnical(raw)) {
    return {
      message: translate(fallbackKey, params) ?? translate('errors.generic') ?? 'Something went wrong.',
      code: fallbackKey,
      known: true,
    }
  }

  // Domain prose already written for humans (mixed EN/FR today) — keep it.
  return { message: raw, code: null, known: false }
}

function statusFallbackKey(status: number | null): string {
  if (status === null) return 'errors.generic'
  return STATUS_KEYS[status] ?? (status >= 500 ? 'errors.server' : 'errors.generic')
}

/**
 * Resolve any thrown value into a user-safe, translatable error.
 * Never returns stack traces, HTTP codes, or framework noise.
 */
export function resolveApiError(error: unknown, fallback?: string): ResolvedApiError {
  const fallbackKey = fallback && normalizeKeyCandidate(fallback) ? fallback : 'errors.generic'
  const explicitFallback = fallback && !normalizeKeyCandidate(fallback) ? fallback : null

  if (!isApiErrorLike(error)) {
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      const offline = localizeRaw('errors.offline', 'errors.offline')
      return { ...offline, status: 0, fields: {} }
    }

    if (error instanceof TypeError || (error instanceof Error && /fetch|network/i.test(error.message))) {
      const connection = localizeRaw('errors.connection', 'errors.connection')
      return { ...connection, status: 0, fields: {} }
    }

    if (error instanceof Error) {
      const resolved = localizeRaw(error.message, fallbackKey)
      return {
        code: resolved.code,
        message: explicitFallback && !resolved.known ? explicitFallback : resolved.message,
        status: null,
        fields: {},
        known: resolved.known,
      }
    }

    const generic = localizeRaw(null, fallbackKey)
    return {
      code: generic.code,
      message: explicitFallback ?? generic.message,
      status: null,
      fields: {},
      known: true,
    }
  }

  const status = error.status
  const payload = (error.payload ?? {}) as ApiErrorPayload
  const params: Record<string, unknown> = {}
  if (payload.module) params.module = payload.module

  const fields: Record<string, string> = {}
  if (payload.errors) {
    for (const [field, messages] of Object.entries(payload.errors)) {
      const first = messages?.[0]
      if (!first) continue
      fields[field] = localizeRaw(first, 'errors.validation', params).message
    }
  }

  const firstField = Object.values(fields)[0]
  if (firstField) {
    return {
      code: payload.code ? normalizeKeyCandidate(payload.code) : 'errors.validation',
      message: firstField,
      status,
      fields,
      known: true,
    }
  }

  const preferred = payload.code || payload.message || error.message
  const statusKey = statusFallbackKey(status)
  const resolved = localizeRaw(preferred, statusKey, params)

  // Prefer status mapping when the server sent a technical/generic HTTP string.
  if (!resolved.known && looksTechnical(String(preferred ?? ''))) {
    const byStatus = localizeRaw(statusKey, statusKey, params)
    return { ...byStatus, status, fields, known: true }
  }

  return {
    code: resolved.code ?? (payload.code ? normalizeKeyCandidate(payload.code) : null),
    message: explicitFallback && !resolved.known ? explicitFallback : resolved.message,
    status,
    fields,
    known: resolved.known,
  }
}

/** Convenience: human message only (keeps existing call-site API). */
export function formatApiErrorMessage(error: unknown, fallback?: string): string {
  return resolveApiError(error, fallback).message
}

/** Humanize a raw offline/sync error string. */
export function humanizeErrorText(raw: string | null | undefined, fallbackKey = 'errors.sync_failed'): string {
  if (!raw) return translate(fallbackKey) ?? translate('errors.generic') ?? 'Something went wrong.'
  return localizeRaw(raw, fallbackKey).message
}
