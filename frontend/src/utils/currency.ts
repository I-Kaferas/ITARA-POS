/** Application display currency — always driven by the active company's currency_code. */
const DEFAULT_CURRENCY = 'FBU'

let appCurrencyCode = DEFAULT_CURRENCY

export function getAppCurrency(): string {
  return appCurrencyCode || DEFAULT_CURRENCY
}

export function setAppCurrency(code?: string | null) {
  const normalized = (code ?? '').trim().toUpperCase()
  appCurrencyCode = normalized || DEFAULT_CURRENCY
}

export function resolveCompanyCurrency(
  company?: { currency_code?: string | null } | null,
  fallback = DEFAULT_CURRENCY,
): string {
  const code = company?.currency_code?.trim().toUpperCase()
  return code || fallback
}
