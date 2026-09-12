import { intlLocale } from '../i18n/locales'
import { getAppCurrency } from './currency'

export function formatMoney(amount: number, currency?: string, locale = intlLocale()): string {
  const code = (currency || getAppCurrency()).toUpperCase()
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: code,
    currencyDisplay: 'symbol',
  }).format(amount / 100)
}

export function parseMoneyInput(value: string): number {
  const normalized = value.replace(',', '.').replace(/[^\d.]/g, '')
  const parsed = Number.parseFloat(normalized)
  if (Number.isNaN(parsed)) return 0
  return Math.round(parsed * 100)
}
