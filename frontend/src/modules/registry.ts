export const MODULE_CODES = [
  'pos',
  'restaurant',
  'hotel',
  'inventory',
  'crm',
  'accounting',
  'hr',
  'procurement',
  'expenses',
  'projects',
  'documents',
  'fleet',
  'maintenance',
  'manufacturing',
  'ecommerce',
] as const

export type ModuleCode = (typeof MODULE_CODES)[number]

const ALIASES: Record<string, ModuleCode> = {
  stock: 'inventory',
}

const codeSet = new Set<string>(MODULE_CODES)

export function canonicalModule(code: string): string {
  return ALIASES[code] ?? code
}

export function moduleEnabled(enabled: string[] | undefined, module?: string | string[] | null): boolean {
  if (module == null || module === '' || (Array.isArray(module) && module.length === 0)) return true
  if (!enabled?.length) return true
  const required = (Array.isArray(module) ? module : [module]).map(canonicalModule)
  const owned = new Set(enabled.map(canonicalModule))
  return required.some(code => owned.has(code))
}

const PREFIXES: { prefix: string; anyOf: string[] }[] = [
  { prefix: '/admin/reports/sales', anyOf: ['pos'] },
  { prefix: '/admin/reports/inventory', anyOf: ['inventory'] },
  { prefix: '/admin/reports/store-stock', anyOf: ['inventory'] },
  { prefix: '/admin/reports/purchases', anyOf: ['procurement'] },
  { prefix: '/admin/reports/financial', anyOf: ['accounting'] },
  { prefix: '/admin/reports/revenue', anyOf: ['accounting'] },
  { prefix: '/admin/pos', anyOf: ['pos'] },
  { prefix: '/admin/sales', anyOf: ['pos'] },
  { prefix: '/admin/promotions', anyOf: ['pos'] },
  { prefix: '/admin/hospitality', anyOf: ['restaurant'] },
  { prefix: '/admin/hotel', anyOf: ['hotel'] },
  { prefix: '/admin/inventory', anyOf: ['inventory'] },
  { prefix: '/admin/crm', anyOf: ['crm'] },
  { prefix: '/admin/accounting', anyOf: ['accounting'] },
  { prefix: '/admin/purchases', anyOf: ['procurement'] },
  { prefix: '/admin/payables', anyOf: ['procurement'] },
  { prefix: '/admin/suppliers', anyOf: ['procurement', 'inventory'] },
  { prefix: '/admin/expenses', anyOf: ['expenses'] },
  { prefix: '/admin/production', anyOf: ['manufacturing'] },
].sort((left, right) => right.prefix.length - left.prefix.length)

export function moduleRequiredForPath(path: string): string[] | null {
  const shell = path.match(/^\/admin\/modules\/([^/]+)/)
  if (shell) {
    const code = canonicalModule(shell[1])
    return codeSet.has(code) ? [code] : ['__unknown__']
  }
  const match = PREFIXES.find(item => path === item.prefix || path.startsWith(`${item.prefix}/`))
  return match?.anyOf ?? null
}

export interface ModuleSettingField {
  key: string
  type: 'boolean' | 'string' | 'integer'
  value: boolean | string | number
  options?: string[] | null
}

export interface ModuleWidget {
  code: string
  label_key: string
  icon: string
  to: string
}

export interface ModuleManifest {
  code: ModuleCode
  icon: string
  permissions: string[]
  settings: ModuleSettingField[]
  navigation: { name: string; to: string; label_key: string; icon: string }[]
  widgets: ModuleWidget[]
  routes: { api: string[]; web: string[] }
}

export interface ModuleCatalogItem {
  code: ModuleCode
  icon: string
  enabled: boolean
}
