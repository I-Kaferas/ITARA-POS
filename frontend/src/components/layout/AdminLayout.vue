<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useSlots, watch, watchEffect } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import LanguageSwitcher from '../ui/LanguageSwitcher.vue'
import AppCalculator from './AppCalculator.vue'
import ModuleSearch from './ModuleSearch.vue'
import StockAlertBell from './StockAlertBell.vue'
import { useAuthStore } from '../../stores/auth'
import { usePosStore } from '../../stores/pos'
import { moduleEnabled, moduleRequiredForPath } from '../../modules/registry'
import { useBackofficeStore } from '../../stores/backoffice'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'
import { usePageHeaderStore } from '../../stores/pageHeader'
import { useOfflineStore } from '../../stores/offline'
import { useRealtimeStore } from '../../stores/realtime'
import { resolvedTheme, useTheme } from '../../composables/useTheme'
import { goToMarketing } from '../../utils/marketing'

type NavChild = {
  name: string
  to: string
  label: string
  icon: string
  color?: string
  module?: string | string[]
  children?: NavChild[]
}
type NavItem = {
  name: string
  to: string
  label: string
  icon: string
  module?: string | string[]
  children?: NavChild[]
}

const { t } = useI18n()
const { preference, setTheme } = useTheme()
const appearance = computed(() => resolvedTheme(preference.value))
function toggleAppearance() {
  setTheme(appearance.value === 'dark' ? 'light' : 'dark')
}
const route = useRoute()
const router = useRouter()
const quietHeading = computed(() => {
  const path = route.path
  return path === '/admin' || path.endsWith('/dashboard') || path === '/admin/hotel/stock' || path.startsWith('/admin/customer-hub')
})
const slots = useSlots()
const auth = useAuthStore()

async function leaveSupport() {
  await auth.returnToPlatform()
  await router.push('/admin/platform')
}
const pos = usePosStore()
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
const storeMenuOpen = ref(false)
const storeMenuTrigger = ref<HTMLElement | null>(null)
const storeMenuPanel = ref<HTMLElement | null>(null)
const storeMenuStyle = ref<Record<string, string>>({})
const storeMenuActive = ref(0)

const openMenuId = ref<string | null>(null)
const navEl = ref<HTMLElement | null>(null)
const sidebarOpen = ref(localStorage.getItem('pos_sidebar_open') !== '0')
const drawerOpen = ref(false)
const isDesktop = ref(typeof window === 'undefined' ? true : window.innerWidth >= 1024)

watch(sidebarOpen, (open) => {
  localStorage.setItem('pos_sidebar_open', open ? '1' : '0')
})

watch([sidebarOpen, isDesktop], () => {
  document.documentElement.classList.toggle('sidebar-collapsed', isDesktop.value && !sidebarOpen.value)
}, { immediate: true })

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
          { name: 'platform-licenses', to: '/admin/platform/licenses', label: t('platform.nav.licenses'), icon: 'key' },
          { name: 'platform-modules', to: '/admin/platform/modules', label: t('platform.nav.modules'), icon: 'layers' },
          { name: 'platform-devices', to: '/admin/platform/devices', label: t('platform.nav.devices'), icon: 'device-tablet' },
          { name: 'platform-users', to: '/admin/platform/users', label: t('platform.nav.users'), icon: 'customers' },
          { name: 'platform-support', to: '/admin/platform/support', label: t('platform.nav.support'), icon: 'mail' },
          { name: 'platform-audit', to: '/admin/platform/audit', label: t('platform.nav.audit'), icon: 'receipt' },
          { name: 'platform-backups', to: '/admin/platform/backups', label: t('platform.nav.backups'), icon: 'download' },
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
          { name: 'org-stores', to: '/admin/organization/stores', label: t('org.tabs.stores'), icon: 'stores' },
          { name: 'org-users', to: '/admin/organization/users', label: t('org.tabs.users'), icon: 'account' },
          { name: 'settings-currency', to: '/admin/organization/currencies', label: t('nav.settingsItems.company'), icon: 'building' },
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
        name: 'help-support',
        to: '/admin/help/guide',
        label: t('nav.helpHub'),
        icon: 'info',
        children: [
          { name: 'help-guide', to: '/admin/help/guide', label: t('nav.helpItems.guide'), icon: 'note' },
          { name: 'help-tutorials', to: '/admin/help/tutorials', label: t('nav.helpItems.tutorials'), icon: 'tv' },
          { name: 'help-faqs', to: '/admin/help/faqs', label: t('nav.helpItems.faqs'), icon: 'search' },
          { name: 'help-desk', to: '/admin/help/support', label: t('nav.helpItems.support'), icon: 'mail' },
          { name: 'help-about', to: '/admin/help/about', label: t('nav.helpItems.about'), icon: 'building' },
        ],
      },
      {
        name: 'space-orders',
        to: '/admin/settings/orders',
        label: t('nav.spaceOrdersHub'),
        icon: 'purchases',
        children: [
          { name: 'settings-orders', to: '/admin/settings/orders', label: t('nav.settingsItems.orders'), icon: 'sales' },
          {
            name: 'settings-analytics',
            to: '/admin/settings/analytics',
            label: t('nav.settingsItems.analytics'),
            icon: 'dashboard',
            children: [
              { name: 'settings-merchant-qr', to: '/admin/settings/merchant-qr', label: t('nav.settingsItems.merchantQr'), icon: 'tag' },
            ],
          },
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
  const allowed = (item: { module?: string; to: string }) =>
    moduleEnabled(enabled, item.module) && moduleEnabled(enabled, moduleRequiredForPath(item.to))

  return navSections.value.map(section => ({
    ...section,
    items: section.items.flatMap(item => {
      if (platformOnly) {
        return item.name === 'platform' || item.name.startsWith('platform-') ? [item] : []
      }
      if (item.name === 'platform' || !allowed(item)) return []
      if (!item.children) return [item]
      const children = item.children.flatMap(child => {
        if (!allowed(child)) return []
        if (!child.children?.length) return [child]
        const nested = child.children.filter(grand => allowed(grand))
        return [{ ...child, children: nested }]
      })
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
  const profile = company.value ?? brandingStore.branding?.company
  return profile?.name?.trim()
    || profile?.trade_name?.trim()
    || brandingStore.branding?.brand_name?.trim()
    || 'ITARA NEXUS Business CORE'
})

const companyInitials = computed(() => {
  const parts = companyName.value.split(/\s+/).filter(Boolean)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return companyName.value.slice(0, 2).toUpperCase()
})

const brandLines = computed(() => ({ primary: companyName.value, secondary: '' }))

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
  const current = route.path.length > 1 ? route.path.replace(/\/+$/, '') : route.path
  const target = path.length > 1 ? path.replace(/\/+$/, '') : path
  if (target === '/admin') return current === '/admin' || route.name === 'dashboard'
  return current === target || current.startsWith(`${target}/`)
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

function isNestedActive(child: NavChild) {
  return child.children?.some(grand => matchesChild(grand)) ?? false
}

function isGroupActive(item: NavItem) {
  if (item.children?.length) return item.children.some(child => isChildActive(child) || isNestedActive(child))
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

const submenuMotionMs = 280
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
    node.style.transition = `height ${submenuMotionMs}ms var(--ease-emphasized), opacity 220ms var(--ease-emphasized)`
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
    node.style.transition = `height ${submenuMotionMs}ms var(--ease-emphasized), opacity 220ms var(--ease-emphasized)`
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

function storeParts(store: { name: string; branch?: { name?: string | null; company?: { name?: string | null } | null } | null }) {
  const branch = store.branch?.name?.trim() || ''
  const title = store.name?.trim() || branch || '—'
  const same = (value: string) => value.toLowerCase() === title.toLowerCase()
  const place = branch && !same(branch) ? branch : ''
  return { title, place, meta: place }
}

const currentStoreParts = computed(() => {
  const store = context.currentStore
  return store ? storeParts(store) : { title: '', place: '', meta: '' }
})

function placeStoreMenu() {
  const rect = storeMenuTrigger.value?.getBoundingClientRect()
  if (!rect) return
  storeMenuStyle.value = {
    top: `${rect.bottom + 8}px`,
    right: `${Math.max(12, window.innerWidth - rect.right)}px`,
    width: `${Math.max(rect.width, 360)}px`,
  }
}

function toggleStoreMenu() {
  storeMenuOpen.value = !storeMenuOpen.value
  if (!storeMenuOpen.value) return
  userMenuOpen.value = false
  const index = context.activeStores.findIndex(store => store.id === context.currentStoreId)
  storeMenuActive.value = index >= 0 ? index : 0
  void nextTick(placeStoreMenu)
}

function chooseStore(id: string) {
  context.selectStore(id)
  storeMenuOpen.value = false
}

function onStoreMenuKey(event: KeyboardEvent) {
  const stores = context.activeStores
  if (!stores.length) return
  if (event.key === 'Escape') {
    event.preventDefault()
    storeMenuOpen.value = false
    return
  }
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    storeMenuActive.value = (storeMenuActive.value + 1) % stores.length
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    storeMenuActive.value = (storeMenuActive.value - 1 + stores.length) % stores.length
  } else if (event.key === 'Enter') {
    event.preventDefault()
    const store = stores[storeMenuActive.value]
    if (store) chooseStore(store.id)
  }
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
  if (!(userMenuTrigger.value?.contains(target) || userMenuPanel.value?.contains(target))) {
    userMenuOpen.value = false
  }
  if (!(storeMenuTrigger.value?.contains(target) || storeMenuPanel.value?.contains(target))) {
    storeMenuOpen.value = false
  }
}

function onUserMenuKey(event: KeyboardEvent) {
  if (storeMenuOpen.value) {
    onStoreMenuKey(event)
    return
  }
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
  goToMarketing()
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
  window.addEventListener('resize', placeStoreMenu)
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
  window.removeEventListener('resize', placeStoreMenu)
  window.removeEventListener('resize', syncViewport)
  window.removeEventListener('pos-sidebar-pref', onSidebarPref)
  document.body.classList.remove('nav-drawer-open')
  document.documentElement.classList.remove('sidebar-collapsed')
  offline.stop()
  realtime.disconnect()
})

watch(() => route.path, () => {
  userMenuOpen.value = false
  storeMenuOpen.value = false
  drawerOpen.value = false
})

const workspaceViewKey = computed(
  () => `${route.path}|${auth.user?.tenant_id ?? 'none'}|${context.currentStoreId ?? 'none'}`,
)

watch(() => context.currentStoreId, (storeId, previous) => {
  if (previous && previous !== storeId) {
    pos.reset()
    backoffice.clearStoreScopedState()
  }
  realtime.resubscribe()
  void backoffice.loadStoreTaxonomies(storeId, company.value?.id)
}, { immediate: true })

watch(userMenuOpen, async (open) => {
  if (!open) return
  storeMenuOpen.value = false
  await nextTick()
  placeUserMenu()
})

watch(storeMenuOpen, async (open) => {
  if (!open) return
  await nextTick()
  placeStoreMenu()
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
          <p class="app-sidebar__company font-brand m-0 text-sm font-semibold tracking-tight text-slate-900">{{ brandLines.primary }}</p>
          <p
            v-if="brandLines.secondary"
            class="font-brand m-0 text-xs tracking-wide text-slate-500"
          >{{ brandLines.secondary }}</p>
          <p class="m-0 mt-1 text-meta uppercase tracking-wide text-slate-400">Admin Panel</p>
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
                  <template v-for="child in item.children" :key="child.name">
                    <div class="app-nav-sub__item">
                      <span class="app-nav-link__branch" aria-hidden="true"></span>
                      <RouterLink
                        :to="child.to"
                        class="app-nav-link app-nav-link--child"
                        :class="{ 'app-nav-link--active': isChildActive(child) || isNestedActive(child) }"
                        :aria-current="isChildActive(child) ? 'page' : undefined"
                      >
                        <span class="app-nav-link__mark" aria-hidden="true">
                          <AppIcon :name="child.icon" :size="20" />
                        </span>
                        <span class="min-w-0 flex-1 text-left">{{ child.label }}</span>
                      </RouterLink>
                    </div>
                    <div v-if="child.children?.length" class="app-nav-sub app-nav-sub--nested">
                      <div
                        v-for="grand in child.children"
                        :key="grand.name"
                        class="app-nav-sub__item"
                      >
                        <span class="app-nav-link__branch" aria-hidden="true"></span>
                        <RouterLink
                          :to="grand.to"
                          class="app-nav-link app-nav-link--child"
                          :class="{ 'app-nav-link--active': matchesChild(grand) }"
                          :aria-current="matchesChild(grand) ? 'page' : undefined"
                        >
                          <span class="app-nav-link__mark" aria-hidden="true">
                            <AppIcon :name="grand.icon" :size="20" />
                          </span>
                          <span class="min-w-0 flex-1 text-left">{{ grand.label }}</span>
                        </RouterLink>
                      </div>
                    </div>
                  </template>
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
      <div v-if="auth.supportingName" class="support-banner">
        <span>{{ t('platform.supporting', { name: auth.supportingName }) }}</span>
        <button type="button" @click="leaveSupport">{{ t('platform.returnPlatform') }}</button>
      </div>
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
          <div class="app-topbar__heading" :class="{ 'app-topbar__heading--quiet': quietHeading }">
            <h1 class="app-topbar__title">
              <component :is="HeaderTitle" />
            </h1>
            <p v-if="hasSubtitle" class="app-topbar__subtitle">
              <component :is="HeaderSubtitle" />
            </p>
          </div>
        </div>

        <div class="topbar-tools">
          <StockAlertBell />
          <AppCalculator />
          <button
            type="button"
            class="theme-btn"
            :aria-label="appearance === 'dark' ? t('auth.theme.light') : t('auth.theme.dark')"
            :title="appearance === 'dark' ? t('auth.theme.light') : t('auth.theme.dark')"
            @click="toggleAppearance"
          >
            <AppIcon :name="appearance === 'dark' ? 'sun' : 'moon'" :size="16" />
          </button>
          <LanguageSwitcher />
          <div v-if="context.activeStores.length" class="store-menu">
            <button
              ref="storeMenuTrigger"
              type="button"
              class="store-menu__trigger"
              :class="{ 'store-menu__trigger--open': storeMenuOpen }"
              :aria-expanded="storeMenuOpen"
              aria-haspopup="listbox"
              @click="toggleStoreMenu"
            >
              <span class="store-menu__mark" aria-hidden="true">
                <AppIcon name="store-pin" :size="16" />
              </span>
              <span class="store-menu__name">{{ currentStoreParts.title }}</span>
              <span v-if="currentStoreParts.place" class="store-menu__chip">{{ currentStoreParts.place }}</span>
              <AppIcon name="chevron-down" :size="16" class="store-menu__caret" />
            </button>
          </div>
          <Teleport to="body">
            <Transition name="menu-pop">
              <div
                v-if="storeMenuOpen"
                ref="storeMenuPanel"
                class="store-menu__panel"
                :style="storeMenuStyle"
                role="listbox"
                :aria-label="t('context.currentStore')"
              >
                <p class="store-menu__heading">{{ t('context.currentStore') }}</p>
                <button
                  v-for="(store, index) in context.activeStores"
                  :key="store.id"
                  type="button"
                  class="store-menu__option"
                  :class="{
                    'store-menu__option--current': store.id === context.currentStoreId,
                    'store-menu__option--focus': index === storeMenuActive,
                  }"
                  role="option"
                  :aria-selected="store.id === context.currentStoreId"
                  @mouseenter="storeMenuActive = index"
                  @click="chooseStore(store.id)"
                >
                  <span class="store-menu__option-mark" aria-hidden="true">
                    <AppIcon name="store-pin" :size="15" />
                  </span>
                  <span class="store-menu__option-copy">
                    <span class="store-menu__option-name">{{ storeParts(store).title }}</span>
                    <span v-if="storeParts(store).meta" class="store-menu__option-meta">{{ storeParts(store).meta }}</span>
                  </span>
                  <AppIcon
                    v-if="store.id === context.currentStoreId"
                    name="check"
                    :size="16"
                    class="store-menu__check"
                  />
                </button>
              </div>
            </Transition>
          </Teleport>
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
          <div :key="workspaceViewKey" class="page-stage">
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
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  justify-content: flex-end;
  gap: var(--header-gap);
  overflow: hidden;
}

.theme-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  min-width: var(--control-md);
  flex: 0 0 auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-ink-brand, var(--color-brand-600));
  cursor: pointer;
}

.theme-btn:hover {
  border-color: var(--color-brand-600);
  background: var(--color-brand-50);
}

.user-menu {
  min-width: 0;
  max-width: 11rem;
  flex: 0 1 auto;
  overflow: hidden;
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
  color: var(--color-sidebar-text);
  padding: var(--nav-item-pad-y) var(--nav-item-pad-x);
  font-size: var(--text-sm);
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
  border-color: var(--color-sidebar-mark);
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
  font-family: var(--font-mono);
}

.user-menu__trigger {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  height: var(--control-md);
  width: 100%;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
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
  border-radius: var(--radius-overlay, var(--radius-xl, 12px));
  background-color: var(--color-surface);
  background-image: none;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
  box-shadow: var(--shadow-overlay);
}

:global(html[data-theme="dark"]) .user-menu__panel {
  border-color: var(--color-border);
  background: var(--color-surface);
  box-shadow: var(--shadow-overlay);
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

.store-menu {
  position: relative;
  min-width: 0;
  max-width: 20rem;
  flex: 0 0 auto;
}

.store-menu__trigger {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  height: var(--control-md);
  max-width: 100%;
  min-width: 0;
  padding: 0 0.55rem 0 0.28rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-primary);
  cursor: pointer;
}

.store-menu__trigger:hover {
  border-color: color-mix(in srgb, var(--color-brand-600) 28%, var(--color-border));
  background: color-mix(in srgb, var(--color-brand-50) 55%, var(--color-surface));
}

.store-menu__trigger--open,
.store-menu__trigger:focus-visible {
  outline: none;
  border-color: var(--color-brand-600);
  box-shadow: 0 0 0 2px var(--color-focus-ring);
}

.store-menu__mark,
.store-menu__option-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  border-radius: var(--radius-sm);
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-600));
}

.store-menu__mark {
  width: var(--control-sm);
  height: var(--control-sm);
}

.store-menu__option-mark {
  width: 1.85rem;
  height: 1.85rem;
}

.store-menu__name {
  min-width: 0;
  overflow: hidden;
  font-size: var(--text-sm);
  font-weight: 650;
  line-height: var(--line-sm);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.store-menu__chip {
  flex-shrink: 0;
  max-width: 7.5rem;
  overflow: hidden;
  padding: 0.12rem 0.5rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--color-brand-600) 10%, var(--color-surface));
  color: var(--color-ink-brand, var(--color-brand-700));
  font-size: var(--text-xs);
  font-weight: 650;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.store-menu__caret {
  flex-shrink: 0;
  color: var(--color-text-muted);
  transition: transform var(--motion-fast) var(--ease-in-out);
}

.store-menu__trigger--open .store-menu__caret {
  transform: rotate(180deg);
  color: var(--color-ink-brand, var(--color-brand-600));
}

.store-menu__panel {
  position: fixed;
  z-index: 500;
  max-height: min(22rem, calc(100vh - 5rem));
  overflow: auto;
  padding: var(--overlay-pad);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);
  scrollbar-width: thin;
}

.store-menu__heading {
  margin: 0;
  padding: var(--overlay-item-pad-y) var(--overlay-item-pad-x) 0.35rem;
  font-size: var(--text-xs);
  font-weight: 650;
  letter-spacing: 0.04em;
  line-height: var(--line-xs);
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.store-menu__option {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  width: 100%;
  min-height: 3.15rem;
  margin-top: 0.2rem;
  padding: 0.45rem 0.55rem;
  border: 0;
  border-radius: var(--radius-sm);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.store-menu__option:hover,
.store-menu__option--focus {
  background: var(--color-table-row-hover);
}

.store-menu__option--current {
  background: color-mix(in srgb, var(--color-brand-600) 8%, var(--color-surface));
}

.store-menu__option-copy {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 0.1rem;
}

.store-menu__option-name {
  overflow: hidden;
  font-size: var(--text-md);
  font-weight: 650;
  line-height: 1.3;
  color: var(--color-text-primary);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.store-menu__option-meta {
  font-size: var(--text-xs);
  line-height: 1.35;
  color: var(--color-text-muted);
}

.store-menu__check {
  flex-shrink: 0;
  color: var(--color-ink-brand, var(--color-brand-600));
}

@media (max-width: 767px) {
  .user-menu {
    flex: 0 0 auto;
    max-width: var(--control-md);
  }

  .user-menu__identity,
  .user-menu__caret {
    display: none;
  }

  .store-menu {
    max-width: 9.5rem;
  }

  .store-menu__chip {
    display: none;
  }
}

.support-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.55rem 1rem;
  background: var(--color-brand-600);
  color: #fff;
  font-size: var(--text-sm);
  font-weight: 600;
}

.support-banner button {
  border: 0;
  border-radius: var(--radius-md);
  background: var(--color-accent);
  color: var(--color-brand-900);
  padding: 0.35rem 0.75rem;
  font-weight: 700;
  cursor: pointer;
}
</style>
