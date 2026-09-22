<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useSlots, watch, watchEffect } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterView, useRoute, useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import LanguageSwitcher from '../ui/LanguageSwitcher.vue'
import AppCalculator from './AppCalculator.vue'
import ModuleSearch from './ModuleSearch.vue'
import RealtimeIndicator from './RealtimeIndicator.vue'
import StockAlertBell from './StockAlertBell.vue'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'
import { usePageHeaderStore } from '../../stores/pageHeader'
import { useRealtimeStore } from '../../stores/realtime'

type NavChild = { name: string; to: string; label: string; icon: string; color?: string }
type NavItem = {
  name: string
  to: string
  label: string
  icon: string
  children?: NavChild[]
}

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const slots = useSlots()
const auth = useAuthStore()
const brandingStore = useBrandingStore()
const context = useContextStore()
const backoffice = useBackofficeStore()
const realtime = useRealtimeStore()
const pageHeader = usePageHeaderStore()
const moduleSearch = ref<InstanceType<typeof ModuleSearch> | null>(null)
const userMenuOpen = ref(false)
const userMenuTrigger = ref<HTMLElement | null>(null)
const userMenuPanel = ref<HTMLElement | null>(null)
const userMenuStyle = ref<Record<string, string>>({})

const expandedMenus = ref<Record<string, boolean>>({})
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
      { name: 'dashboard', to: '/admin', label: t('nav.dashboard'), icon: 'dashboard' },
      {
        name: 'pos-ops',
        to: '/admin/pos/overview',
        label: t('nav.group.posOps'),
        icon: 'store-pin',
        children: [
          { name: 'pos-overview', to: '/admin/pos/overview', label: t('nav.posOverview'), icon: 'dashboard' },
          { name: 'pos-terminal', to: '/admin/pos/terminal', label: t('nav.posTerminal'), icon: 'device-pos' },
          { name: 'pos-tables', to: '/admin/hospitality', label: t('nav.restaurant'), icon: 'tables' },
          { name: 'pos-shifts', to: '/admin/pos/shifts', label: t('nav.posShifts'), icon: 'shift' },
          { name: 'pos-reservations', to: '/admin/pos/reservations', label: t('nav.posReservations'), icon: 'calendar' },
        ],
      },
      {
        name: 'pos-sales',
        to: '/admin/pos/orders',
        label: t('nav.group.posSales'),
        icon: 'sales',
        children: [
          { name: 'pos-orders', to: '/admin/pos/orders', label: t('nav.posOrders'), icon: 'sales' },
          { name: 'pos-returns', to: '/admin/sales/returns', label: t('sales.tabs.returns'), icon: 'transfer' },
        ],
      },
      {
        name: 'hotel',
        to: '/admin/hotel/rooms',
        label: t('nav.hotel'),
        icon: 'building',
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
      { name: 'stores', to: '/admin/stores', label: t('nav.stores'), icon: 'stores' },
      { name: 'customers', to: '/admin/customers', label: t('nav.customers'), icon: 'customers' },
    ] as NavItem[],
  },
  {
    label: t('nav.section.catalog'),
    items: [
      {
        name: 'catalog-products',
        to: '/admin/products',
        label: t('nav.group.products'),
        icon: 'catalog',
        children: [
          { name: 'product-catalog', to: '/admin/products', label: t('nav.productCatalog'), icon: 'products' },
          { name: 'product-accompaniments', to: '/admin/accompaniments', label: t('nav.accompaniments'), icon: 'sparkles' },
          { name: 'product-options', to: '/admin/catalog/options', label: t('nav.productOptions'), icon: 'layers' },
          { name: 'beverages', to: '/admin/catalog/beverages', label: t('nav.beverages'), icon: 'sparkles' },
          { name: 'catalog-gallery', to: '/admin/catalog/gallery', label: t('nav.catalogGallery'), icon: 'catalog' },
        ],
      },
      {
        name: 'catalog-reference',
        to: '/admin/catalog/catalogs',
        label: t('nav.group.reference'),
        icon: 'layers',
        children: [
          { name: 'catalogs', to: '/admin/catalog/catalogs', label: t('catalog.tabs.catalogs'), icon: 'catalog' },
          { name: 'catalog-categories', to: '/admin/catalog/categories', label: t('catalog.tabs.categories'), icon: 'layers' },
          { name: 'catalog-brands', to: '/admin/catalog/brands', label: t('nav.brands'), icon: 'tag' },
          { name: 'catalog-units', to: '/admin/catalog/units', label: t('nav.units'), icon: 'package' },
          { name: 'catalog-attributes', to: '/admin/catalog/attributes', label: t('nav.attributes'), icon: 'adjust' },
        ],
      },
      {
        name: 'catalog-pricing',
        to: '/admin/catalog/prices',
        label: t('nav.group.pricing'),
        icon: 'tag',
        children: [
          { name: 'price-lists', to: '/admin/catalog/prices', label: t('nav.priceLists'), icon: 'tag' },
          { name: 'catalog-taxes', to: '/admin/catalog/taxes', label: t('catalog.tabs.taxes'), icon: 'percent' },
        ],
      },
      { name: 'barcodes', to: '/admin/barcodes', label: t('nav.barcodes'), icon: 'tag' },
      { name: 'promotions', to: '/admin/promotions', label: t('nav.promotions'), icon: 'products' },
      { name: 'services', to: '/admin/services', label: t('nav.services'), icon: 'customers' },
    ] as NavItem[],
  },
  {
    label: t('nav.section.stock'),
    items: [
      {
        name: 'inventory-status',
        to: '/admin/inventory/stock',
        label: t('nav.group.stockStatus'),
        icon: 'inventory',
        children: [
          { name: 'inventory-stock', to: '/admin/inventory/stock', label: t('inventory.tabs.stock'), icon: 'inventory' },
          { name: 'inventory-alerts', to: '/admin/inventory/alerts', label: t('inventory.tabs.alerts'), icon: 'alert' },
        ],
      },
      {
        name: 'inventory-movements',
        to: '/admin/inventory/supplies',
        label: t('nav.group.movements'),
        icon: 'import',
        children: [
          { name: 'inventory-supplies', to: '/admin/inventory/supplies', label: t('inventory.tabs.supplies'), icon: 'import' },
          { name: 'inventory-transfers', to: '/admin/inventory/transfers', label: t('inventory.tabs.transfers'), icon: 'transfer' },
          { name: 'inventory-adjustments', to: '/admin/inventory/adjustments', label: t('inventory.tabs.adjustments'), icon: 'adjust' },
          { name: 'inventory-issues', to: '/admin/inventory/issues', label: t('inventory.tabs.issues'), icon: 'upload' },
        ],
      },
      {
        name: 'inventory-controls',
        to: '/admin/inventory/counts',
        label: t('nav.group.controls'),
        icon: 'layers',
        children: [
          { name: 'inventory-counts', to: '/admin/inventory/counts', label: t('inventory.tabs.inventories'), icon: 'check' },
          { name: 'inventory-verifications', to: '/admin/inventory/verifications', label: t('inventory.tabs.verifications'), icon: 'lock' },
        ],
      },
      {
        name: 'inventory-traceability',
        to: '/admin/inventory/batches',
        label: t('nav.group.traceability'),
        icon: 'tag',
        children: [
          { name: 'inventory-batches', to: '/admin/inventory/batches', label: t('inventory.tabs.batches'), icon: 'package' },
          { name: 'inventory-serials', to: '/admin/inventory/serials', label: t('inventory.tabs.serials'), icon: 'tag' },
        ],
      },
      { name: 'production', to: '/admin/production', label: t('nav.production'), icon: 'inventory' },
    ] as NavItem[],
  },
  {
    label: t('nav.section.purchasing'),
    items: [
      { name: 'suppliers', to: '/admin/suppliers', label: t('nav.suppliers'), icon: 'suppliers' },
      {
        name: 'purchases-cycle',
        to: '/admin/purchases/overview',
        label: t('nav.group.purchaseCycle'),
        icon: 'purchases',
        children: [
          { name: 'purchase-overview', to: '/admin/purchases/overview', label: t('purchases.hub.overview'), icon: 'dashboard' },
          { name: 'purchase-requisitions', to: '/admin/purchases/requisitions', label: t('purchases.hub.requisitions'), icon: 'note' },
          { name: 'purchase-proformas', to: '/admin/purchases/proformas', label: t('purchases.hub.proformas'), icon: 'receipt' },
          { name: 'purchase-orders', to: '/admin/purchases/orders', label: t('purchases.hub.orders'), icon: 'purchases' },
        ],
      },
      {
        name: 'purchases-billing',
        to: '/admin/purchases/invoices',
        label: t('nav.group.purchaseBilling'),
        icon: 'sales',
        children: [
          { name: 'purchase-invoices', to: '/admin/purchases/invoices', label: t('purchases.hub.invoices'), icon: 'receipt' },
          { name: 'purchase-payments', to: '/admin/purchases/payments', label: t('purchases.hub.payments'), icon: 'coins' },
          { name: 'purchase-returns', to: '/admin/purchases/returns', label: t('purchases.hub.returns'), icon: 'transfer' },
        ],
      },
      { name: 'payables', to: '/admin/payables', label: t('nav.payables'), icon: 'purchases' },
    ] as NavItem[],
  },
  {
    label: t('nav.section.finance'),
    items: [
      {
        name: 'expenses',
        to: '/admin/expenses/dashboard',
        label: t('nav.expenses'),
        icon: 'purchases',
        children: [
          { name: 'expenses-dashboard', to: '/admin/expenses/dashboard', label: t('expenses.tabs.dashboard'), icon: 'dashboard' },
          { name: 'expenses-list', to: '/admin/expenses', label: t('expenses.tabs.list'), icon: 'note' },
          { name: 'expenses-categories', to: '/admin/expenses/categories', label: t('expenses.tabs.categories'), icon: 'layers' },
          { name: 'expenses-recurring', to: '/admin/expenses/recurring', label: t('expenses.tabs.recurring'), icon: 'calendar' },
          { name: 'expenses-reports', to: '/admin/expenses/reports', label: t('expenses.tabs.reports'), icon: 'sales' },
        ],
      },
      { name: 'accounting', to: '/admin/accounting', label: t('nav.accounting'), icon: 'sales' },
      {
        name: 'reports',
        to: '/admin/reports/dashboard',
        label: t('nav.reports'),
        icon: 'dashboard',
        children: [
          { name: 'reports-dashboard', to: '/admin/reports/dashboard', label: t('reports.tabs.dashboard'), icon: 'dashboard' },
          { name: 'reports-sales', to: '/admin/reports/sales', label: t('reports.tabs.sales'), icon: 'sales' },
          { name: 'reports-inventory', to: '/admin/reports/inventory', label: t('reports.tabs.inventory'), icon: 'inventory' },
          { name: 'reports-store-stock', to: '/admin/reports/store-stock', label: t('reports.tabs.storeStock'), icon: 'stores' },
          { name: 'reports-purchases', to: '/admin/reports/purchases', label: t('reports.tabs.purchases'), icon: 'purchases' },
          { name: 'reports-forecasts', to: '/admin/reports/forecasts', label: t('reports.tabs.forecasts'), icon: 'sparkles' },
          { name: 'reports-financial', to: '/admin/reports/financial', label: t('reports.tabs.revenue'), icon: 'coins' },
          { name: 'reports-condensed', to: '/admin/reports/condensed', label: t('reports.tabs.condensed'), icon: 'layers' },
          { name: 'reports-daily', to: '/admin/reports/daily', label: t('reports.tabs.daily'), icon: 'calendar' },
          { name: 'reports-user-performance', to: '/admin/reports/user-performance', label: t('reports.tabs.userPerformance'), icon: 'account' },
        ],
      },
    ] as NavItem[],
  },
  {
    label: t('nav.section.system'),
    items: [
      {
        name: 'org-company',
        to: '/admin/organization/company',
        label: t('nav.group.company'),
        icon: 'organization',
        children: [
          { name: 'org-company-page', to: '/admin/organization/company', label: t('org.tabs.company'), icon: 'organization' },
          { name: 'org-branding', to: '/admin/organization/branding', label: t('org.tabs.branding'), icon: 'sparkles' },
          { name: 'org-currencies', to: '/admin/organization/currencies', label: t('org.tabs.currencies'), icon: 'coins' },
          { name: 'org-payments', to: '/admin/organization/payment-methods', label: t('org.tabs.paymentMethods'), icon: 'card' },
        ],
      },
      {
        name: 'org-sites',
        to: '/admin/organization/branches',
        label: t('nav.group.sites'),
        icon: 'stores',
        children: [
          { name: 'org-branches', to: '/admin/organization/branches', label: t('org.tabs.branches'), icon: 'building' },
          { name: 'org-stores', to: '/admin/organization/stores', label: t('org.tabs.stores'), icon: 'stores' },
          { name: 'org-warehouses', to: '/admin/organization/warehouses', label: t('org.tabs.warehouses'), icon: 'inventory' },
        ],
      },
      {
        name: 'org-pos',
        to: '/admin/organization/terminals',
        label: t('nav.group.posHardware'),
        icon: 'store-pin',
        children: [
          { name: 'org-terminals', to: '/admin/organization/terminals', label: t('org.tabs.terminals'), icon: 'device-pos' },
          { name: 'org-devices', to: '/admin/organization/devices', label: t('org.tabs.devices'), icon: 'device-tablet' },
          { name: 'org-registers', to: '/admin/organization/registers', label: t('org.tabs.registers'), icon: 'coins' },
        ],
      },
      {
        name: 'org-access',
        to: '/admin/organization/users',
        label: t('nav.group.access'),
        icon: 'account',
        children: [
          { name: 'org-users', to: '/admin/organization/users', label: t('org.tabs.users'), icon: 'customers' },
          { name: 'org-roles', to: '/admin/organization/roles', label: t('org.tabs.roles'), icon: 'lock' },
          { name: 'org-permissions', to: '/admin/organization/permissions', label: t('org.tabs.permissions'), icon: 'key' },
        ],
      },
      { name: 'import-export', to: '/admin/import-export', label: t('nav.importExport'), icon: 'import' },
      { name: 'sync', to: '/admin/sync', label: t('nav.sync'), icon: 'import' },
      { name: 'audit', to: '/admin/audit', label: t('nav.audit'), icon: 'layers' },
      { name: 'platform', to: '/admin/platform', label: t('nav.platform'), icon: 'organization' },
      { name: 'account', to: '/admin/account', label: t('nav.account'), icon: 'account' },
    ] as NavItem[],
  },
])

function hasModule(code: string) {
  const modules = auth.user?.modules
  if (!modules?.length) return true
  return modules.includes(code)
}

const visibleNav = computed(() => navSections.value.map(section => ({
  ...section,
  items: section.items.filter(item => {
    if (item.name === 'platform') return auth.user?.is_super_admin === true
    if (item.name === 'pos-ops' || item.name === 'pos-sales') return hasModule('pos')
    if (item.name.startsWith('inventory-') || item.name === 'production') return hasModule('stock')
    if (item.name === 'hotel') return hasModule('hotel')
    if (item.name === 'restaurant') return hasModule('restaurant')
    return true
  }),
})).filter(section => section.items.length > 0))

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
  const fromBranding = brandingStore.branding?.brand_name?.trim()
  if (fromBranding) return fromBranding
  const name = company.value?.name?.trim() || company.value?.trade_name?.trim() || 'ITARA NEXUS Business CORE'
  return name
})

const brandLines = computed(() => {
  const parts = companyName.value.split(/\s+/).filter(Boolean)
  if (parts.length <= 1) return { primary: companyName.value, secondary: '' }
  return { primary: parts[0], secondary: parts.slice(1).join(' ') }
})

const accentColor = computed(() => brandingStore.branding?.accent_color || 'var(--color-brand-500)')

const logoFailed = ref(false)
const companyLogo = computed(() =>
  brandingStore.branding?.logo_url?.trim()
  || company.value?.logo_url?.trim()
  || '',
)

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
  return Boolean(expandedMenus.value[item.name])
}

function toggleMenu(item: NavItem) {
  if (!item.children?.length) return
  if (!isDesktop.value && !drawerOpen.value) {
    drawerOpen.value = true
    expandedMenus.value[item.name] = true
    return
  }
  if (isDesktop.value && !sidebarOpen.value) {
    sidebarOpen.value = true
    expandedMenus.value[item.name] = true
    return
  }
  expandedMenus.value[item.name] = !isExpanded(item)
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
    for (const section of navSections.value) {
      for (const item of section.items) {
        if (item.children?.length && isGroupActive(item)) {
          expandedMenus.value[item.name] = true
        }
      }
    }
  },
  { immediate: true },
)

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
  syncViewport()
  window.addEventListener('pointerdown', onUserMenuPointer)
  window.addEventListener('keydown', onUserMenuKey)
  window.addEventListener('resize', placeUserMenu)
  window.addEventListener('resize', syncViewport)
  window.addEventListener('pos-sidebar-pref', onSidebarPref)
  void brandingStore.loadCurrent().catch(() => undefined)
  realtime.connect()
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', onUserMenuPointer)
  window.removeEventListener('keydown', onUserMenuKey)
  window.removeEventListener('resize', placeUserMenu)
  window.removeEventListener('resize', syncViewport)
  window.removeEventListener('pos-sidebar-pref', onSidebarPref)
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
</script>

<template>
  <div class="app-shell">
    <div
      v-if="drawerOpen"
      class="app-sidebar-backdrop"
      @click="closeDrawer"
    />
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
          <img v-else src="/brand-mark.svg" :alt="companyName" />
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

      <nav class="app-sidebar__nav">
        <div v-for="section in visibleNav" :key="section.label">
          <p class="app-sidebar__section-label">{{ section.label }}</p>
          <template v-for="item in section.items" :key="item.name">
            <template v-if="item.children?.length">
              <button
                type="button"
                class="app-nav-link app-nav-link--parent"
                :class="{ 'app-nav-link--active': isGroupActive(item), 'app-nav-link--open': isExpanded(item) }"
                :title="item.label"
                :aria-expanded="isExpanded(item)"
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
              <div v-show="isExpanded(item)" class="app-nav-sub">
                <RouterLink
                  v-for="child in item.children"
                  :key="child.name"
                  :to="child.to"
                  class="app-nav-link app-nav-link--child"
                  :class="{ 'app-nav-link--active': isChildActive(child) }"
                >
                  <span class="app-nav-link__mark" aria-hidden="true">
                    <AppIcon :name="child.icon" :size="16" />
                  </span>
                  <span class="min-w-0 flex-1 text-left">{{ child.label }}</span>
                </RouterLink>
              </div>
            </template>
            <RouterLink
              v-else
              :to="item.to"
              class="app-nav-link"
              :class="{ 'app-nav-link--active': isActive(item.to) }"
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
          </Teleport>
        </div>
      </header>

      <main class="app-content">
        <Transition name="page" mode="out-in">
          <div :key="route.path" class="page-stage">
            <RouterView />
          </div>
        </Transition>
      </main>
    </div>
  </div>
</template>

<style scoped>
.text-brand-500 { color: var(--color-brand-500); }

.topbar-start {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: var(--space-3);
}

.topbar-tools {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.module-search-btn {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  height: var(--control-lg);
  width: calc(100% - var(--space-6));
  margin: var(--space-3) var(--space-3) var(--space-2);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-canvas);
  color: var(--color-text-muted);
  padding: 0 var(--space-3);
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
  background: var(--color-brand-50);
  border-color: var(--color-brand-200);
  color: var(--color-brand-700);
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
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: white;
  padding: 2px var(--space-2);
  font-size: var(--text-xs);
  color: var(--color-text-faint);
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
  background: #fff;
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
  color: #0f172a;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-menu__email {
  display: none;
}

.user-menu__caret {
  flex-shrink: 0;
  color: #64748b;
  transform: rotate(90deg);
  transition: transform 0.16s ease;
}

.user-menu__caret--open {
  transform: rotate(-90deg);
}

.user-menu__panel {
  position: fixed;
  z-index: 500;
  width: 15.5rem;
  overflow: hidden;
  padding: var(--space-1);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: #fff;
  box-shadow: var(--shadow-md);
}

.user-menu__heading {
  margin: 0;
  padding: var(--space-2) var(--space-3);
  font-size: var(--text-xs);
  font-weight: 600;
  line-height: var(--line-xs);
  color: #64748b;
}

.user-menu__item {
  display: flex;
  width: 100%;
  align-items: center;
  gap: var(--space-3);
  height: var(--control-md);
  min-height: var(--control-md);
  border: 0;
  border-radius: var(--radius-sm);
  background: transparent;
  padding: 0 var(--space-3);
  text-align: left;
  font-size: var(--text-md);
  font-weight: 500;
  line-height: var(--line-sm);
  color: #0f172a;
  cursor: pointer;
}

.user-menu__item:hover {
  background: #f4f8fb;
}

.user-menu__item--danger {
  color: #b91c1c;
}

@media (max-width: 767px) {
  .user-menu__identity {
    display: none;
  }
}
</style>
