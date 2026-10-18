export type Segment = 'retail' | 'restaurants' | 'hospitality' | 'ecommerce'
export type SegmentFilter = 'all' | Segment
export type DateRange = '7d' | '30d' | '90d' | '12m'
export type TxStatus = 'completed' | 'pending' | 'refunded'
export type PaymentMethod = 'Card' | 'Cash' | 'Mobile' | 'Transfer' | 'BNPL'

export interface Transaction {
  id: string
  date: string
  merchant: string
  city: string
  segment: Segment
  amount: number
  items: number
  payment: PaymentMethod
  status: TxStatus
}

export interface KpiMetric {
  label: string
  value: number
  trend: number
  format: 'currency' | 'number' | 'percent'
  icon: 'dollar' | 'receipt' | 'card' | 'users'
  tint: 'indigo' | 'cyan' | 'emerald' | 'amber'
}

export interface DashboardData {
  kpis: KpiMetric[]
  revenueTrend: { date: string; revenue: number }[]
  payments: { name: PaymentMethod; value: number; color: string }[]
  categories: { name: string; sales: number }[]
  processingVolume: number
  refunds: number
  refundRate: number
  locations: { name: string; share: number }[]
  transactions: Transaction[]
}

const SEGMENTS: Segment[] = ['retail', 'restaurants', 'hospitality', 'ecommerce']

const MERCHANTS: Record<Segment, string[]> = {
  retail: ['Northline Mart', 'Urban Goods Co', 'Harbor Outfitters', 'Summit Supply'],
  restaurants: ['Cedar Kitchen', 'Blue Orchid Bistro', 'Firelane Grill', 'Salt & Ember'],
  hospitality: ['Lakeview Inn', 'Aether Suites', 'Canal House Hotel', 'Vista Residences'],
  ecommerce: ['Parcel Pop', 'NexCart Online', 'SwiftShelf', 'ByteBasket'],
}

const CITIES = [
  'Austin, TX',
  'Seattle, WA',
  'Denver, CO',
  'Chicago, IL',
  'Miami, FL',
  'Boston, MA',
  'Portland, OR',
  'Atlanta, GA',
  'Phoenix, AZ',
  'Nashville, TN',
]

const CATEGORIES: Record<Segment, string[]> = {
  retail: ['Apparel', 'Electronics', 'Home', 'Grocery', 'Beauty'],
  restaurants: ['Mains', 'Beverages', 'Desserts', 'Takeout', 'Catering'],
  hospitality: ['Rooms', 'F&B', 'Spa', 'Events', 'Parking'],
  ecommerce: ['Fashion', 'Gadgets', 'Home', 'Sports', 'Digital'],
}

const PAYMENT_COLORS: Record<PaymentMethod, string> = {
  Card: '#6366f1',
  Cash: '#06b6d4',
  Mobile: '#10b981',
  Transfer: '#f59e0b',
  BNPL: '#ef4444',
}

const PAYMENT_WEIGHTS: Record<Segment, Record<PaymentMethod, number>> = {
  retail: { Card: 0.48, Cash: 0.18, Mobile: 0.22, Transfer: 0.07, BNPL: 0.05 },
  restaurants: { Card: 0.42, Cash: 0.28, Mobile: 0.24, Transfer: 0.04, BNPL: 0.02 },
  hospitality: { Card: 0.55, Cash: 0.08, Mobile: 0.12, Transfer: 0.18, BNPL: 0.07 },
  ecommerce: { Card: 0.52, Cash: 0.02, Mobile: 0.2, Transfer: 0.1, BNPL: 0.16 },
}

function mulberry32(seed: number) {
  let t = seed >>> 0
  return () => {
    t += 0x6d2b79f5
    let r = Math.imul(t ^ (t >>> 15), 1 | t)
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r)
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296
  }
}

function hashSeed(range: DateRange, segment: SegmentFilter): number {
  const str = `${range}:${segment}:itara-nexus`
  let h = 2166136261
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

function daysForRange(range: DateRange): number {
  if (range === '7d') return 7
  if (range === '30d') return 30
  if (range === '90d') return 90
  return 365
}

function pickWeighted<T extends string>(rand: () => number, weights: Record<T, number>): T {
  const entries = Object.entries(weights) as [T, number][]
  const total = entries.reduce((s, [, w]) => s + w, 0)
  let roll = rand() * total
  for (const [key, w] of entries) {
    roll -= w
    if (roll <= 0) return key
  }
  return entries[entries.length - 1][0]
}

function segmentMultiplier(segment: SegmentFilter): number {
  if (segment === 'all') return 1
  if (segment === 'retail') return 1.05
  if (segment === 'restaurants') return 0.92
  if (segment === 'hospitality') return 1.18
  return 1.12
}

function activeSegments(segment: SegmentFilter): Segment[] {
  return segment === 'all' ? SEGMENTS : [segment]
}

export function generateDashboard(range: DateRange, segment: SegmentFilter): DashboardData {
  const rand = mulberry32(hashSeed(range, segment))
  const days = daysForRange(range)
  const now = new Date()
  now.setHours(12, 0, 0, 0)
  const mult = segmentMultiplier(segment)
  const segs = activeSegments(segment)

  const revenueTrend: { date: string; revenue: number }[] = []
  const points = range === '12m' ? 12 : Math.min(days, range === '90d' ? 30 : days)
  const step = Math.max(1, Math.floor(days / points))

  for (let i = points - 1; i >= 0; i--) {
    const d = new Date(now)
    d.setDate(d.getDate() - i * step)
    const day = d.getDay()
    const weekendBoost = day === 0 || day === 6 ? 1.22 : 1
    const growth = 1 + ((points - i) / points) * 0.18
    const noise = 0.82 + rand() * 0.36
    const base = (range === '12m' ? 180_000 : 12_500) * mult
    revenueTrend.push({
      date: d.toISOString(),
      revenue: Math.round(base * weekendBoost * growth * noise),
    })
  }

  const totalRevenue = revenueTrend.reduce((s, p) => s + p.revenue, 0)
  const prevRevenue = totalRevenue / (1 + 0.08 + (rand() - 0.5) * 0.06)
  const revenueTrendPct = ((totalRevenue - prevRevenue) / prevRevenue) * 100

  const orders = Math.round(totalRevenue / (48 + rand() * 22))
  const prevOrders = orders / (1 + 0.05 + (rand() - 0.4) * 0.08)
  const aov = totalRevenue / orders
  const prevAov = aov / (1 + 0.02 + (rand() - 0.5) * 0.05)
  const customers = Math.round(orders * (0.62 + rand() * 0.18))
  const prevCustomers = customers / (1 + 0.07 + (rand() - 0.45) * 0.07)

  const kpis: KpiMetric[] = [
    {
      label: 'Gross Revenue',
      value: totalRevenue,
      trend: revenueTrendPct,
      format: 'currency',
      icon: 'dollar',
      tint: 'indigo',
    },
    {
      label: 'Orders',
      value: orders,
      trend: ((orders - prevOrders) / prevOrders) * 100,
      format: 'number',
      icon: 'receipt',
      tint: 'cyan',
    },
    {
      label: 'Avg. Ticket',
      value: aov,
      trend: ((aov - prevAov) / prevAov) * 100,
      format: 'currency',
      icon: 'card',
      tint: 'emerald',
    },
    {
      label: 'Active Customers',
      value: customers,
      trend: ((customers - prevCustomers) / prevCustomers) * 100,
      format: 'number',
      icon: 'users',
      tint: 'amber',
    },
  ]

  const paymentTotals: Record<PaymentMethod, number> = {
    Card: 0,
    Cash: 0,
    Mobile: 0,
    Transfer: 0,
    BNPL: 0,
  }

  const categoryMap = new Map<string, number>()
  const locationMap = new Map<string, number>()
  const transactions: Transaction[] = []

  for (let i = 0; i < 50; i++) {
    const seg = segs[Math.floor(rand() * segs.length)]
    const merchants = MERCHANTS[seg]
    const merchant = merchants[Math.floor(rand() * merchants.length)]
    const city = CITIES[Math.floor(rand() * CITIES.length)]
    const dayOffset = Math.floor(rand() * days)
    const d = new Date(now)
    d.setDate(d.getDate() - dayOffset)
    const payment = pickWeighted(rand, PAYMENT_WEIGHTS[seg])
    const statusRoll = rand()
    const status: TxStatus =
      statusRoll > 0.92 ? 'refunded' : statusRoll > 0.86 ? 'pending' : 'completed'
    const amount = Math.round((18 + rand() * (seg === 'hospitality' ? 420 : 160)) * 100) / 100
    const items = 1 + Math.floor(rand() * (seg === 'restaurants' ? 6 : 4))
    const id = `TX-${(100000 + Math.floor(rand() * 900000)).toString(16).toUpperCase()}`

    paymentTotals[payment] += amount
    const cats = CATEGORIES[seg]
    const cat = cats[Math.floor(rand() * cats.length)]
    categoryMap.set(cat, (categoryMap.get(cat) ?? 0) + amount)
    const cityShort = city.split(',')[0]
    locationMap.set(cityShort, (locationMap.get(cityShort) ?? 0) + amount)

    transactions.push({
      id,
      date: d.toISOString(),
      merchant,
      city,
      segment: seg,
      amount,
      items,
      payment,
      status,
    })
  }

  transactions.sort((a, b) => +new Date(b.date) - +new Date(a.date))

  const payments = (Object.keys(PAYMENT_COLORS) as PaymentMethod[])
    .map((name) => ({
      name,
      value: Math.round(paymentTotals[name]),
      color: PAYMENT_COLORS[name],
    }))
    .filter((p) => p.value > 0)
    .sort((a, b) => b.value - a.value)

  const categories = [...categoryMap.entries()]
    .map(([name, sales]) => ({ name, sales: Math.round(sales) }))
    .sort((a, b) => b.sales - a.sales)
    .slice(0, 6)

  const locTotal = [...locationMap.values()].reduce((s, v) => s + v, 0) || 1
  const locations = [...locationMap.entries()]
    .map(([name, v]) => ({ name, share: (v / locTotal) * 100 }))
    .sort((a, b) => b.share - a.share)
    .slice(0, 4)

  const refunds = transactions.filter((t) => t.status === 'refunded').reduce((s, t) => s + t.amount, 0)
  const refundRate = (refunds / (totalRevenue || 1)) * 100

  return {
    kpis,
    revenueTrend,
    payments,
    categories,
    processingVolume: Math.round(totalRevenue * (0.94 + rand() * 0.04)),
    refunds: Math.round(refunds),
    refundRate,
    locations,
    transactions,
  }
}

export const DATE_RANGE_OPTIONS: { id: DateRange; label: string }[] = [
  { id: '7d', label: 'Last 7 days' },
  { id: '30d', label: 'Last 30 days' },
  { id: '90d', label: 'Last 90 days' },
  { id: '12m', label: '12 months' },
]

export const SEGMENT_OPTIONS: { id: SegmentFilter; label: string }[] = [
  { id: 'all', label: 'All Segments' },
  { id: 'retail', label: 'Retail' },
  { id: 'restaurants', label: 'Restaurants' },
  { id: 'hospitality', label: 'Hospitality' },
  { id: 'ecommerce', label: 'E-Commerce' },
]
