const currencyFull = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
})

const currencyPrecise = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})

export function formatMoney(value: number, precise = false): string {
  return (precise ? currencyPrecise : currencyFull).format(value)
}

export function formatCompact(value: number): string {
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `$${(value / 1_000_000).toFixed(1)}M`
  if (abs >= 1_000) return `$${(value / 1_000).toFixed(1)}K`
  return `$${Math.round(value)}`
}

export function formatPercent(value: number, digits = 1): string {
  return `${value.toFixed(digits)}%`
}

export function formatDateShort(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

export function formatDateTime(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}
