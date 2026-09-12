<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
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
const userMenu = ref<HTMLElement | null>(null)

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
          { name: 'pos-shifts', to: '/admin/pos/shifts', label: t('nav.posShifts') },
          { name: 'pos-reservations', to: '/admin/pos/reservations', label: t('nav.posReservations') },
        ],
      },
    ] as NavItem[],
  },
  {
    label: t('nav.section.commerce'),
    items: [
      {
        name: 'catalog',
        to: '/admin/products',
        label: t('nav.catalog'),
        icon: 'catalog',
        children: [
          { name: 'product-catalog', to: '/admin/products', label: t('nav.productCatalog') },
          { name: 'product-options', to: '/admin/catalog/options', label: t('nav.productOptions') },
          { name: 'beverages', to: '/admin/catalog/beverages', label: t('nav.beverages') },
          { name: 'catalog-gallery', to: '/admin/catalog/gallery', label: t('nav.catalogGallery') },
          { name: 'price-lists', to: '/admin/catalog/prices', label: t('nav.priceLists') },
          { name: 'catalog-brands', to: '/admin/catalog/brands', label: t('nav.brands') },
          { name: 'catalog-units', to: '/admin/catalog/units', label: t('nav.units') },
          { name: 'customers', to: '/admin/customers', label: t('nav.customers') },
        ],
      },
      { name: 'stores', to: '/admin/stores', label: t('nav.stores'), icon: 'stores' },
      { name: 'inventory', to: '/admin/inventory/stock', label: t('nav.inventory'), icon: 'inventory' },
      { name: 'suppliers', to: '/admin/suppliers', label: t('nav.suppliers'), icon: 'suppliers' },
      { name: 'purchases', to: '/admin/purchases/overview', label: t('nav.purchases'), icon: 'purchases' },
      { name: 'expenses', to: '/admin/expenses/dashboard', label: t('nav.expenses'), icon: 'purchases' },
      { name: 'payables', to: '/admin/payables', label: t('nav.payables'), icon: 'purchases' },
      { name: 'promotions', to: '/admin/promotions', label: t('nav.promotions'), icon: 'products' },
      { name: 'reports', to: '/admin/reports/sales', label: t('nav.reports'), icon: 'dashboard' },
      { name: 'accounting', to: '/admin/accounting', label: t('nav.accounting'), icon: 'sales' },
      { name: 'import-export', to: '/admin/import-export', label: t('nav.importExport'), icon: 'import' },
    ] as NavItem[],
  },
  {
    label: t('nav.section.system'),
    items: [
      { name: 'organization', to: '/admin/organization/company', label: t('nav.organization'), icon: 'organization' },
      { name: 'audit', to: '/admin/audit', label: t('nav.audit'), icon: 'layers' },
      { name: 'account', to: '/admin/account', label: t('nav.account'), icon: 'account' },
    ] as NavItem[],
  },
])

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

function isChildActive(child: NavChild) {
  if (child.to === '/admin/products') return route.path.startsWith('/admin/products')
  if (child.to === '/admin/customers') return route.path.startsWith('/admin/customers')
  if (child.to === '/admin/pos/orders') {
    return route.path.startsWith('/admin/pos/orders') || route.path.startsWith('/admin/sales')
  }
  if (child.to === '/admin/pos/shifts') {
    return route.path.startsWith('/admin/pos/shifts')
  }
  if (child.to === '/admin/pos/terminal') {
    return route.path === '/admin/pos/terminal' || route.path === '/admin/pos'
  }
  return isActive(child.to)
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

function onUserMenuPointer(event: PointerEvent) {
  if (!userMenu.value?.contains(event.target as Node)) userMenuOpen.value = false
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
  window.addEventListener('pos-sidebar-pref', onSidebarPref)
  void brandingStore.loadCurrent().catch(() => undefined)
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', onUserMenuPointer)
  window.removeEventListener('pos-sidebar-pref', onSidebarPref)
})

watch(() => route.path, () => {
  userMenuOpen.value = false
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
        <div v-for="section in navSections" :key="section.label">
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
          <div ref="userMenu" class="user-menu">
            <button
              type="button"
              class="user-menu__trigger"
              :class="{ 'user-menu__trigger--open': userMenuOpen }"
              :title="auth.user?.name"
              :aria-expanded="userMenuOpen"
              @click="userMenuOpen = !userMenuOpen"
            >
              <span class="user-chip__avatar">{{ userInitials }}</span>
              <span class="user-menu__identity">
                <span class="user-menu__name">{{ auth.user?.name }}</span>
                <span class="user-menu__email">{{ auth.user?.email }}</span>
              </span>
              <AppIcon name="chevron-right" :size="13" class="user-menu__caret" :class="{ 'user-menu__caret--open': userMenuOpen }" />
            </button>
            <div v-if="userMenuOpen" class="user-menu__panel" role="menu">
              <button type="button" class="user-menu__item" @click="goUserMenu('/admin')">
                <AppIcon name="dashboard" :size="15" />
                {{ t('nav.dashboard') }}
              </button>
              <button type="button" class="user-menu__item" @click="goUserMenu('/admin/profile')">
                <AppIcon name="account" :size="15" />
                {{ t('auth.profile') }}
              </button>
              <button type="button" class="user-menu__item" @click="goUserMenu('/admin/settings')">
                <AppIcon name="organization" :size="15" />
                {{ t('auth.settings') }}
              </button>
              <button type="button" class="user-menu__item user-menu__item--danger" @click="logout">
                <AppIcon name="logout" :size="15" />
                {{ t('auth.logout') }}
              </button>
            </div>
          </div>
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
</style>
