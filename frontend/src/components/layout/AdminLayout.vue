<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useSlots, watch, watchEffect } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import LanguageSwitcher from '../ui/LanguageSwitcher.vue'
import AppCalculator from './AppCalculator.vue'
import ModuleSearch from './ModuleSearch.vue'
import OfflineIndicator from './OfflineIndicator.vue'
import RealtimeIndicator from './RealtimeIndicator.vue'
import StockAlertBell from './StockAlertBell.vue'
import { useAuthStore } from '../../stores/auth'
import { moduleEnabled } from '../../modules/registry'
import { useBackofficeStore } from '../../stores/backoffice'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'
import { usePageHeaderStore } from '../../stores/pageHeader'
import { useOfflineStore } from '../../stores/offline'
import { useRealtimeStore } from '../../stores/realtime'
import { useTheme } from '../../composables/useTheme'

type NavChild = { name: string; to: string; label: string; icon: string; color?: string; module?: string | string[] }
type NavItem = {
  name: string
  to: string
  label: string
  icon: string
  module?: string | string[]
  children?: NavChild[]
}

const { t } = useI18n()
const { preference, cycleTheme } = useTheme()
const themeIcon = computed(() => {
  if (preference.value === 'dark') return 'moon'
  if (preference.value === 'light') return 'sun'
  return 'device-computer'
})
const route = useRoute()
const router = useRouter()
const slots = useSlots()
const auth = useAuthStore()
const billingBanner = computed(() => {
  const status = auth.user?.subscription?.status
  if (status === 'suspended') return t('subscriptionPage.bannerSuspended')
  if (status === 'past_due') return t('subscriptionPage.bannerPastDue')
  return ''
})
const brandingStore = useBrandingStore()
const context = useContextStore()
const backoffice = useBackofficeStore()
const offline = useOfflineStore()
const realtime = useRealtimeStore()
const pageHeader = usePageHeaderStore()
const moduleSearch = ref<InstanceType<typeof ModuleSearch> | null>(null)
const userMenuOpen = ref(false)
const userMenuTrigger = ref<HTMLElement | null>(null)
const userMenuPanel = ref<HTMLElement | null>(null)
const userMenuStyle = ref<Record<string, string>>({})

const openMenuId = ref<string | null>(null)
const navEl = ref<HTMLElement | null>(null)
const sidebarOpen = ref(localStorage.getItem('pos_sidebar_open') !== '0')
const drawerOpen = ref(false)
const isDesktop = ref(typeof window === 'undefined' ? true : window.innerWidth >= 1024)

watch(sidebarOpen, (open) => {
  localStorage.setItem('pos_sidebar_open', open ? '1' : '0')
})

function syncViewport() {
  isDesktop.value = window.innerWidth >= 1024
  if (isDesktop.value) drawerOpen.value = false
}

const navSections = computed(() => [
  {
    label: t('nav.section.main'),
    items: [
      {
        name: 'platform',
        to: '/admin/platform',
        label: t('nav.platform'),
        icon: 'building',
        children: [
          { name: 'platform-dashboard', to: '/admin/platform', label: t('platform.nav.dashboard'), icon: 'dashboard' },
          { name: 'platform-tenants', to: '/admin/platform/tenants', label: t('platform.nav.tenants'), icon: 'building' },
          { name: 'platform-plans', to: '/admin/platform/plans', label: t('platform.nav.plans'), icon: 'coins' },
          { name: 'platform-users', to: '/admin/platform/users', label: t('platform.nav.users'), icon: 'customers' },
          { name: 'platform-support', to: '/admin/platform/support', label: t('platform.nav.support'), icon: 'mail' },
          { name: 'platform-audit', to: '/admin/platform/audit', label: t('platform.nav.audit'), icon: 'receipt' },
          { name: 'platform-backups', to: '/admin/platform/backups', label: t('platform.nav.backups'), icon: 'layers' },
        ],
      },
      { name: 'dashboard', to: '/admin', label: t('nav.dashboard'), icon: 'dashboard' },
      {
        name: 'hotel',
        to: '/admin/hotel/rooms',
        label: t('nav.hotel'),
        icon: 'building',
        module: 'hotel',
        children: [
          { name: 'hotel-room-config', to: '/admin/hotel/room-config', label: t('hotel.tabs.roomConfig'), icon: 'layers' },
          { name: 'hotel-rooms', to: '/admin/hotel/rooms', label: t('hotel.tabs.rooms'), icon: 'bed' },
          { name: 'hotel-reservations', to: '/admin/hotel/reservations', label: t('hotel.tabs.reservations'), icon: 'calendar' },
          { name: 'hotel-stays', to: '/admin/hotel/stays', label: t('hotel.tabs.stays'), icon: 'key' },
          { name: 'hotel-invoices', to: '/admin/hotel/invoices', label: t('hotel.tabs.invoices'), icon: 'receipt' },
          { name: 'hotel-guests', to: '/admin/hotel/guests', label: t('hotel.tabs.guests'), icon: 'customers' },
          { name: 'hotel-housekeeping', to: '/admin/hotel/housekeeping', label: t('hotel.tabs.housekeeping'), icon: 'broom' },
          { name: 'hotel-calendar', to: '/admin/hotel/calendar', label: t('hotel.tabs.calendar'), icon: 'calendar' },
          { name: 'hotel-concierge', to: '/admin/hotel/concierge', label: t('hotel.tabs.concierge'), icon: 'bell' },
          { name: 'hotel-reports', to: '/admin/hotel/reports', label: t('hotel.tabs.reports'), icon: 'dashboard' },
          { name: 'hotel-settings', to: '/admin/hotel/settings', label: t('hotel.tabs.settings'), icon: 'account' },
        ],
      },
      {
        name: 'catalogue',
        to: '/admin/products',
        label: t('nav.catalog'),
        icon: 'catalog',
        children: [
          { name: 'product-catalog', to: '/admin/products', label: t('nav.products'), icon: 'products' },
          { name: 'catalog-gallery', to: '/admin/catalog/gallery', label: t('nav.catalogGallery'), icon: 'catalog' },
          { name: 'customers', to: '/admin/customers', label: t('nav.customers'), icon: 'customers' },
          { name: 'crm', to: '/admin/crm', label: t('nav.crm'), icon: 'customers', module: 'crm' },
          { name: 'price-lists', to: '/admin/catalog/prices', label: t('nav.priceLists'), icon: 'tag' },
        ],
      },
      {
        name: 'pos-ops',
        to: '/admin/pos/overview',
        label: t('nav.group.posOps'),
        icon: 'store-pin',
        module: 'pos',
        children: [
          { name: 'pos-overview', to: '/admin/pos/overview', label: t('nav.posOverview'), icon: 'dashboard' },
          { name: 'pos-terminal', to: '/admin/pos/terminal', label: t('nav.posTerminal'), icon: 'device-pos' },
          { name: 'pos-orders', to: '/admin/pos/orders', label: t('nav.posOrders'), icon: 'sales' },
          { name: 'pos-shifts', to: '/admin/pos/shifts', label: t('nav.posShifts'), icon: 'shift' },
          { name: 'pos-reservations', to: '/admin/pos/reservations', label: t('nav.posReservations'), icon: 'calendar' },
        ],
      },
      {
        name: 'inventory',
        to: '/admin/inventory/stock',
        label: t('nav.inventoryHub'),
        icon: 'inventory',
        module: 'inventory',
        children: [
          { name: 'inventory-overview', to: '/admin/reports/inventory', label: t('nav.inventoryItems.overview'), icon: 'dashboard' },
          { name: 'inventory-products', to: '/admin/inventory/stock', label: t('nav.inventoryItems.products'), icon: 'products' },
          { name: 'catalog-brands', to: '/admin/catalog/brands', label: t('nav.inventoryItems.brands'), icon: 'tag' },
          { name: 'inventory-manufacturers', to: '/admin/inventory/manufacturers', label: t('nav.inventoryItems.manufacturers'), icon: 'organization' },
          { name: 'catalog-units', to: '/admin/catalog/units', label: t('nav.inventoryItems.units'), icon: 'package' },
          { name: 'inventory-transfers', to: '/admin/inventory/transfers', label: t('nav.inventoryItems.transfers'), icon: 'transfer' },
          { name: 'inventory-counts', to: '/admin/inventory/counts', label: t('nav.inventoryItems.counts'), icon: 'check' },
          { name: 'inventory-issues', to: '/admin/inventory/issues', label: t('nav.inventoryItems.exits'), icon: 'upload' },
          { name: 'catalog-taxes', to: '/admin/catalog/taxes', label: t('nav.inventoryItems.taxes'), icon: 'percent' },
          { name: 'catalog-categories', to: '/admin/catalog/categories', label: t('nav.inventoryItems.categories'), icon: 'layers' },
          { name: 'org-warehouses', to: '/admin/organization/warehouses', label: t('nav.inventoryItems.warehouses'), icon: 'inventory' },
          { name: 'inventory-adjustments', to: '/admin/inventory/adjustments', label: t('nav.inventoryItems.movements'), icon: 'adjust' },
          { name: 'suppliers', to: '/admin/suppliers', label: t('nav.inventoryItems.suppliers'), icon: 'suppliers' },
          { name: 'inventory-departments', to: '/admin/inventory/departments', label: t('nav.inventoryItems.departments'), icon: 'building' },
        ],
      },
      {
        name: 'purchasing',
        to: '/admin/purchases/overview',
        label: t('nav.purchasingHub'),
        icon: 'purchases',
        module: 'procurement',
        children: [
          { name: 'purchase-overview', to: '/admin/purchases/overview', label: t('purchases.hub.overview'), icon: 'dashboard' },
          { name: 'purchase-requisitions', to: '/admin/purchases/requisitions', label: t('purchases.hub.requisitions'), icon: 'note' },
          { name: 'purchase-proformas', to: '/admin/purchases/proformas', label: t('purchases.hub.proformas'), icon: 'receipt' },
          { name: 'purchase-orders', to: '/admin/purchases/orders', label: t('purchases.hub.orders'), icon: 'purchases' },
          { name: 'purchase-invoices', to: '/admin/purchases/invoices', label: t('purchases.hub.invoices'), icon: 'receipt' },
          { name: 'purchase-payments', to: '/admin/purchases/payments', label: t('purchases.hub.payments'), icon: 'coins' },
          { name: 'purchase-returns', to: '/admin/purchases/returns', label: t('purchases.hub.returns'), icon: 'transfer' },
        ],
      },
      {
        name: 'expense-tracker',
        to: '/admin/expenses/dashboard',
        label: t('nav.expenseTrackerHub'),
        icon: 'coins',
        module: 'expenses',
        children: [
          { name: 'expenses-dashboard', to: '/admin/expenses/dashboard', label: t('expenses.tabs.dashboard'), icon: 'dashboard' },
          { name: 'expenses-list', to: '/admin/expenses', label: t('expenses.tabs.list'), icon: 'note' },
          { name: 'expenses-categories', to: '/admin/expenses/categories', label: t('expenses.tabs.categories'), icon: 'layers' },
          { name: 'expenses-reports', to: '/admin/expenses/reports', label: t('expenses.tabs.reports'), icon: 'sales' },
          { name: 'expenses-recurring', to: '/admin/expenses/recurring', label: t('expenses.tabs.recurring'), icon: 'calendar' },
        ],
      },
      {
        name: 'reports',
        to: '/admin/reports/dashboard',
        label: t('nav.reports'),
        icon: 'dashboard',
        children: [
          { name: 'reports-dashboard', to: '/admin/reports/dashboard', label: t('reports.tabs.dashboard'), icon: 'dashboard' },
          { name: 'reports-sales', to: '/admin/reports/sales', label: t('reports.tabs.sales'), icon: 'sales', module: 'pos' },
          { name: 'reports-inventory', to: '/admin/reports/inventory', label: t('reports.tabs.inventory'), icon: 'inventory', module: 'inventory' },
          { name: 'reports-purchases', to: '/admin/reports/purchases', label: t('reports.tabs.purchases'), icon: 'purchases', module: 'procurement' },
          { name: 'reports-forecasts', to: '/admin/reports/forecasts', label: t('reports.tabs.forecasts'), icon: 'sparkles' },
          { name: 'reports-financial', to: '/admin/reports/financial', label: t('reports.tabs.revenue'), icon: 'coins', module: 'accounting' },
          { name: 'reports-condensed', to: '/admin/reports/condensed', label: t('reports.tabs.condensed'), icon: 'layers' },
          { name: 'reports-daily', to: '/admin/reports/daily', label: t('reports.tabs.daily'), icon: 'calendar' },
          { name: 'reports-user-performance', to: '/admin/reports/user-performance', label: t('reports.tabs.userPerformance'), icon: 'account' },
        ],
      },
      {
        name: 'sync-devices',
        to: '/admin/organization/devices',
        label: t('nav.syncDevicesHub'),
        icon: 'device-tablet',
        children: [
          { name: 'org-devices', to: '/admin/organization/devices', label: t('org.tabs.devices'), icon: 'device-tablet' },
        ],
      },
      {
        name: 'settings-hub',
        to: '/admin/settings/subscription',
        label: t('nav.settingsHub'),
        icon: 'account',
        children: [
          { name: 'settings-subscription', to: '/admin/settings/subscription', label: t('nav.settingsItems.subscription'), icon: 'key' },
          { name: 'settings-modules', to: '/admin/settings/modules', label: t('modules.title'), icon: 'layers' },
          { name: 'notifications', to: '/admin/notifications', label: t('nav.notifications'), icon: 'bell' },
          { name: 'settings-currency', to: '/admin/organization/currencies', label: t('nav.settingsItems.company'), icon: 'building' },
          { name: 'settings-merchant-qr', to: '/admin/settings/merchant-qr', label: t('nav.settingsItems.merchantQr'), icon: 'tag' },
          { name: 'design-system', to: '/admin/design', label: t('nav.settingsItems.design'), icon: 'sparkles' },
        ],
      },
      {
        name: 'customer-hub',
        to: '/admin/customer-hub/dashboard',
        label: t('nav.customerHub'),
        icon: 'customers',
        children: [
          { name: 'customer-hub-dashboard', to: '/admin/customer-hub/dashboard', label: t('nav.customerHubItems.dashboard'), icon: 'dashboard' },
          { name: 'customer-hub-link-requests', to: '/admin/customer-hub/link-requests', label: t('nav.customerHubItems.linkRequests'), icon: 'key' },
          { name: 'customer-hub-linked-users', to: '/admin/customer-hub/linked-users', label: t('nav.customerHubItems.linkedUsers'), icon: 'customers' },
          { name: 'customer-hub-mobile-orders', to: '/admin/customer-hub/mobile-orders', label: t('nav.customerHubItems.mobileOrders'), icon: 'device-tablet' },
          { name: 'customer-hub-payments', to: '/admin/customer-hub/payments', label: t('nav.customerHubItems.payments'), icon: 'coins' },
        ],
      },
      {
        name: 'space-orders',
        to: '/admin/settings/orders',
        label: t('nav.spaceOrdersHub'),
        icon: 'purchases',
        children: [
          { name: 'settings-orders', to: '/admin/settings/orders', label: t('nav.settingsItems.orders'), icon: 'sales' },
          { name: 'settings-analytics', to: '/admin/settings/analytics', label: t('nav.settingsItems.analytics'), icon: 'dashboard' },
        ],
      },
      { name: 'app-versions', to: '/admin/settings/app-versions', label: t('nav.settingsItems.appVersions'), icon: 'device-tablet' },
      { name: 'restaurant', to: '/admin/hospitality', label: t('nav.restaurant'), icon: 'store-pin', module: 'restaurant' },
      { name: 'accounting', to: '/admin/accounting', label: t('nav.accounting'), icon: 'coins', module: 'accounting' },
      { name: 'manufacturing', to: '/admin/production', label: t('nav.production'), icon: 'package', module: 'manufacturing' },
      {
        name: 'extensions',
        to: '/admin/settings/modules',
        label: t('modules.more'),
        icon: 'layers',
        children: [
          { name: 'module-hr', to: '/admin/modules/hr', label: t('modules.names.hr'), icon: 'customers', module: 'hr' },
          { name: 'module-projects', to: '/admin/modules/projects', label: t('modules.names.projects'), icon: 'layers', module: 'projects' },
          { name: 'module-documents', to: '/admin/modules/documents', label: t('modules.names.documents'), icon: 'note', module: 'documents' },
          { name: 'module-fleet', to: '/admin/modules/fleet', label: t('modules.names.fleet'), icon: 'transfer', module: 'fleet' },
          { name: 'module-maintenance', to: '/admin/modules/maintenance', label: t('modules.names.maintenance'), icon: 'adjust', module: 'maintenance' },
          { name: 'module-ecommerce', to: '/admin/modules/ecommerce', label: t('modules.names.ecommerce'), icon: 'catalog', module: 'ecommerce' },
        ],
      },
    ] as NavItem[],
  },
])

const visibleNav = computed(() => {
  const platformOnly = auth.user?.is_super_admin === true && !auth.user.tenant_id
  const enabled = auth.user?.modules
  return navSections.value.map(section => ({
    ...section,
    items: section.items.flatMap(item => {
      if (platformOnly) {
        return item.name === 'platform' || item.name.startsWith('platform-') ? [item] : []
      }
      if (item.name === 'platform' || !moduleEnabled(enabled, item.module)) return []
      if (!item.children) return [item]
      const children = item.children.filter(child => moduleEnabled(enabled, child.module))
      return children.length ? [{ ...item, children }] : []
    }),
  })).filter(section => section.items.length > 0)
})

const userInitials = computed(() => {
  const name = auth.user?.name ?? '?'
  return name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()
})

const company = computed(() => {
  return context.currentStore?.branch?.company
    ?? context.stores.find(store => store.branch?.company)?.branch?.company
    ?? null
})

const companyName = computed(() => {
  const name = company.value?.trade_name?.trim()
    || company.value?.name?.trim()
    || brandingStore.branding?.company?.trade_name?.trim()
    || brandingStore.branding?.company?.name?.trim()
    || brandingStore.branding?.brand_name?.trim()
    || 'ITARA NEXUS Business CORE'
  return name
})

const companyInitials = computed(() => {
  const parts = companyName.value.split(/\s+/).filter(Boolean)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return companyName.value.slice(0, 2).toUpperCase()
})

const brandLines = computed(() => {
  const parts = companyName.value.split(/\s+/).filter(Boolean)
  if (parts.length <= 1) return { primary: companyName.value, secondary: '' }
  return { primary: parts[0], secondary: parts.slice(1).join(' ') }
})

const accentColor = computed(() => brandingStore.branding?.accent_color || 'var(--color-brand-500)')

const logoFailed = ref(false)
const companyLogo = computed(() => {
  const active = company.value
  const profile = brandingStore.branding?.company
  return active?.logo_url?.trim()
    || active?.settings?.invoice_logo_url?.trim()
    || profile?.logo_url?.trim()
    || brandingStore.branding?.logo_url?.trim()
    || ''
})

watch(companyLogo, () => {
  logoFailed.value = false
})

function isActive(path: string) {
  if (path === '/admin') return route.path === '/admin'
  return route.path === path || route.path.startsWith(path + '/')
}

function matchesChild(child: NavChild) {
  if (child.to === '/admin/products') return route.path.startsWith('/admin/products')
  if (child.to === '/admin/customers') return route.path.startsWith('/admin/customers')
  if (child.to === '/admin/pos/orders') {
    return route.path.startsWith('/admin/pos/orders')
      || (route.path.startsWith('/admin/sales') && !route.path.startsWith('/admin/sales/returns'))
  }
  if (child.to === '/admin/sales/returns') return route.path.startsWith('/admin/sales/returns')
  if (child.to === '/admin/pos/shifts') return route.path.startsWith('/admin/pos/shifts')
  if (child.to === '/admin/pos/terminal') {
    return route.path === '/admin/pos/terminal' || route.path === '/admin/pos'
  }
  if (child.to === '/admin/expenses') {
    return route.path === '/admin/expenses'
  }
  return route.path === child.to || route.path.startsWith(child.to + '/')
}

function isChildActive(child: NavChild) {
  if (!matchesChild(child)) return false
  const children = navSections.value.flatMap(section => section.items.flatMap(item => item.children ?? []))
  return !children.some(other => other.to !== child.to && other.to.length > child.to.length && matchesChild(other))
}

function isGroupActive(item: NavItem) {
  if (item.children?.length) return item.children.some(isChildActive)
  return isActive(item.to)
}

function isExpanded(item: NavItem) {
  return openMenuId.value === item.name
}

function activeMenuId() {
  for (const section of visibleNav.value) {
    for (const item of section.items) {
      if (item.children?.length && isGroupActive(item)) return item.name
    }
  }
  return null
}

function toggleMenu(item: NavItem) {
  if (!item.children?.length) return
  if (!isDesktop.value && !drawerOpen.value) {
    drawerOpen.value = true
    openMenuId.value = item.name
    return
  }
  if (isDesktop.value && !sidebarOpen.value) {
    sidebarOpen.value = true
    openMenuId.value = item.name
    return
  }
  openMenuId.value = isExpanded(item) ? null : item.name
}

const submenuMotionMs = 220
let scrollTimer = 0
let navReady = false

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

function visibleActiveLink() {
  const nav = navEl.value
  if (!nav) return null
  const links = [...nav.querySelectorAll<HTMLElement>('.app-nav-link--active')]
  const visible = links.filter((el) => {
    const rect = el.getBoundingClientRect()
    return rect.width > 0 && rect.height > 0
  })
  return visible.find((el) => el.classList.contains('app-nav-link--child')) ?? visible[visible.length - 1] ?? null
}

function isFullyInView(container: HTMLElement, el: HTMLElement) {
  const box = container.getBoundingClientRect()
  const rect = el.getBoundingClientRect()
  return rect.top >= box.top - 1 && rect.bottom <= box.bottom + 1
}

function scrollActiveIntoView() {
  const nav = navEl.value
  const el = visibleActiveLink()
  if (!nav || !el || isFullyInView(nav, el)) return
  const box = nav.getBoundingClientRect()
  const rect = el.getBoundingClientRect()
  const top = nav.scrollTop + (rect.top - box.top) - (box.height / 2) + (rect.height / 2)
  nav.scrollTo({
    top: Math.max(0, top),
    behavior: prefersReducedMotion() ? 'auto' : 'smooth',
  })
}

function scheduleScroll(waitForSubmenu: boolean) {
  window.clearTimeout(scrollTimer)
  const delay = waitForSubmenu && !prefersReducedMotion() ? submenuMotionMs : 0
  scrollTimer = window.setTimeout(() => {
    void nextTick(() => requestAnimationFrame(() => scrollActiveIntoView()))
  }, delay)
}

type SubNode = HTMLElement & { _subTimer?: number }

function clearSubTimer(node: SubNode) {
  if (node._subTimer === undefined) return
  window.clearTimeout(node._subTimer)
  node._subTimer = undefined
}

function resetSubMotion(node: HTMLElement) {
  node.style.transition = ''
  node.style.height = ''
  node.style.opacity = ''
  node.style.overflow = ''
}

function onSubEnter(el: Element, done: () => void) {
  const node = el as SubNode
  clearSubTimer(node)
  if (prefersReducedMotion()) {
    resetSubMotion(node)
    done()
    return
  }
  let settled = false
  const finish = (event?: TransitionEvent) => {
    if (settled) return
    if (event && (event.target !== node || event.propertyName !== 'height')) return
    settled = true
    clearSubTimer(node)
    node.removeEventListener('transitionend', finish)
    done()
  }
  node.style.overflow = 'hidden'
  node.style.height = '0px'
  node.style.opacity = '0'
  node.addEventListener('transitionend', finish)
  requestAnimationFrame(() => {
    const height = node.scrollHeight
    node.style.transition = `height ${submenuMotionMs}ms var(--ease-out), opacity 200ms var(--ease-out)`
    node.style.height = `${height}px`
    node.style.opacity = '1'
    node._subTimer = window.setTimeout(() => finish(), submenuMotionMs + 40)
    if (height === 0) finish()
  })
}

function onSubAfterEnter(el: Element) {
  resetSubMotion(el as HTMLElement)
}

function onSubLeave(el: Element, done: () => void) {
  const node = el as SubNode
  clearSubTimer(node)
  if (prefersReducedMotion()) {
    done()
    return
  }
  node.style.overflow = 'hidden'
  node.style.height = `${node.scrollHeight}px`
  node.style.opacity = '1'
  requestAnimationFrame(() => {
    node.style.transition = `height ${submenuMotionMs}ms var(--ease-out), opacity 200ms var(--ease-out)`
    node.style.height = '0px'
    node.style.opacity = '0'
  })
  node._subTimer = window.setTimeout(() => {
    node._subTimer = undefined
    resetSubMotion(node)
    done()
  }, submenuMotionMs)
}

function focusableNavItems() {
  const nav = navEl.value
  if (!nav) return []
  return [...nav.querySelectorAll<HTMLElement>('.app-nav-link')].filter((el) => {
    const rect = el.getBoundingClientRect()
    return rect.width > 0 && rect.height > 0
  })
}

function onNavKeydown(event: KeyboardEvent) {
  const current = (event.target as HTMLElement | null)?.closest<HTMLElement>('.app-nav-link')
  if (!current || !navEl.value?.contains(current)) return
  const items = focusableNavItems()
  const index = items.indexOf(current)
  if (index < 0) return

  if (event.key === 'ArrowDown' || event.key === 'ArrowUp' || event.key === 'Home' || event.key === 'End') {
    event.preventDefault()
    const next = event.key === 'ArrowDown'
      ? items[Math.min(items.length - 1, index + 1)]
      : event.key === 'ArrowUp'
        ? items[Math.max(0, index - 1)]
        : event.key === 'Home'
          ? items[0]
          : items[items.length - 1]
    next?.focus()
    return
  }

  if (event.key === 'ArrowRight' && current.classList.contains('app-nav-link--parent')) {
    event.preventDefault()
    const name = current.dataset.menu
    if (!name) return
    if (openMenuId.value !== name) openMenuId.value = name
    window.setTimeout(() => {
      navEl.value?.querySelector<HTMLElement>(`#nav-sub-${CSS.escape(name)} .app-nav-link`)?.focus()
    }, prefersReducedMotion() ? 0 : submenuMotionMs)
    return
  }

  if (event.key === 'ArrowLeft' && current.classList.contains('app-nav-link--child')) {
    event.preventDefault()
    const parent = current.closest('.app-nav-sub')?.previousElementSibling
    if (parent instanceof HTMLElement) parent.focus()
    return
  }

  if (event.key === 'ArrowLeft' && current.classList.contains('app-nav-link--parent') && current.getAttribute('aria-expanded') === 'true') {
    event.preventDefault()
    openMenuId.value = null
  }
}

function toggleSidebar() {
  if (!isDesktop.value) {
    drawerOpen.value = !drawerOpen.value
    return
  }
  sidebarOpen.value = !sidebarOpen.value
}

function closeDrawer() {
  drawerOpen.value = false
}

watch(
  () => route.path,
  () => {
    const nextId = activeMenuId()
    const opening = nextId !== null && nextId !== openMenuId.value
    openMenuId.value = nextId
    if (navReady) scheduleScroll(opening)
  },
  { immediate: true },
)

watch(sidebarOpen, (open) => {
  if (navReady) scheduleScroll(open && openMenuId.value !== null)
})

watch(drawerOpen, (open) => {
  document.body.classList.toggle('nav-drawer-open', open)
  if (open && navReady) scheduleScroll(openMenuId.value !== null)
})

function onStoreChange(event: Event) {
  const id = (event.target as HTMLSelectElement).value
  context.selectStore(id || null)
}

function placeUserMenu() {
  const rect = userMenuTrigger.value?.getBoundingClientRect()
  if (!rect) return
  userMenuStyle.value = {
    top: `${rect.bottom + 8}px`,
    right: `${Math.max(12, window.innerWidth - rect.right)}px`,
  }
}

function onUserMenuPointer(event: PointerEvent) {
  const target = event.target as Node
  if (userMenuTrigger.value?.contains(target) || userMenuPanel.value?.contains(target)) return
  userMenuOpen.value = false
}

function onUserMenuKey(event: KeyboardEvent) {
  if (event.key === 'Escape') userMenuOpen.value = false
}

function goUserMenu(path: string) {
  userMenuOpen.value = false
  router.push(path)
}

async function logout() {
  userMenuOpen.value = false
  realtime.disconnect()
  await auth.logout()
  brandingStore.clear()
  context.reset()
  router.push({ name: 'login' })
}

function onSidebarPref(event: Event) {
  sidebarOpen.value = Boolean((event as CustomEvent<boolean>).detail)
}

onMounted(() => {
  navReady = true
  scheduleScroll(openMenuId.value !== null)
  syncViewport()
  window.addEventListener('pointerdown', onUserMenuPointer)
  window.addEventListener('keydown', onUserMenuKey)
  window.addEventListener('resize', placeUserMenu)
  window.addEventListener('resize', syncViewport)
  window.addEventListener('pos-sidebar-pref', onSidebarPref)
  void brandingStore.loadCurrent().catch(() => undefined)
  offline.start()
  realtime.connect()
})

onBeforeUnmount(() => {
  window.clearTimeout(scrollTimer)
  window.removeEventListener('pointerdown', onUserMenuPointer)
  window.removeEventListener('keydown', onUserMenuKey)
  window.removeEventListener('resize', placeUserMenu)
  window.removeEventListener('resize', syncViewport)
  window.removeEventListener('pos-sidebar-pref', onSidebarPref)
  document.body.classList.remove('nav-drawer-open')
  offline.stop()
  realtime.disconnect()
})

watch(() => route.path, () => {
  userMenuOpen.value = false
  drawerOpen.value = false
})

watch(() => context.currentStoreId, (storeId) => {
  realtime.resubscribe()
  void backoffice.loadStoreTaxonomies(storeId, company.value?.id)
}, { immediate: true })

watch(userMenuOpen, async (open) => {
  if (!open) return
  await nextTick()
  placeUserMenu()
})

const HeaderTitle = computed(() => ({
  setup: () => () => pageHeader.titleSlot?.() ?? slots.title?.() ?? null,
}))
const HeaderSubtitle = computed(() => ({
  setup: () => () => pageHeader.subtitleSlot?.() ?? slots.subtitle?.() ?? null,
}))
const hasSubtitle = computed(() => Boolean(pageHeader.subtitleSlot || slots.subtitle))
const pageMotion = computed(() => (route.path.startsWith('/admin/pos/terminal') ? 'page-instant' : 'page'))
</script>

<template>
  <div class="app-shell">
    <Transition name="fade">
      <div
        v-if="drawerOpen"
        class="app-sidebar-backdrop"
        @click="closeDrawer"
      />
    </Transition>
    <aside
      class="app-sidebar"
      :class="{
        'app-sidebar--collapsed': isDesktop && !sidebarOpen,
        'app-sidebar--drawer-open': drawerOpen,
      }"
    >
      <div class="app-sidebar__brand">
        <div class="app-sidebar__logo">
          <img
            v-if="companyLogo && !logoFailed"
            :src="companyLogo"
            :alt="companyName"
            @error="logoFailed = true"
          />
          <span v-else class="app-sidebar__mark" :aria-label="companyName">{{ companyInitials }}</span>
        </div>
        <div class="app-sidebar__brand-text min-w-0 flex-1">
          <p class="font-brand m-0 text-sm font-bold tracking-[0.04em] text-slate-900">{{ brandLines.primary }}</p>
          <p
            v-if="brandLines.secondary"
            class="font-brand m-0 text-[0.6875rem] tracking-[0.12em] text-slate-500"
          >{{ brandLines.secondary }}</p>
          <p class="m-0 mt-0.5 text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-400">Admin Panel</p>
        </div>
        <button
          type="button"
          class="sidebar-toggle"
          :title="sidebarOpen ? t('nav.collapseMenu') : t('nav.expandMenu')"
          :aria-label="sidebarOpen ? t('nav.collapseMenu') : t('nav.expandMenu')"
          @click="toggleSidebar"
        >
          <AppIcon name="chevron-right" :size="16" class="sidebar-toggle__icon" :class="{ 'sidebar-toggle__icon--open': isDesktop ? sidebarOpen : drawerOpen }" />
        </button>
      </div>
      <button type="button" class="module-search-btn" @click="moduleSearch?.show()">
        <AppIcon name="search" :size="18" />
        <span>{{ t('command.open') }}</span>
        <kbd>Ctrl K</kbd>
      </button>

      <nav ref="navEl" class="app-sidebar__nav" @keydown="onNavKeydown">
        <div v-for="section in visibleNav" :key="section.label">
          <p class="app-sidebar__section-label">{{ section.label }}</p>
          <template v-for="item in section.items" :key="item.name">
            <template v-if="item.children?.length">
              <button
                type="button"
                class="app-nav-link app-nav-link--parent"
                :class="{ 'app-nav-link--active': isGroupActive(item), 'app-nav-link--open': isExpanded(item) }"
                :data-menu="item.name"
                :title="item.label"
                :aria-expanded="isExpanded(item)"
                :aria-controls="`nav-sub-${item.name}`"
                @click="toggleMenu(item)"
              >
                <AppIcon :name="item.icon" :size="18" />
                <span class="min-w-0 flex-1 text-left">{{ item.label }}</span>
                <AppIcon
                  name="chevron-right"
                  :size="16"
                  class="app-nav-link__chevron"
                  :class="{ 'app-nav-link__chevron--open': isExpanded(item) }"
                />
              </button>
              <Transition @enter="onSubEnter" @after-enter="onSubAfterEnter" @leave="onSubLeave">
                <div v-show="isExpanded(item)" :id="`nav-sub-${item.name}`" class="app-nav-sub">
                  <div
                    v-for="child in item.children"
                    :key="child.name"
                    class="app-nav-sub__item"
                  >
                    <span class="app-nav-link__branch" aria-hidden="true"></span>
                    <RouterLink
                      :to="child.to"
                      class="app-nav-link app-nav-link--child"
                      :class="{ 'app-nav-link--active': isChildActive(child) }"
                      :aria-current="isChildActive(child) ? 'page' : undefined"
                    >
                      <span class="app-nav-link__mark" aria-hidden="true">
                        <AppIcon :name="child.icon" :size="18" />
                      </span>
                      <span class="min-w-0 flex-1 text-left">{{ child.label }}</span>
                    </RouterLink>
                  </div>
                </div>
              </Transition>
            </template>
            <RouterLink
              v-else
              :to="item.to"
              class="app-nav-link"
              :class="{ 'app-nav-link--active': isActive(item.to) }"
              :aria-current="isActive(item.to) ? 'page' : undefined"
              :title="item.label"
            >
              <AppIcon :name="item.icon" :size="18" />
              <span class="min-w-0 flex-1 text-left">{{ item.label }}</span>
            </RouterLink>
          </template>
        </div>
      </nav>
    </aside>
    <ModuleSearch ref="moduleSearch" />

    <div class="app-main">
      <header class="app-topbar">
        <div class="topbar-start">
          <button
            type="button"
            class="topbar-menu-btn"
            :aria-label="t('nav.expandMenu')"
            @click="drawerOpen = true"
          >
            <AppIcon name="menu" :size="18" />
          </button>
          <div class="app-topbar__heading">
            <h1 class="app-topbar__title">
              <component :is="HeaderTitle" />
            </h1>
            <p v-if="hasSubtitle" class="app-topbar__subtitle">
              <component :is="HeaderSubtitle" />
            </p>
          </div>
        </div>

        <div class="topbar-tools">
          <OfflineIndicator />
          <RealtimeIndicator />
          <StockAlertBell />
          <AppCalculator />
          <LanguageSwitcher />
          <div v-if="context.activeStores.length" class="store-pill">
            <AppIcon name="store-pin" :size="16" class="text-brand-500 shrink-0" />
            <select
              :value="context.currentStoreId ?? ''"
              class="store-pill__select"
              @change="onStoreChange"
            >
              <option v-for="s in context.activeStores" :key="s.id" :value="s.id">
                {{ context.storeLabel(s) }}
              </option>
            </select>
          </div>
          <div class="user-menu">
            <button
              ref="userMenuTrigger"
              type="button"
              class="user-menu__trigger"
              :class="{ 'user-menu__trigger--open': userMenuOpen }"
              :title="auth.user?.name"
              :aria-expanded="userMenuOpen"
              aria-haspopup="menu"
              @click="userMenuOpen = !userMenuOpen"
            >
              <span class="user-chip__avatar">{{ userInitials }}</span>
              <span class="user-menu__identity">
                <span class="user-menu__name">{{ auth.user?.name }}</span>
                <span class="user-menu__email">{{ auth.user?.email }}</span>
              </span>
              <AppIcon name="chevron-right" :size="16" class="user-menu__caret" :class="{ 'user-menu__caret--open': userMenuOpen }" />
            </button>
          </div>
          <Teleport to="body">
            <Transition name="menu-pop">
              <div
                v-if="userMenuOpen"
                ref="userMenuPanel"
                class="user-menu__panel"
                :style="userMenuStyle"
                role="menu"
              >
                <p class="user-menu__heading">{{ auth.user?.name }}</p>
                <button type="button" class="user-menu__item" role="menuitem" @click="goUserMenu('/admin')">
                  <AppIcon name="dashboard" :size="18" />
                  {{ t('nav.dashboard') }}
                </button>
                <button type="button" class="user-menu__item" role="menuitem" @click="goUserMenu('/admin/profile')">
                  <AppIcon name="account" :size="18" />
                  {{ t('auth.profile') }}
                </button>
                <button type="button" class="user-menu__item" role="menuitem" @click="goUserMenu('/admin/settings')">
                  <AppIcon name="organization" :size="18" />
                  {{ t('auth.settings') }}
                </button>
                <button type="button" class="user-menu__item" role="menuitem" @click="cycleTheme">
                  <AppIcon :name="themeIcon" :size="18" />
                  {{ t(`auth.theme.${preference}`) }}
                </button>
                <button type="button" class="user-menu__item user-menu__item--danger" role="menuitem" @click="logout">
                  <AppIcon name="logout" :size="18" />
                  {{ t('auth.logout') }}
                </button>
              </div>
            </Transition>
          </Teleport>
        </div>
      </header>

      <p v-if="billingBanner" class="billing-banner" :class="{ 'billing-banner--blocked': auth.user?.subscription?.status === 'suspended' }">
        <span>{{ billingBanner }}</span>
        <RouterLink to="/admin/settings/subscription">{{ t('subscriptionPage.bannerAction') }}</RouterLink>
      </p>

      <main class="app-content">
        <Transition :name="pageMotion" mode="out-in">
          <div :key="route.path" class="page-stage">
            <RouterView />
          </div>
        </Transition>
      </main>
    </div>
  </div>
</template>

<style scoped>
.text-brand-500 { color: var(--color-ink-brand, var(--color-brand-500));}
.billing-banner {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  align-items: center;
  justify-content: space-between;
  margin: 0;
  padding: 0.7rem 1rem;
  background: var(--color-warning-bg, #fffbeb);
  color: var(--color-text-primary);
  font-size: 0.875rem;
}
.billing-banner--blocked { background: var(--color-danger-bg, #fef2f2); }
.billing-banner a { font-weight: 650; color: inherit; }

.topbar-start {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: var(--header-gap);
}

.topbar-tools {
  display: flex;
  align-items: center;
  gap: var(--header-gap);
}

.module-search-btn {
  display: flex;
  align-items: center;
  gap: var(--nav-icon-gap);
  height: auto;
  min-height: var(--control-lg);
  width: calc(100% - var(--space-6));
  margin: var(--space-3) var(--space-3) var(--space-2);
  border: 1px solid var(--color-sidebar-border);
  border-radius: var(--radius-md);
  background: var(--color-sidebar-elevated);
  color: var(--color-sidebar-muted);
  padding: var(--nav-item-pad-y) var(--nav-item-pad-x);
  font-size: var(--text-md);
  font-weight: 500;
  line-height: var(--line-sm);
  cursor: pointer;
  transition:
    background var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out);
}

.module-search-btn:hover {
  background: var(--color-sidebar-hover);
  border-color: var(--color-sidebar-border);
  color: var(--color-sidebar-text-strong);
}

.module-search-btn svg {
  flex-shrink: 0;
  color: inherit;
}

.module-search-btn span {
  flex: 1;
  text-align: left;
}

.module-search-btn kbd {
  border: 1px solid var(--color-sidebar-border);
  border-radius: var(--radius-sm);
  background: var(--color-sidebar);
  padding: 2px var(--space-2);
  font-size: var(--text-xs);
  color: var(--color-sidebar-muted);
  font-family: var(--font-sans);
}

.user-menu__trigger {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  height: var(--control-md);
  min-width: var(--control-md);
  max-width: 16rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  padding: 0 var(--space-2) 0 var(--space-1);
  cursor: pointer;
}

.user-menu__trigger .user-chip__avatar {
  width: var(--control-sm);
  height: var(--control-sm);
}

.user-menu__trigger--open {
  border-color: var(--color-brand-600);
  box-shadow: 0 0 0 2px var(--color-focus-ring);
}

.user-menu__identity {
  display: flex;
  min-width: 0;
  flex-direction: column;
  justify-content: center;
  text-align: left;
}

.user-menu__name {
  overflow: hidden;
  font-size: var(--text-sm);
  font-weight: 500;
  line-height: var(--line-sm);
  color: var(--color-text-primary);
  text-overflow: ellipsis;
  white-space: nowrap;}

.user-menu__email {
  display: none;
}

.user-menu__caret {
  flex-shrink: 0;
  color: var(--color-text-muted);
  transform: rotate(90deg);
  transition: transform var(--motion-fast) var(--ease-in-out);}

.user-menu__caret--open {
  transform: rotate(-90deg);
}

.user-menu__panel {
  position: fixed;
  z-index: 500;
  width: 15.5rem;
  overflow: hidden;
  padding: var(--overlay-pad);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);
}

.user-menu__heading {
  margin: 0;
  padding: var(--overlay-item-pad-y) var(--overlay-item-pad-x);
  font-size: var(--text-xs);
  font-weight: 600;
  line-height: var(--line-xs);
  color: var(--color-text-muted);}

.user-menu__item {
  display: flex;
  width: 100%;
  align-items: center;
  gap: var(--nav-icon-gap);
  height: auto;
  min-height: var(--control-md);
  border: 0;
  border-radius: var(--radius-sm);
  background: transparent;
  padding: var(--overlay-item-pad-y) var(--overlay-item-pad-x);
  text-align: left;
  font-size: var(--text-md);
  font-weight: 500;
  line-height: var(--line-sm);
  color: var(--color-text-primary);
  cursor: pointer;}

.user-menu__item:hover {
  background: var(--color-table-row-hover);}

.user-menu__item--danger {
  color: light-dark(#b91c1c, #e2a0a0);}

@media (max-width: 767px) {
  .user-menu__identity {
    display: none;
  }
}
</style>
