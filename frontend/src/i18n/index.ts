import { createI18n } from 'vue-i18n'
import en from './locales/en.json'
import fr from './locales/fr.json'
import sw from './locales/sw.json'
import { applyDocumentLocale, persistLocale, readStoredLocale, type AppLocale } from './locales'

const initial = readStoredLocale()
applyDocumentLocale(initial)

const i18n = createI18n({
  legacy: false,
  locale: initial,
  fallbackLocale: 'fr',
  messages: { en, fr, sw },
})

export function setAppLocale(locale: AppLocale) {
  i18n.global.locale.value = locale
  persistLocale(locale)
}

export default i18n
