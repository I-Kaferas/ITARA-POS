import { intlLocale } from '../i18n/locales'
import { resolveMoneyCurrency } from './currency'

export function formatMoney(amount: number, currency?: string, locale = intlLocale()): string {
  const code = resolveMoneyCurrency(currency)
  const value = (Number(amount) || 0) / 100
  try {
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: code,
      currencyDisplay: 'symbol',
    }).format(value)
  } catch {
    return `${value.toLocaleString(locale, { maximumFractionDigits: 2 })} ${code}`
  }
}

export function parseMoneyInput(value: string): number {
  const normalized = value.replace(',', '.').replace(/[^\d.]/g, '')
  const parsed = Number.parseFloat(normalized)
  if (Number.isNaN(parsed)) return 0
  return Math.round(parsed * 100)
}
