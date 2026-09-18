import { computed, ref } from 'vue'

/** Local / legacy aliases → ISO 4217 codes accepted by Intl.NumberFormat */
const CURRENCY_ALIASES: Record<string, string> = {
  FBU: 'BIF',
  FBUU: 'BIF',
}

const DEFAULT_CURRENCY = 'BIF'

const appCurrencyCode = ref(DEFAULT_CURRENCY)

/** Normalize to an uppercase ISO-friendly code (aliases mapped). */
export function normalizeCurrencyCode(code?: string | null, fallback = DEFAULT_CURRENCY): string {
  const raw = (code ?? '').trim().toUpperCase()
  if (!raw) return fallback
  return CURRENCY_ALIASES[raw] ?? raw
}

/** Application display currency — always driven by the active company's currency_code. */
export function getAppCurrency(): string {
  return appCurrencyCode.value || DEFAULT_CURRENCY
}

export function setAppCurrency(code?: string | null) {
  appCurrencyCode.value = normalizeCurrencyCode(code, DEFAULT_CURRENCY)
}

export function resolveCompanyCurrency(
  company?: { currency_code?: string | null } | null,
  fallback = DEFAULT_CURRENCY,
): string {
  return normalizeCurrencyCode(company?.currency_code, fallback)
}

/** Prefer an explicit code (line/hotel/etc.), otherwise the app currency. */
export function resolveMoneyCurrency(preferred?: string | null): string {
  return normalizeCurrencyCode(preferred, getAppCurrency())
}

export function useAppCurrency() {
  return computed(() => appCurrencyCode.value)
}
