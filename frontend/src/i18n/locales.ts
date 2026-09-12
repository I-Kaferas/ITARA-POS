export const LOCALE_STORAGE_KEY = 'pos_locale'

export const SUPPORTED_LOCALES = ['fr', 'en', 'sw'] as const

export type AppLocale = (typeof SUPPORTED_LOCALES)[number]

export const LOCALE_LABELS: Record<AppLocale, string> = {
  fr: 'Français',
  en: 'English',
  sw: 'Kiswahili',
}

export const LOCALE_META: Record<AppLocale, { native: string; code: string; region: string }> = {
  fr: { native: 'Français', code: 'FR', region: 'France' },
  en: { native: 'English', code: 'EN', region: 'International' },
  sw: { native: 'Kiswahili', code: 'SW', region: 'Afrika Mashariki' },
}

export const INTL_LOCALES: Record<AppLocale, string> = {
  fr: 'fr-FR',
  en: 'en-GB',
  sw: 'sw-KE',
}

export function isAppLocale(value: string | null | undefined): value is AppLocale {
  return value === 'fr' || value === 'en' || value === 'sw'
}

export function readStoredLocale(): AppLocale {
  try {
    const stored = localStorage.getItem(LOCALE_STORAGE_KEY)
    return isAppLocale(stored) ? stored : 'fr'
  } catch {
    return 'fr'
  }
}

export function applyDocumentLocale(locale: AppLocale) {
  document.documentElement.lang = locale
}

export function persistLocale(locale: AppLocale) {
  localStorage.setItem(LOCALE_STORAGE_KEY, locale)
  applyDocumentLocale(locale)
}

export function intlLocale(locale: string | null | undefined = readStoredLocale()): string {
  return isAppLocale(locale) ? INTL_LOCALES[locale] : INTL_LOCALES.fr
}
