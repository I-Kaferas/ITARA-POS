/** Perpetual weighted average, in minor currency units. Matches WeightedAverageCost.php. */
export function weightedAverageCost(onHand: number, currentCost: number, incomingQty: number, incomingCost: number): number {
  const stock = Math.max(0, Math.trunc(onHand))
  const qty = Math.max(0, Math.trunc(incomingQty))
  const current = Math.max(0, Math.trunc(currentCost))
  const incoming = Math.max(0, Math.trunc(incomingCost))
  const total = stock + qty

  if (total <= 0 || incoming === current) return current
  if (stock === 0) return incoming

  const numerator = stock * current + qty * incoming
  return Math.trunc((numerator + Math.trunc(total / 2)) / total)
}
