import { createI18n } from 'vue-i18n'
import { applyDocumentLocale, persistLocale, readStoredLocale, type AppLocale } from './locales'

const initial = readStoredLocale()
applyDocumentLocale(initial)

const localeLoaders: Record<AppLocale, () => Promise<{ default: Record<string, unknown> }>> = {
  fr: () => import('./locales/fr.json'),
  en: () => import('./locales/en.json'),
  sw: () => import('./locales/sw.json'),
}

const loaded = new Set<AppLocale>()

const i18n = createI18n({
  legacy: false,
  locale: initial,
  fallbackLocale: 'fr',
  messages: {},
})

export async function loadLocaleMessages(locale: AppLocale) {
  if (loaded.has(locale)) return
  const mod = await localeLoaders[locale]()
  i18n.global.setLocaleMessage(locale, mod.default)
  loaded.add(locale)
}

export async function setAppLocale(locale: AppLocale) {
  await loadLocaleMessages(locale)
  if (locale !== 'fr' && !loaded.has('fr')) {
    await loadLocaleMessages('fr')
  }
  i18n.global.locale.value = locale
  persistLocale(locale)
}

/** Ensure the active locale (and French fallback) are ready before first paint. */
export async function ensureI18nReady() {
  await loadLocaleMessages(initial)
  if (initial !== 'fr') {
    await loadLocaleMessages('fr')
  }
}

export default i18n
