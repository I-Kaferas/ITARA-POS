<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import LanguageSwitcher from '../ui/LanguageSwitcher.vue'
import AppCalculator from './AppCalculator.vue'
import ModuleSearch from './ModuleSearch.vue'
import StockAlertBell from './StockAlertBell.vue'
import { useAuthStore } from '../../stores/auth'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'

type NavChild = { name: string; to: string; label: string }
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
const moduleSearch = ref<InstanceType<typeof ModuleSearch> | null>(null)
const userMenuOpen = ref(false)
const userMenuTrigger = ref<HTMLElement | null>(null)
const userMenuPanel = ref<HTMLElement | null>(null)
const userMenuStyle = ref<Record<string, string>>({})

const expandedMenus = ref<Record<string, boolean>>({})
const sidebarOpen = ref(localStorage.getItem('pos_sidebar_open') !== '0')

watch(sidebarOpen, (open) => {
  localStorage.setItem('pos_sidebar_open', open ? '1' : '0')
})

const navSections = computed(() => [
  {
    label: t('nav.section.main'),
    items: [
      { name: 'dashboard', to: '/admin', label: t('nav.dashboard'), icon: 'dashboard' },
      {
        name: 'pos',
        to: '/admin/pos/overview',
        label: t('nav.pos'),
        icon: 'store-pin',
        children: [
          { name: 'pos-overview', to: '/admin/pos/overview', label: t('nav.posOverview') },
          { name: 'pos-terminal', to: '/admin/pos/terminal', label: t('nav.posTerminal') },
          { name: 'pos-orders', to: '/admin/pos/orders', label: t('nav.posOrders') },
          { name: 'pos-returns', to: '/admin/sales/returns', label: t('sales.tabs.returns') },
          { name: 'pos-shifts', to: '/admin/pos/shifts', label: t('nav.posShifts') },
          { name: 'pos-reservations', to: '/admin/pos/reservations', label: t('nav.posReservations') },
        ],
      },
      { name: 'hospitality', to: '/admin/hospitality', label: t('nav.hospitality'), icon: 'store-pin' },
      { name: 'stores', to: '/admin/stores', label: t('nav.stores'), icon: 'stores' },
      { name: 'customers', to: '/admin/customers', label: t('nav.customers'), icon: 'customers' },
    ] as NavItem[],
  },
  {
    label: t('nav.section.catalog'),
    items: [
      {
        name: 'catalog',
        to: '/admin/products',
        label: t('nav.catalog'),
        icon: 'catalog',
        children: [
          { name: 'product-catalog', to: '/admin/products', label: t('nav.productCatalog') },
          { name: 'catalogs', to: '/admin/catalog/catalogs', label: t('catalog.tabs.catalogs') },
          { name: 'catalog-categories', to: '/admin/catalog/categories', label: t('catalog.tabs.categories') },
          { name: 'catalog-brands', to: '/admin/catalog/brands', label: t('nav.brands') },
          { name: 'catalog-units', to: '/admin/catalog/units', label: t('nav.units') },
          { name: 'catalog-attributes', to: '/admin/catalog/attributes', label: t('nav.attributes') },
          { name: 'product-options', to: '/admin/catalog/options', label: t('nav.productOptions') },
          { name: 'beverages', to: '/admin/catalog/beverages', label: t('nav.beverages') },
          { name: 'price-lists', to: '/admin/catalog/prices', label: t('nav.priceLists') },
          { name: 'catalog-taxes', to: '/admin/catalog/taxes', label: t('catalog.tabs.taxes') },
          { name: 'catalog-gallery', to: '/admin/catalog/gallery', label: t('nav.catalogGallery') },
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
        name: 'inventory',
        to: '/admin/inventory/stock',
        label: t('nav.inventory'),
        icon: 'inventory',
        children: [
          { name: 'inventory-stock', to: '/admin/inventory/stock', label: t('inventory.tabs.stock') },
          { name: 'inventory-supplies', to: '/admin/inventory/supplies', label: t('inventory.tabs.supplies') },
          { name: 'inventory-transfers', to: '/admin/inventory/transfers', label: t('inventory.tabs.transfers') },
          { name: 'inventory-adjustments', to: '/admin/inventory/adjustments', label: t('inventory.tabs.adjustments') },
          { name: 'inventory-issues', to: '/admin/inventory/issues', label: t('inventory.tabs.issues') },
          { name: 'inventory-counts', to: '/admin/inventory/counts', label: t('inventory.tabs.inventories') },
          { name: 'inventory-verifications', to: '/admin/inventory/verifications', label: t('inventory.tabs.verifications') },
          { name: 'inventory-batches', to: '/admin/inventory/batches', label: t('inventory.tabs.batches') },
          { name: 'inventory-serials', to: '/admin/inventory/serials', label: t('inventory.tabs.serials') },
          { name: 'inventory-alerts', to: '/admin/inventory/alerts', label: t('inventory.tabs.alerts') },
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
        name: 'purchases',
        to: '/admin/purchases/overview',
        label: t('nav.purchases'),
        icon: 'purchases',
        children: [
          { name: 'purchase-overview', to: '/admin/purchases/overview', label: t('purchases.hub.overview') },
          { name: 'purchase-requisitions', to: '/admin/purchases/requisitions', label: t('purchases.hub.requisitions') },
          { name: 'purchase-proformas', to: '/admin/purchases/proformas', label: t('purchases.hub.proformas') },
          { name: 'purchase-orders', to: '/admin/purchases/orders', label: t('purchases.hub.orders') },
          { name: 'purchase-invoices', to: '/admin/purchases/invoices', label: t('purchases.hub.invoices') },
          { name: 'purchase-payments', to: '/admin/purchases/payments', label: t('purchases.hub.payments') },
          { name: 'purchase-returns', to: '/admin/purchases/returns', label: t('purchases.hub.returns') },
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
          { name: 'expenses-dashboard', to: '/admin/expenses/dashboard', label: t('expenses.tabs.dashboard') },
          { name: 'expenses-list', to: '/admin/expenses', label: t('expenses.tabs.list') },
          { name: 'expenses-categories', to: '/admin/expenses/categories', label: t('expenses.tabs.categories') },
          { name: 'expenses-recurring', to: '/admin/expenses/recurring', label: t('expenses.tabs.recurring') },
          { name: 'expenses-reports', to: '/admin/expenses/reports', label: t('expenses.tabs.reports') },
        ],
      },
      { name: 'accounting', to: '/admin/accounting', label: t('nav.accounting'), icon: 'sales' },
      {
        name: 'reports',
        to: '/admin/reports/sales',
        label: t('nav.reports'),
        icon: 'dashboard',
        children: [
          { name: 'reports-sales', to: '/admin/reports/sales', label: t('reports.tabs.sales') },
          { name: 'reports-inventory', to: '/admin/reports/inventory', label: t('reports.tabs.inventory') },
          { name: 'reports-financial', to: '/admin/reports/financial', label: t('reports.tabs.financial') },
        ],
      },
    ] as NavItem[],
  },
  {
    label: t('nav.section.system'),
    items: [
      {
        name: 'organization',
        to: '/admin/organization/company',
        label: t('nav.organization'),
        icon: 'organization',
        children: [
          { name: 'org-company', to: '/admin/organization/company', label: t('org.tabs.company') },
          { name: 'org-branding', to: '/admin/organization/branding', label: t('org.tabs.branding') },
          { name: 'org-currencies', to: '/admin/organization/currencies', label: t('org.tabs.currencies') },
          { name: 'org-payments', to: '/admin/organization/payment-methods', label: t('org.tabs.paymentMethods') },
          { name: 'org-branches', to: '/admin/organization/branches', label: t('org.tabs.branches') },
          { name: 'org-stores', to: '/admin/organization/stores', label: t('org.tabs.stores') },
          { name: 'org-warehouses', to: '/admin/organization/warehouses', label: t('org.tabs.warehouses') },
          { name: 'org-terminals', to: '/admin/organization/terminals', label: t('org.tabs.terminals') },
          { name: 'org-devices', to: '/admin/organization/devices', label: t('org.tabs.devices') },
          { name: 'org-registers', to: '/admin/organization/registers', label: t('org.tabs.registers') },
          { name: 'org-users', to: '/admin/organization/users', label: t('org.tabs.users') },
          { name: 'org-roles', to: '/admin/organization/roles', label: t('org.tabs.roles') },
          { name: 'org-permissions', to: '/admin/organization/permissions', label: t('org.tabs.permissions') },
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
    if (item.name === 'pos') return hasModule('pos')
    if (item.name === 'inventory' || item.name === 'production') return hasModule('stock')
    if (item.name === 'hospitality') return hasModule('restaurant') || hasModule('hotel')
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
  if (!sidebarOpen.value) {
    sidebarOpen.value = true
    expandedMenus.value[item.name] = true
    return
  }
  expandedMenus.value[item.name] = !isExpanded(item)
}

function toggleSidebar() {
  sidebarOpen.value = !sidebarOpen.value
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
  await auth.logout()
  brandingStore.clear()
  context.reset()
  router.push({ name: 'login' })
}

function onSidebarPref(event: Event) {
  sidebarOpen.value = Boolean((event as CustomEvent<boolean>).detail)
}

onMounted(() => {
  window.addEventListener('pointerdown', onUserMenuPointer)
  window.addEventListener('keydown', onUserMenuKey)
  window.addEventListener('resize', placeUserMenu)
  window.addEventListener('pos-sidebar-pref', onSidebarPref)
  void brandingStore.loadCurrent().catch(() => undefined)
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', onUserMenuPointer)
  window.removeEventListener('keydown', onUserMenuKey)
  window.removeEventListener('resize', placeUserMenu)
  window.removeEventListener('pos-sidebar-pref', onSidebarPref)
})

watch(() => route.path, () => {
  userMenuOpen.value = false
})

watch(userMenuOpen, async (open) => {
  if (!open) return
  await nextTick()
  placeUserMenu()
})
</script>

<template>
  <div class="app-shell">
    <aside class="app-sidebar" :class="{ 'app-sidebar--collapsed': !sidebarOpen }">
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
          <AppIcon name="chevron-right" :size="14" class="sidebar-toggle__icon" :class="{ 'sidebar-toggle__icon--open': sidebarOpen }" />
        </button>
      </div>
      <button type="button" class="module-search-btn" @click="moduleSearch?.show()">
        <AppIcon name="search" :size="15" />
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
                <AppIcon :name="item.icon" :size="17" />
                <span class="min-w-0 flex-1 text-left">{{ item.label }}</span>
                <AppIcon
                  name="chevron-right"
                  :size="14"
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
                  {{ child.label }}
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
              <AppIcon :name="item.icon" :size="17" />
              <span class="min-w-0 flex-1 text-left">{{ item.label }}</span>
            </RouterLink>
          </template>
        </div>
      </nav>
    </aside>
    <ModuleSearch ref="moduleSearch" />

    <div class="app-main">
      <header class="app-topbar">
        <div>
          <h1 class="app-topbar__title">
            <slot name="title" />
          </h1>
          <p v-if="$slots.subtitle" class="m-0 mt-0.5 text-xs text-slate-500">
            <slot name="subtitle" />
          </p>
        </div>

        <div class="topbar-tools">
          <StockAlertBell />
          <AppCalculator />
          <LanguageSwitcher />
          <div v-if="context.activeStores.length" class="store-pill">
            <AppIcon name="store-pin" :size="15" class="text-brand-500 shrink-0" />
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
              <AppIcon name="chevron-right" :size="13" class="user-menu__caret" :class="{ 'user-menu__caret--open': userMenuOpen }" />
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
                <AppIcon name="dashboard" :size="15" />
                {{ t('nav.dashboard') }}
              </button>
              <button type="button" class="user-menu__item" role="menuitem" @click="goUserMenu('/admin/profile')">
                <AppIcon name="account" :size="15" />
                {{ t('auth.profile') }}
              </button>
              <button type="button" class="user-menu__item" role="menuitem" @click="goUserMenu('/admin/settings')">
                <AppIcon name="organization" :size="15" />
                {{ t('auth.settings') }}
              </button>
              <button type="button" class="user-menu__item user-menu__item--danger" role="menuitem" @click="logout">
                <AppIcon name="logout" :size="15" />
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

.topbar-tools {
  display: flex;
  align-items: center;
  gap: 0.625rem;
}

.module-search-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: calc(100% - 1.4rem);
  margin: 0.55rem 0.7rem 0.35rem;
  border: 1px solid rgba(227, 155, 43, 0.28);
  border-radius: 0.8rem;
  background: #1a2630;
  color: rgba(255, 255, 255, 0.78);
  padding: 0.55rem 0.75rem;
  font-size: 0.75rem;
  cursor: pointer;
  transition: background 0.18s ease, border-color 0.18s ease, color 0.18s ease;
}

.module-search-btn:hover {
  background: #243340;
  border-color: rgba(227, 155, 43, 0.55);
  color: #fff;
}

.module-search-btn span {
  flex: 1;
  text-align: left;
}

.module-search-btn kbd {
  border: 1px solid rgba(227, 155, 43, 0.35);
  border-radius: 0.4rem;
  background: rgba(227, 155, 43, 0.12);
  padding: 0.1rem 0.35rem;
  font-size: 0.62rem;
  color: #e39b2b;
}

.user-menu__trigger {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  max-width: 16rem;
  border: 1px solid #d7dbe6;
  border-radius: 999px;
  background: #fff;
  padding: 0.28rem 0.65rem 0.28rem 0.28rem;
  cursor: pointer;
}

.user-menu__trigger--open {
  border-color: #4a6d86;
  box-shadow: 0 0 0 3px rgba(74, 109, 134, 0.12);
}

.user-menu__identity {
  display: flex;
  min-width: 0;
  flex-direction: column;
  text-align: left;
}

.user-menu__name {
  overflow: hidden;
  font-size: 0.8125rem;
  font-weight: 700;
  line-height: 1.2;
  color: #0f172a;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-menu__email {
  overflow: hidden;
  font-size: 0.6875rem;
  line-height: 1.2;
  color: #64748b;
  text-overflow: ellipsis;
  white-space: nowrap;
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
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: #fff;
  box-shadow: 0 16px 40px rgba(15, 23, 42, 0.16);
}

.user-menu__heading {
  margin: 0;
  padding: 0.7rem 0.85rem 0.45rem;
  border-bottom: 1px solid #f1f5f9;
  font-size: 0.75rem;
  font-weight: 700;
  color: #64748b;
}

.user-menu__item {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 0.55rem;
  border: 0;
  background: #fff;
  padding: 0.7rem 0.85rem;
  text-align: left;
  font-size: 0.875rem;
  font-weight: 600;
  color: #0f172a;
  cursor: pointer;
}

.user-menu__item:hover {
  background: #f4f8fb;
}

.user-menu__item--danger {
  border-top: 1px solid #f1f5f9;
  color: #b91c1c;
}
</style>
