export type ListFilters = {
  search: string
  period: string
  from: string
  to: string
  status: string
  supplier_id: string
  branch_id: string
  warehouse_id: string
  category_id: string
  department: string
  cost_center: string
  payment_method: string
  priority: string
  frequency: string
  active: string
}

export function emptyListFilters(period = 'all'): ListFilters {
  return {
    search: '',
    period,
    from: '',
    to: '',
    status: '',
    supplier_id: '',
    branch_id: '',
    warehouse_id: '',
    category_id: '',
    department: '',
    cost_center: '',
    payment_method: '',
    priority: '',
    frequency: '',
    active: '',
  }
}

export function periodRange(period: string, from = '', to = ''): { from?: string; to?: string } {
  if (period === 'all' || !period) return {}
  const now = new Date()
  const end = now.toISOString().slice(0, 10)
  const start = new Date(now)
  if (period === 'today') return { from: end, to: end }
  if (period === 'week') {
    start.setDate(now.getDate() - 6)
    return { from: start.toISOString().slice(0, 10), to: end }
  }
  if (period === 'month') {
    return { from: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`, to: end }
  }
  if (period === 'quarter') {
    start.setMonth(Math.floor(now.getMonth() / 3) * 3, 1)
    return { from: start.toISOString().slice(0, 10), to: end }
  }
  if (period === 'year') return { from: `${now.getFullYear()}-01-01`, to: end }
  if (period === 'custom') return { from: from || undefined, to: to || undefined }
  return {}
}

export function listFilterParams(filters: ListFilters, map: {
  searchKey?: string
  categoryKey?: string
  includeEmpty?: boolean
} = {}): Record<string, string> {
  const params: Record<string, string> = {}
  const searchKey = map.searchKey ?? 'q'
  const categoryKey = map.categoryKey ?? 'category_id'
  const dates = periodRange(filters.period, filters.from, filters.to)
  if (filters.search.trim()) params[searchKey] = filters.search.trim()
  if (dates.from) params.from = dates.from
  if (dates.to) params.to = dates.to
  if (filters.status) params.status = filters.status
  if (filters.supplier_id) params.supplier_id = filters.supplier_id
  if (filters.branch_id) params.branch_id = filters.branch_id
  if (filters.warehouse_id) params.warehouse_id = filters.warehouse_id
  if (filters.category_id) params[categoryKey] = filters.category_id
  if (filters.department.trim()) params.department = filters.department.trim()
  if (filters.cost_center.trim()) params.cost_center = filters.cost_center.trim()
  if (filters.payment_method) params.payment_method = filters.payment_method
  if (filters.priority) params.priority = filters.priority
  if (filters.frequency) params.frequency = filters.frequency
  if (filters.active !== '') params.active = filters.active
  return params
}

export function matchesSearch(haystack: unknown, search: string): boolean {
  const q = search.trim().toLowerCase()
  if (!q) return true
  return String(haystack ?? '').toLowerCase().includes(q)
}

export function inPeriod(dateValue: unknown, filters: ListFilters): boolean {
  const dates = periodRange(filters.period, filters.from, filters.to)
  if (!dates.from && !dates.to) return true
  const raw = String(dateValue ?? '')
  if (!raw) return false
  const day = raw.slice(0, 10)
  if (dates.from && day < dates.from) return false
  if (dates.to && day > dates.to) return false
  return true
}

export function matchesActive(isActive: unknown, active: string): boolean {
  if (active === '') return true
  const value = Boolean(isActive)
  return active === '1' ? value : !value
}
