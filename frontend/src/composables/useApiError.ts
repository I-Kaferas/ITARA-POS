import { useI18n } from 'vue-i18n'
import { formatApiErrorMessage, resolveApiError, type ResolvedApiError } from '../errors/resolveApiError'
import { pushToast } from './useToast'

export type ShowApiErrorOptions = {
  /** Optional caller fallback (i18n key or human sentence). */
  fallback?: string
  /** Toast title; defaults to common.error. */
  title?: string
  /** When false, only resolve — do not toast. Default true. */
  toast?: boolean
  /** Toast duration in ms. */
  duration?: number
}

/**
 * Global API error UX: resolve → human message → optional danger toast.
 * Prefer this for mutations; keep inline AppAlert/ref for page-load errors.
 */
export function useApiError() {
  const { t } = useI18n()

  function resolve(error: unknown, fallback?: string): ResolvedApiError {
    return resolveApiError(error, fallback)
  }

  function message(error: unknown, fallback?: string): string {
    return formatApiErrorMessage(error, fallback)
  }

  function show(error: unknown, options: ShowApiErrorOptions = {}): ResolvedApiError {
    const resolved = resolveApiError(error, options.fallback)
    if (options.toast !== false) {
      pushToast({
        tone: 'danger',
        title: options.title ?? t('common.error'),
        message: resolved.message,
        duration: options.duration,
      })
    }
    return resolved
  }

  return { resolve, message, show, format: formatApiErrorMessage }
}

/** Non-composable helper for stores / plain modules. */
export function showApiError(error: unknown, options: ShowApiErrorOptions = {}): ResolvedApiError {
  const resolved = resolveApiError(error, options.fallback)
  if (options.toast !== false) {
    pushToast({
      tone: 'danger',
      title: options.title,
      message: resolved.message,
      duration: options.duration,
    })
  }
  return resolved
}
