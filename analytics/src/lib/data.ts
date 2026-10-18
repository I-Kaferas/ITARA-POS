export type Segment = 'all' | 'retail' | 'restaurants' | 'hospitality' | 'ecommerce'
export type DateRange = '7d' | '30d' | '90d' | '12m'
export type TxStatus = 'completed' | 'pending' | 'refunded'
export type PaymentMethod = 'Card' | 'Cash' | 'Wallet' | 'Transfer' | 'BNPL'

export interface Transaction {
  id: string
  date: string
  merchant: string
  city: string
  segment: Exclude<Segment, 'all'>
  amount: number
  items: number
  payment: PaymentMethod
  status: TxStatus
}

export interface Kpi {
  key: string
  label: string
  value: number
  format: 'money' | 'number' | 'percent'
  change: number
  icon: 'dollar' | 'receipt' | 'card' | 'users'
  tone: 'indigo' | 'cyan' | 'emerald' | 'amber'
}

export interface DashboardData {
  kpis: Kpi[]
  revenueTrend: { date: string; revenue: number }[]
  payments: { name: PaymentMethod; value: number; color: string }[]
  categories: { name: string; sales: number }[]
  processingVolume: number
  refunds: number
  refundRate: number
  locations: { name: string; share: number }[]
  transactions: Transaction[]
}

const SEGMENTS: Exclude<Segment, 'all'>[] = ['retail', 'restaurants', 'hospitality', 'ecommerce']

const MERCHANTS: Record<Exclude<Segment, 'all'>, string[]> = {
  retail: ['Harbor Goods', 'Northline Outfitters', 'Corner Market Co', 'Atlas Apparel'],
  restaurants: ['Cedar Table', 'Blue Oven Kitchen', 'Salt & Ember', 'Nightjar Bistro'],
  hospitality: ['Auric Suites', 'Lakeview Inn', 'Plaza Residence', 'Harbor Bay Hotel'],
  ecommerce: ['Nimbus Shop', 'Parcel & Co', 'Orbit Cart', 'Vista Direct'],
}

const CITIES = [
  'Austin, TX',
  'Seattle, WA',
  'Chicago, IL',
  'Denver, CO',
  'Miami, FL',
  'Boston, MA',
  'Portland, OR',
  'Nashville, TN',
]

const CATEGORIES: Record<Exclude<Segment, 'all'>, string[]> = {
  retail: ['Apparel', 'Electronics', 'Home', 'Grocery', 'Beauty'],
  restaurants: ['Mains', 'Drinks', 'Desserts', 'Takeout', 'Catering'],
  hospitality: ['Rooms', 'F&B', 'Spa', 'Events', 'Retail desk'],
  ecommerce: ['Fashion', 'Gadgets', 'Homeware', 'Subscriptions', 'Digital'],
}

const PAYMENTS: PaymentMethod[] = ['Card', 'Cash', 'Wallet', 'Transfer', 'BNPL']
const PAYMENT_COLORS: Record<PaymentMethod, string> = {
  Card: '#6366f1',
  Cash: '#06b6d4',
  Wallet: '#10b981',
  Transfer: '#f59e0b',
  BNPL: '#ef4444',
}

const PAYMENT_WEIGHTS: Record<Exclude<Segment, 'all'>, number[]> = {
  retail: [0.52, 0.18, 0.12, 0.1, 0.08],
  restaurants: [0.48, 0.28, 0.14, 0.06, 0.04],
  hospitality: [0.62, 0.08, 0.1, 0.14, 0.06],
  ecommerce: [0.58, 0.02, 0.2, 0.08, 0.12],
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

function hashSeed(range: DateRange, segment: Segment): number {
  const s = `${range}:${segment}:itara-nexus-2026`
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

function daysForRange(range: DateRange): number {
  switch (range) {
    case '7d':
      return 7
    case '30d':
      return 30
    case '90d':
      return 90
    case '12m':
      return 365
  }
}

function pickWeighted<T>(rand: () => number, items: T[], weights: number[]): T {
  const total = weights.reduce((a, b) => a + b, 0)
  let r = rand() * total
  for (let i = 0; i < items.length; i++) {
    r -= weights[i]
    if (r <= 0) return items[i]
  }
  return items[items.length - 1]
}

function segmentMultiplier(segment: Segment): number {
  switch (segment) {
    case 'retail':
      return 1.05
    case 'restaurants':
      return 0.92
    case 'hospitality':
      return 1.18
    case 'ecommerce':
      return 1.1
    default:
      return 1
  }
}

function activeSegments(segment: Segment): Exclude<Segment, 'all'>[] {
  return segment === 'all' ? SEGMENTS : [segment]
}

export function generateDashboard(range: DateRange, segment: Segment): DashboardData {
  const rand = mulberry32(hashSeed(range, segment))
  const days = daysForRange(range)
  const segs = activeSegments(segment)
  const now = new Date()
  now.setHours(12, 0, 0, 0)

  const revenueTrend: { date: string; revenue: number }[] = []
  let totalRevenue = 0
  let prevRevenue = 0
  const mid = Math.floor(days / 2)

  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now)
    d.setDate(d.getDate() - i)
    const weekend = d.getDay() === 0 || d.getDay() === 6 ? 1.22 : 1
    const growth = 1 + ((days - i) / days) * 0.18
    const base = 4200 + rand() * 2800
    const revenue = Math.round(base * weekend * growth * segmentMultiplier(segment) * (0.85 + rand() * 0.3))
    revenueTrend.push({ date: d.toISOString().slice(0, 10), revenue })
    totalRevenue += revenue
    if (i >= mid) prevRevenue += revenue
  }

  const currentHalf = totalRevenue - prevRevenue
  const revenueChange = prevRevenue === 0 ? 0 : ((currentHalf - prevRevenue) / prevRevenue) * 100

  const orders = Math.round(totalRevenue / (48 + rand() * 22))
  const aov = totalRevenue / Math.max(orders, 1)
  const customers = Math.round(orders * (0.62 + rand() * 0.18))
  const ordersChange = revenueChange * (0.7 + rand() * 0.4)
  const aovChange = (rand() - 0.45) * 8
  const customersChange = revenueChange * (0.55 + rand() * 0.35)

  const paymentTotals = Object.fromEntries(PAYMENTS.map((p) => [p, 0])) as Record<PaymentMethod, number>
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
    d.setHours(8 + Math.floor(rand() * 12), Math.floor(rand() * 60), 0, 0)

    const payment = pickWeighted(rand, PAYMENTS, PAYMENT_WEIGHTS[seg])
    const statusRoll = rand()
    const status: TxStatus = statusRoll > 0.92 ? 'refunded' : statusRoll > 0.86 ? 'pending' : 'completed'
    const amount = Math.round((18 + rand() * 420) * segmentMultiplier(seg) * 100) / 100
    const items = 1 + Math.floor(rand() * 8)
    const id = `TX-${(100000 + Math.floor(rand() * 899999)).toString(36).toUpperCase()}${i.toString(36).toUpperCase()}`

    paymentTotals[payment] += amount
    const cats = CATEGORIES[seg]
    const cat = cats[Math.floor(rand() * cats.length)]
    categoryMap.set(cat, (categoryMap.get(cat) ?? 0) + amount)
    const loc = city.split(',')[0]
    locationMap.set(loc, (locationMap.get(loc) ?? 0) + amount)

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

  const payments = PAYMENTS.map((name) => ({
    name,
    value: paymentTotals[name],
    color: PAYMENT_COLORS[name],
  })).filter((p) => p.value > 0)

  const categories = [...categoryMap.entries()]
    .map(([name, sales]) => ({ name, sales: Math.round(sales) }))
    .sort((a, b) => b.sales - a.sales)
    .slice(0, 6)

  const locEntries = [...locationMap.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4)
  const locSum = locEntries.reduce((a, [, v]) => a + v, 0) || 1
  const locations = locEntries.map(([name, v]) => ({
    name,
    share: Math.round((v / locSum) * 1000) / 10,
  }))

  const refunds = transactions.filter((t) => t.status === 'refunded').reduce((a, t) => a + t.amount, 0)
  const refundRate = (refunds / (totalRevenue || 1)) * 100
  const processingVolume = Math.round(totalRevenue * (1.04 + rand() * 0.08))

  return {
    kpis: [
      {
        key: 'revenue',
        label: 'Gross Revenue',
        value: totalRevenue,
        format: 'money',
        change: revenueChange,
        icon: 'dollar',
        tone: 'indigo',
      },
      {
        key: 'orders',
        label: 'Orders',
        value: orders,
        format: 'number',
        change: ordersChange,
        icon: 'receipt',
        tone: 'cyan',
      },
      {
        key: 'aov',
        label: 'Avg. Order Value',
        value: aov,
        format: 'money',
        change: aovChange,
        icon: 'card',
        tone: 'emerald',
      },
      {
        key: 'customers',
        label: 'Active Customers',
        value: customers,
        format: 'number',
        change: customersChange,
        icon: 'users',
        tone: 'amber',
      },
    ],
    revenueTrend,
    payments: payments.map((p) => ({ ...p, value: Math.round(p.value) })),
    categories,
    processingVolume,
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
  { id: '12m', label: 'Last 12 months' },
]

export const SEGMENT_OPTIONS: { id: Segment; label: string }[] = [
  { id: 'all', label: 'All Segments' },
  { id: 'retail', label: 'Retail' },
  { id: 'restaurants', label: 'Restaurants' },
  { id: 'hospitality', label: 'Hospitality' },
  { id: 'ecommerce', label: 'E-Commerce' },
]

export { PAYMENT_COLORS }
