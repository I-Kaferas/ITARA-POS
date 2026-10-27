import { createI18n } from 'vue-i18n'
import {
  applyDocumentLocale,
  isAppLocale,
  persistLocale,
  readStoredLocale,
  type AppLocale,
} from './locales'

function readQueryLocale(): AppLocale | null {
  try {
    const raw = new URLSearchParams(window.location.search).get('lang')
    return isAppLocale(raw) ? raw : null
  } catch {
    return null
  }
}

const fromQuery = typeof window !== 'undefined' ? readQueryLocale() : null
const initial = fromQuery || readStoredLocale()
if (fromQuery) persistLocale(fromQuery)
else applyDocumentLocale(initial)

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

/** Load the active locale before the first paint. */
export async function ensureI18nReady() {
  await loadLocaleMessages(initial)
}

/** French stays the fallback, loaded after paint when another language is active. */
export function warmFallbackLocale() {
  if (initial !== 'fr') void loadLocaleMessages('fr')
}

export default i18n
