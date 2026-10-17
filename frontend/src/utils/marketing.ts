import { readStoredLocale } from '../i18n/locales'

/** Public marketing site (vitrine). Used after logout. */
export const MARKETING_URL =
  String(import.meta.env.VITE_MARKETING_URL || '').trim() || 'http://localhost:5174'

export function goToMarketing() {
  try {
    const url = new URL(MARKETING_URL, window.location.origin)
    url.searchParams.set('lang', readStoredLocale())
    window.location.assign(url.toString())
  } catch {
    window.location.assign(MARKETING_URL)
  }
}
