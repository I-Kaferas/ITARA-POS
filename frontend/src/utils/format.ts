import { intlLocale } from '../i18n/locales'
import { getAppCurrency, resolveMoneyCurrency } from './currency'

export function formatMoney(amount: number, currency?: string): string {
  const code = resolveMoneyCurrency(currency)
  const value = (Number(amount) || 0) / 100
  try {
    return new Intl.NumberFormat(intlLocale(), {
      style: 'currency',
      currency: code,
      currencyDisplay: 'symbol',
    }).format(value)
  } catch {
    return `${value.toLocaleString(intlLocale(), { maximumFractionDigits: 2 })} ${code}`
  }
}

export function formatDate(value?: string | null): string {
  if (!value) return '—'
  return new Intl.DateTimeFormat(intlLocale(), { dateStyle: 'medium' }).format(new Date(value))
}

export function formatDateTime(value?: string | null): string {
  if (!value) return '—'
  return new Intl.DateTimeFormat(intlLocale(), {
    dateStyle: 'medium',
    timeStyle: 'medium',
  }).format(new Date(value))
}

export function toDateTimeLocal(value: Date = new Date()): string {
  const pad = (part: number) => String(part).padStart(2, '0')
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}T${pad(value.getHours())}:${pad(value.getMinutes())}:${pad(value.getSeconds())}`
}
