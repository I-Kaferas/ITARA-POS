const currencyFull = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
})

const currencyPrecise = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2,
})

export function formatCurrency(value: number, precise = false): string {
  return (precise ? currencyPrecise : currencyFull).format(value)
}

export function formatCompactCurrency(value: number): string {
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `$${(value / 1_000_000).toFixed(1)}M`
  if (abs >= 1_000) return `$${(value / 1_000).toFixed(1)}K`
  return `$${Math.round(value)}`
}

export function formatPercent(value: number, digits = 1): string {
  return `${value.toFixed(digits)}%`
}

export function formatDate(iso: string): string {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(iso))
}

export function formatShortDate(iso: string): string {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
  }).format(new Date(iso))
}
