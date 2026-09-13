export function taxQuote(amount: number, rate = 0, inclusive = false) {
  const percent = Number(rate) || 0
  if (inclusive) {
    const tva = percent <= 0 ? 0 : Math.round(amount * percent / (100 + percent))
    return { ht: amount - tva, tva, ttc: amount }
  }
  const tva = Math.round(amount * percent / 100)
  return { ht: amount, tva, ttc: amount + tva }
}
