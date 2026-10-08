/**
 * Domain-configurable conflict resolution rules (mirrors backend config).
 *
 * - sales → never overwrite completed sales
 * - stock → use stock movements
 * - configuration → master configuration wins
 */

export type ConflictDomain = 'sales' | 'stock' | 'configuration' | 'default'

export type ConflictStrategy =
  | 'never_overwrite_completed'
  | 'stock_movements'
  | 'master_wins'
  | 'manual'
  | 'server_wins'
  | 'client_wins'

export type ConflictAction = 'apply' | 'keep_server' | 'reject' | 'rewrite_as_movement'

export interface DomainRule {
  strategy: ConflictStrategy
  entity_types: string[]
}

export type ConflictCatalog = Record<string, DomainRule>

export interface ConflictEvalInput {
  entityType: string
  operation: string
  serverStatus?: string | null
  serverQuantity?: number | null
  localQuantity?: number | null
  baseVersion?: string | null
  serverVersion?: string | null
  fromMaster?: boolean
  hasMasterCopy?: boolean
  force?: boolean
  conflictDomain?: ConflictDomain
}

export interface ConflictEvalResult {
  action: ConflictAction
  domain: ConflictDomain
  strategy: ConflictStrategy
  code?: string
  message?: string
  meta?: Record<string, unknown>
}

const DEFAULT_CATALOG: ConflictCatalog = {
  sales: {
    strategy: 'never_overwrite_completed',
    entity_types: ['sale', 'sales', 'sale_item', 'sale_payment', 'payment'],
  },
  stock: {
    strategy: 'stock_movements',
    entity_types: [
      'stock',
      'stock_balance',
      'inventory_movement',
      'stock_movement',
      'stock_adjustment',
      'stock_transfer',
    ],
  },
  configuration: {
    strategy: 'master_wins',
    entity_types: [
      'product',
      'category',
      'price',
      'price_list',
      'user',
      'permission',
      'role',
      'tax',
      'tax_group',
      'tax_class',
      'tax_rule',
      'table',
      'zone',
      'printer',
      'printer_group',
      'printer_route',
      'restaurant_configuration',
      'hotel_settings',
      'payment_method',
      'unit',
      'currency',
    ],
  },
  default: {
    strategy: 'manual',
    entity_types: [],
  },
}

const FINAL_SALE_STATUSES = new Set(['completed', 'voided', 'merged'])
const SALE_MUTATIONS = new Set(['update', 'delete', 'void', 'overwrite', 'complete'])
const STOCK_OVERWRITES = new Set([
  'set_quantity',
  'overwrite',
  'overwrite_balance',
  'replace_balance',
  'set_balance',
])
const STOCK_MOVEMENTS = new Set(['create', 'movement', 'adjust', 'transfer', 'receive', 'issue'])

let catalog: ConflictCatalog = { ...DEFAULT_CATALOG }

export function setConflictCatalog(next: ConflictCatalog | null | undefined): void {
  if (!next || typeof next !== 'object') {
    catalog = { ...DEFAULT_CATALOG }
    return
  }
  catalog = { ...DEFAULT_CATALOG, ...next }
}

export function getConflictCatalog(): ConflictCatalog {
  return catalog
}

export function resolveConflictDomain(entityType: string, explicit?: ConflictDomain): ConflictDomain {
  if (explicit) return explicit
  const needle = entityType.toLowerCase()
  for (const [domain, rule] of Object.entries(catalog)) {
    if (rule.entity_types.some((item) => item.toLowerCase() === needle)) {
      return domain as ConflictDomain
    }
  }
  return 'default'
}

export function evaluateConflict(input: ConflictEvalInput): ConflictEvalResult {
  const domain = resolveConflictDomain(input.entityType, input.conflictDomain)
  const strategy = (catalog[domain]?.strategy ?? 'manual') as ConflictStrategy
  const operation = input.operation.toLowerCase()

  switch (strategy) {
    case 'never_overwrite_completed':
      return resolveSales(input, domain, strategy, operation)
    case 'stock_movements':
      return resolveStock(input, domain, strategy, operation)
    case 'master_wins':
      return resolveMasterWins(input, domain, strategy)
    case 'server_wins':
      if (input.force) return apply(domain, strategy)
      if (input.hasMasterCopy || isStale(input)) {
        return keepServer(domain, strategy, 'server_wins', 'La copie serveur est conservée.')
      }
      return apply(domain, strategy)
    case 'client_wins':
      return apply(domain, strategy)
    case 'manual':
    default:
      if (input.force) return apply(domain, strategy)
      if (isStale(input)) {
        return reject(domain, strategy, 'stale_version', 'Le document a été modifié sur le serveur depuis la copie locale.')
      }
      return apply(domain, strategy)
  }
}

function resolveSales(
  input: ConflictEvalInput,
  domain: ConflictDomain,
  strategy: ConflictStrategy,
  operation: string,
): ConflictEvalResult {
  const status = (input.serverStatus ?? '').toLowerCase()
  if (!status || !FINAL_SALE_STATUSES.has(status)) {
    return apply(domain, strategy)
  }
  if (!SALE_MUTATIONS.has(operation)) {
    return keepServer(domain, strategy, 'completed_sale', 'La vente est déjà finalisée sur le serveur.', { status, operation })
  }
  return reject(domain, strategy, 'completed_sale', 'Impossible d’écraser une vente finalisée.', { status, operation })
}

function resolveStock(
  input: ConflictEvalInput,
  domain: ConflictDomain,
  strategy: ConflictStrategy,
  operation: string,
): ConflictEvalResult {
  if (STOCK_MOVEMENTS.has(operation)) {
    return apply(domain, strategy, { via: 'movement' })
  }

  const isOverwrite = STOCK_OVERWRITES.has(operation)
    || (input.localQuantity != null && input.serverQuantity != null)

  if (!isOverwrite) {
    return apply(domain, strategy)
  }

  if (input.serverQuantity != null && input.localQuantity != null && input.serverQuantity !== input.localQuantity) {
    return {
      action: 'rewrite_as_movement',
      domain,
      strategy,
      code: 'use_stock_movements',
      message: 'Le stock se synchronise par mouvements, pas par écrasement de quantité.',
      meta: {
        delta: input.localQuantity - input.serverQuantity,
        server_quantity: input.serverQuantity,
        local_quantity: input.localQuantity,
      },
    }
  }

  return reject(
    domain,
    strategy,
    'use_stock_movements',
    'Le stock se synchronise par mouvements, pas par écrasement de quantité.',
    { operation },
  )
}

function resolveMasterWins(
  input: ConflictEvalInput,
  domain: ConflictDomain,
  strategy: ConflictStrategy,
): ConflictEvalResult {
  if (input.fromMaster) {
    return apply(domain, strategy, { source: 'master' })
  }
  if (input.hasMasterCopy || isStale(input)) {
    return keepServer(domain, strategy, 'master_wins', 'La configuration maître prévaut.')
  }
  return apply(domain, strategy, { source: 'seed' })
}

function isStale(input: ConflictEvalInput): boolean {
  if (!input.baseVersion || !input.serverVersion) return false
  return input.baseVersion !== input.serverVersion
}

function apply(domain: ConflictDomain, strategy: ConflictStrategy, meta?: Record<string, unknown>): ConflictEvalResult {
  return { action: 'apply', domain, strategy, meta }
}

function keepServer(
  domain: ConflictDomain,
  strategy: ConflictStrategy,
  code: string,
  message: string,
  meta?: Record<string, unknown>,
): ConflictEvalResult {
  return { action: 'keep_server', domain, strategy, code, message, meta }
}

function reject(
  domain: ConflictDomain,
  strategy: ConflictStrategy,
  code: string,
  message: string,
  meta?: Record<string, unknown>,
): ConflictEvalResult {
  return { action: 'reject', domain, strategy, code, message, meta }
}
