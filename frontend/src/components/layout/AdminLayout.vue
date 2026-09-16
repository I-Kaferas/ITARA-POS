<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import LanguageSwitcher from '../ui/LanguageSwitcher.vue'
import AppCalculator from './AppCalculator.vue'
import ModuleSearch from './ModuleSearch.vue'
import RealtimeIndicator from './RealtimeIndicator.vue'
import StockAlertBell from './StockAlertBell.vue'
import { useAuthStore } from '../../stores/auth'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'
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
const auth = useAuthStore()
const brandingStore = useBrandingStore()
const context = useContextStore()
const realtime = useRealtimeStore()
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
          { name: 'pos-overview', to: '/admin/pos/overview', label: t('nav.posOverview'), icon: 'dashboard', color: '#64748b' },
          { name: 'pos-terminal', to: '/admin/pos/terminal', label: t('nav.posTerminal'), icon: 'device-pos', color: '#0f766e' },
          { name: 'pos-tables', to: '/admin/hospitality', label: t('nav.restaurant'), icon: 'tables', color: '#0f766e' },
          { name: 'pos-shifts', to: '/admin/pos/shifts', label: t('nav.posShifts'), icon: 'shift', color: '#2563eb' },
          { name: 'pos-reservations', to: '/admin/pos/reservations', label: t('nav.posReservations'), icon: 'calendar', color: '#d97706' },
        ],
      },
      {
        name: 'pos-sales',
        to: '/admin/pos/orders',
        label: t('nav.group.posSales'),
        icon: 'sales',
        children: [
          { name: 'pos-orders', to: '/admin/pos/orders', label: t('nav.posOrders'), icon: 'sales', color: '#059669' },
          { name: 'pos-returns', to: '/admin/sales/returns', label: t('sales.tabs.returns'), icon: 'transfer', color: '#dc2626' },
        ],
      },
      {
        name: 'hotel',
        to: '/admin/hotel/rooms',
        label: t('nav.hotel'),
        icon: 'building',
        children: [
          { name: 'hotel-room-config', to: '/admin/hotel/room-config', label: t('hotel.tabs.roomConfig'), icon: 'layers', color: '#5c7f96' },
          { name: 'hotel-rooms', to: '/admin/hotel/rooms', label: t('hotel.tabs.rooms'), icon: 'bed', color: '#0f766e' },
          { name: 'hotel-reservations', to: '/admin/hotel/reservations', label: t('hotel.tabs.reservations'), icon: 'calendar', color: '#2563eb' },
          { name: 'hotel-stays', to: '/admin/hotel/stays', label: t('hotel.tabs.stays'), icon: 'key', color: '#b45309' },
          { name: 'hotel-invoices', to: '/admin/hotel/invoices', label: t('hotel.tabs.invoices'), icon: 'receipt', color: '#059669' },
          { name: 'hotel-guests', to: '/admin/hotel/guests', label: t('hotel.tabs.guests'), icon: 'customers', color: '#be185d' },
          { name: 'hotel-housekeeping', to: '/admin/hotel/housekeeping', label: t('hotel.tabs.housekeeping'), icon: 'broom', color: '#0891b2' },
          { name: 'hotel-calendar', to: '/admin/hotel/calendar', label: t('hotel.tabs.calendar'), icon: 'calendar', color: '#d97706' },
          { name: 'hotel-concierge', to: '/admin/hotel/concierge', label: t('hotel.tabs.concierge'), icon: 'bell', color: '#0e7490' },
          { name: 'hotel-reports', to: '/admin/hotel/reports', label: t('hotel.tabs.reports'), icon: 'dashboard', color: '#475569' },
          { name: 'hotel-settings', to: '/admin/hotel/settings', label: t('hotel.tabs.settings'), icon: 'account', color: '#64748b' },
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
          { name: 'product-catalog', to: '/admin/products', label: t('nav.productCatalog'), icon: 'products', color: '#0f766e' },
          { name: 'product-accompaniments', to: '/admin/accompaniments', label: t('nav.accompaniments'), icon: 'sparkles', color: '#d97706' },
          { name: 'product-options', to: '/admin/catalog/options', label: t('nav.productOptions'), icon: 'layers', color: '#5c7f96' },
          { name: 'beverages', to: '/admin/catalog/beverages', label: t('nav.beverages'), icon: 'sparkles', color: '#b45309' },
          { name: 'catalog-gallery', to: '/admin/catalog/gallery', label: t('nav.catalogGallery'), icon: 'catalog', color: '#7c3aed' },
        ],
      },
      {
        name: 'catalog-reference',
        to: '/admin/catalog/catalogs',
        label: t('nav.group.reference'),
        icon: 'layers',
        children: [
          { name: 'catalogs', to: '/admin/catalog/catalogs', label: t('catalog.tabs.catalogs'), icon: 'catalog', color: '#2563eb' },
          { name: 'catalog-categories', to: '/admin/catalog/categories', label: t('catalog.tabs.categories'), icon: 'layers', color: '#0e7490' },
          { name: 'catalog-brands', to: '/admin/catalog/brands', label: t('nav.brands'), icon: 'tag', color: '#be185d' },
          { name: 'catalog-units', to: '/admin/catalog/units', label: t('nav.units'), icon: 'package', color: '#64748b' },
          { name: 'catalog-attributes', to: '/admin/catalog/attributes', label: t('nav.attributes'), icon: 'adjust', color: '#d97706' },
        ],
      },
      {
        name: 'catalog-pricing',
        to: '/admin/catalog/prices',
        label: t('nav.group.pricing'),
        icon: 'tag',
        children: [
          { name: 'price-lists', to: '/admin/catalog/prices', label: t('nav.priceLists'), icon: 'tag', color: '#059669' },
          { name: 'catalog-taxes', to: '/admin/catalog/taxes', label: t('catalog.tabs.taxes'), icon: 'percent', color: '#b45309' },
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
          { name: 'inventory-stock', to: '/admin/inventory/stock', label: t('inventory.tabs.stock'), icon: 'inventory', color: '#0f766e' },
          { name: 'inventory-alerts', to: '/admin/inventory/alerts', label: t('inventory.tabs.alerts'), icon: 'alert', color: '#dc2626' },
        ],
      },
      {
        name: 'inventory-movements',
        to: '/admin/inventory/supplies',
        label: t('nav.group.movements'),
        icon: 'import',
        children: [
          { name: 'inventory-supplies', to: '/admin/inventory/supplies', label: t('inventory.tabs.supplies'), icon: 'import', color: '#059669' },
          { name: 'inventory-transfers', to: '/admin/inventory/transfers', label: t('inventory.tabs.transfers'), icon: 'transfer', color: '#2563eb' },
          { name: 'inventory-adjustments', to: '/admin/inventory/adjustments', label: t('inventory.tabs.adjustments'), icon: 'adjust', color: '#d97706' },
          { name: 'inventory-issues', to: '/admin/inventory/issues', label: t('inventory.tabs.issues'), icon: 'upload', color: '#b45309' },
        ],
      },
      {
        name: 'inventory-controls',
        to: '/admin/inventory/counts',
        label: t('nav.group.controls'),
        icon: 'layers',
        children: [
          { name: 'inventory-counts', to: '/admin/inventory/counts', label: t('inventory.tabs.inventories'), icon: 'check', color: '#0e7490' },
          { name: 'inventory-verifications', to: '/admin/inventory/verifications', label: t('inventory.tabs.verifications'), icon: 'lock', color: '#64748b' },
        ],
      },
      {
        name: 'inventory-traceability',
        to: '/admin/inventory/batches',
        label: t('nav.group.traceability'),
        icon: 'tag',
        children: [
          { name: 'inventory-batches', to: '/admin/inventory/batches', label: t('inventory.tabs.batches'), icon: 'package', color: '#7c3aed' },
          { name: 'inventory-serials', to: '/admin/inventory/serials', label: t('inventory.tabs.serials'), icon: 'tag', color: '#be185d' },
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
          { name: 'purchase-overview', to: '/admin/purchases/overview', label: t('purchases.hub.overview'), icon: 'dashboard', color: '#64748b' },
          { name: 'purchase-requisitions', to: '/admin/purchases/requisitions', label: t('purchases.hub.requisitions'), icon: 'note', color: '#2563eb' },
          { name: 'purchase-proformas', to: '/admin/purchases/proformas', label: t('purchases.hub.proformas'), icon: 'receipt', color: '#d97706' },
          { name: 'purchase-orders', to: '/admin/purchases/orders', label: t('purchases.hub.orders'), icon: 'purchases', color: '#0f766e' },
        ],
      },
      {
        name: 'purchases-billing',
        to: '/admin/purchases/invoices',
        label: t('nav.group.purchaseBilling'),
        icon: 'sales',
        children: [
          { name: 'purchase-invoices', to: '/admin/purchases/invoices', label: t('purchases.hub.invoices'), icon: 'receipt', color: '#059669' },
          { name: 'purchase-payments', to: '/admin/purchases/payments', label: t('purchases.hub.payments'), icon: 'coins', color: '#b45309' },
          { name: 'purchase-returns', to: '/admin/purchases/returns', label: t('purchases.hub.returns'), icon: 'transfer', color: '#dc2626' },
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
          { name: 'expenses-dashboard', to: '/admin/expenses/dashboard', label: t('expenses.tabs.dashboard'), icon: 'dashboard', color: '#64748b' },
          { name: 'expenses-list', to: '/admin/expenses', label: t('expenses.tabs.list'), icon: 'note', color: '#2563eb' },
          { name: 'expenses-categories', to: '/admin/expenses/categories', label: t('expenses.tabs.categories'), icon: 'layers', color: '#0e7490' },
          { name: 'expenses-recurring', to: '/admin/expenses/recurring', label: t('expenses.tabs.recurring'), icon: 'calendar', color: '#d97706' },
          { name: 'expenses-reports', to: '/admin/expenses/reports', label: t('expenses.tabs.reports'), icon: 'sales', color: '#059669' },
        ],
      },
      { name: 'accounting', to: '/admin/accounting', label: t('nav.accounting'), icon: 'sales' },
      {
        name: 'reports',
        to: '/admin/reports/sales',
        label: t('nav.reports'),
        icon: 'dashboard',
        children: [
          { name: 'reports-sales', to: '/admin/reports/sales', label: t('reports.tabs.sales'), icon: 'sales', color: '#059669' },
          { name: 'reports-inventory', to: '/admin/reports/inventory', label: t('reports.tabs.inventory'), icon: 'inventory', color: '#0f766e' },
          { name: 'reports-financial', to: '/admin/reports/financial', label: t('reports.tabs.financial'), icon: 'coins', color: '#b45309' },
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
          { name: 'org-company-page', to: '/admin/organization/company', label: t('org.tabs.company'), icon: 'organization', color: '#5c7f96' },
          { name: 'org-branding', to: '/admin/organization/branding', label: t('org.tabs.branding'), icon: 'sparkles', color: '#7c3aed' },
          { name: 'org-currencies', to: '/admin/organization/currencies', label: t('org.tabs.currencies'), icon: 'coins', color: '#d97706' },
          { name: 'org-payments', to: '/admin/organization/payment-methods', label: t('org.tabs.paymentMethods'), icon: 'card', color: '#059669' },
        ],
      },
      {
        name: 'org-sites',
        to: '/admin/organization/branches',
        label: t('nav.group.sites'),
        icon: 'stores',
        children: [
          { name: 'org-branches', to: '/admin/organization/branches', label: t('org.tabs.branches'), icon: 'building', color: '#2563eb' },
          { name: 'org-stores', to: '/admin/organization/stores', label: t('org.tabs.stores'), icon: 'stores', color: '#0f766e' },
          { name: 'org-warehouses', to: '/admin/organization/warehouses', label: t('org.tabs.warehouses'), icon: 'inventory', color: '#b45309' },
        ],
      },
      {
        name: 'org-pos',
        to: '/admin/organization/terminals',
        label: t('nav.group.posHardware'),
        icon: 'store-pin',
        children: [
          { name: 'org-terminals', to: '/admin/organization/terminals', label: t('org.tabs.terminals'), icon: 'device-pos', color: '#0e7490' },
          { name: 'org-devices', to: '/admin/organization/devices', label: t('org.tabs.devices'), icon: 'device-tablet', color: '#7c3aed' },
          { name: 'org-registers', to: '/admin/organization/registers', label: t('org.tabs.registers'), icon: 'coins', color: '#d97706' },
        ],
      },
      {
        name: 'org-access',
        to: '/admin/organization/users',
        label: t('nav.group.access'),
        icon: 'account',
        children: [
          { name: 'org-users', to: '/admin/organization/users', label: t('org.tabs.users'), icon: 'customers', color: '#2563eb' },
          { name: 'org-roles', to: '/admin/organization/roles', label: t('org.tabs.roles'), icon: 'lock', color: '#b45309' },
          { name: 'org-permissions', to: '/admin/organization/permissions', label: t('org.tabs.permissions'), icon: 'key', color: '#dc2626' },
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
  const name = company.value?.name?.trim() || company.value?.trade_name?.trim() || 'ITARA NEXUS'
  return name
})

const brandLines = computed(() => {
  const parts = companyName.value.split(/\s+/).filter(Boolean)
  if (parts.length <= 1) return { primary: companyName.value, secondary: '' }
  return { primary: parts[0], secondary: parts.slice(1).join(' ') }
})

const accentColor = computed(() => brandingStore.branding?.accent_color || '#e39b2b')

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

watch(() => context.currentStoreId, () => {
  realtime.resubscribe()
})

watch(userMenuOpen, async (open) => {
  if (!open) return
  await nextTick()
  placeUserMenu()
})
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
          <p class="font-brand m-0 text-sm font-bold tracking-[0.08em] text-white">{{ brandLines.primary }}</p>
          <p
            v-if="brandLines.secondary"
            class="font-brand m-0 text-[0.6875rem] tracking-[0.16em]"
            :style="{ color: accentColor }"
          >{{ brandLines.secondary }}</p>
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
                  :class="{
                    'app-nav-link--active': isChildActive(child),
                    'app-nav-link--toned': Boolean(child.color),
                  }"
                  :style="child.color ? { '--nav-color': child.color } : undefined"
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
              <slot name="title" />
            </h1>
            <p v-if="$slots.subtitle" class="app-topbar__subtitle">
              <slot name="subtitle" />
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
            <slot />
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
  border: 1px solid rgba(227, 155, 43, 0.35);
  border-radius: var(--radius-md);
  background: rgba(0, 0, 0, 0.16);
  color: #ffffff;
  padding: 0 var(--space-3);
  font-size: var(--text-md);
  font-weight: 500;
  line-height: var(--line-sm);
  cursor: pointer;
}

.module-search-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  border-color: rgba(227, 155, 43, 0.55);
  color: #fff;
}

.module-search-btn svg {
  flex-shrink: 0;
  color: #ffffff;
}

.module-search-btn span {
  flex: 1;
  text-align: left;
}

.module-search-btn kbd {
  border: 1px solid rgba(227, 155, 43, 0.35);
  border-radius: var(--radius-sm);
  background: rgba(227, 155, 43, 0.12);
  padding: 2px var(--space-2);
  font-size: var(--text-xs);
  line-height: var(--line-xs);
  color: #e39b2b;
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
  border-color: #4a6d86;
  box-shadow: 0 0 0 3px rgba(74, 109, 134, 0.12);
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
