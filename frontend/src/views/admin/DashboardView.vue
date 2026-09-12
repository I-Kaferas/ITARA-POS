<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import StatCard from '../../components/ui/StatCard.vue'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'

const { t } = useI18n()
const store = useBackofficeStore()
const auth = useAuthStore()

onMounted(() => store.loadStats())

const firstName = computed(() => auth.user?.name?.split(' ')[0] ?? '')

const statCards = computed(() => [
  { key: 'companies', label: t('nav.organization'), icon: 'building', accent: '#4a6d86', iconBg: '#e4edf2' },
  { key: 'catalogs', label: t('nav.catalogs'), icon: 'layers', accent: '#5c7f96', iconBg: '#f3f6f8' },
  { key: 'products', label: t('nav.products'), icon: 'products', accent: '#3d5c73', iconBg: '#e4edf2' },
  { key: 'stores', label: t('nav.stores'), icon: 'stores', accent: '#e39b2b', iconBg: '#f8efdc' },
  { key: 'store_imports', label: t('dashboard.imports'), icon: 'import', accent: '#7d9aaf', iconBg: '#f3f6f8' },
] as const)

const quickActions = computed(() => [
  { to: '/admin/products', icon: 'plus', title: t('dashboard.actions.newProduct'), desc: t('dashboard.actions.newProductDesc') },
  { to: '/admin/catalog/catalogs', icon: 'catalog', title: t('dashboard.actions.manageCatalog'), desc: t('dashboard.actions.manageCatalogDesc') },
  { to: '/admin/inventory/stock', icon: 'inventory', title: t('nav.inventory'), desc: t('inventory.subtitle') },
  { to: '/admin/pos/overview', icon: 'store-pin', title: t('nav.pos'), desc: t('pointOfSale.overview.subtitle') },
  { to: '/admin/pos/orders', icon: 'sales', title: t('nav.posOrders'), desc: t('pointOfSale.orders.subtitle') },
  { to: '/admin/purchases/orders', icon: 'purchases', title: t('nav.purchases'), desc: t('purchases.subtitle') },
  { to: '/admin/suppliers', icon: 'suppliers', title: t('nav.suppliers'), desc: t('suppliers.subtitle') },
  { to: '/admin/customers', icon: 'customers', title: t('nav.customers'), desc: t('customers.subtitle') },
  { to: '/admin/stores', icon: 'import', title: t('dashboard.actions.importStore'), desc: t('dashboard.actions.importStoreDesc') },
  { to: '/admin/organization/company', icon: 'organization', title: t('dashboard.actions.organization'), desc: t('dashboard.actions.organizationDesc') },
])

const checklist = computed(() => [
  { done: (store.stats?.companies ?? 0) > 0, label: t('dashboard.checklist.company') },
  { done: (store.stats?.catalogs ?? 0) > 0, label: t('dashboard.checklist.catalog') },
  { done: (store.stats?.products ?? 0) > 0, label: t('dashboard.checklist.products') },
  { done: (store.stats?.store_imports ?? 0) > 0, label: t('dashboard.checklist.import') },
])

const completedSteps = computed(() => checklist.value.filter(c => c.done).length)
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.dashboard') }}</template>
    <template #subtitle>{{ t('dashboard.subtitle') }}</template>

    <div class="hero-banner">
      <div class="hero-banner__content">
        <p class="font-brand mb-1 text-xs font-semibold uppercase tracking-widest text-white/50">
          {{ t('dashboard.greeting') }}
        </p>
        <h2 class="hero-banner__title">
          {{ t('dashboard.hello', { name: firstName }) }}
        </h2>
        <p class="hero-banner__subtitle">{{ t('dashboard.description') }}</p>
      </div>
    </div>

    <div class="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
      <StatCard
        v-for="card in statCards"
        :key="card.key"
        :label="card.label"
        :value="store.stats?.[card.key] ?? '—'"
        :icon="card.icon"
        :accent="card.accent"
        :icon-bg="card.iconBg"
      />
    </div>

    <div class="grid gap-6 lg:grid-cols-5">
      <div class="lg:col-span-3">
        <div class="ui-card">
          <div class="ui-card__header">
            <h3 class="ui-card__title">{{ t('dashboard.quickActions') }}</h3>
            <AppIcon name="sparkles" :size="18" class="text-brand-400" />
          </div>
          <div class="ui-card__body grid gap-3 sm:grid-cols-2">
            <RouterLink
              v-for="action in quickActions"
              :key="action.to"
              :to="action.to"
              class="action-tile"
            >
              <div class="action-tile__icon">
                <AppIcon :name="action.icon" :size="18" />
              </div>
              <div>
                <p class="action-tile__title">{{ action.title }}</p>
                <p class="action-tile__desc">{{ action.desc }}</p>
              </div>
              <AppIcon name="chevron-right" :size="16" class="ml-auto shrink-0 text-slate-300" />
            </RouterLink>
          </div>
        </div>
      </div>

      <div class="lg:col-span-2">
        <div class="ui-card h-full">
          <div class="ui-card__header">
            <div>
              <h3 class="ui-card__title">{{ t('dashboard.gettingStarted') }}</h3>
              <p class="m-0 mt-0.5 text-xs text-slate-500">
                {{ completedSteps }}/{{ checklist.length }} {{ t('dashboard.stepsDone') }}
              </p>
            </div>
            <div class="flex h-9 w-9 items-center justify-center rounded-full bg-brand-50 text-sm font-bold text-brand-600">
              {{ Math.round((completedSteps / checklist.length) * 100) }}%
            </div>
          </div>
          <div class="ui-card__body !pt-0">
            <div
              class="mb-4 h-1.5 overflow-hidden rounded-full bg-slate-100"
            >
              <div
                class="h-full rounded-full bg-brand-600 transition-all duration-500"
                :style="{ width: `${(completedSteps / checklist.length) * 100}%` }"
              />
            </div>
            <div v-for="(item, i) in checklist" :key="i" class="checklist-item">
              <div
                class="checklist-item__dot flex items-center justify-center"
                :class="{ 'checklist-item__dot--done': item.done }"
              >
                <AppIcon v-if="item.done" name="check" :size="10" class="text-success" />
              </div>
              <p class="m-0 text-sm" :class="item.done ? 'text-slate-500 line-through' : 'text-slate-700 font-medium'">
                {{ item.label }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-6 flex items-center justify-between rounded-xl border border-slate-200/80 bg-white/60 px-4 py-3 text-xs text-slate-500">
      <span class="font-brand">{{ t('app.tagline') }}</span>
      <span class="flex items-center gap-1.5">
        <span class="inline-block h-1.5 w-1.5 rounded-full bg-emerald-500" />
        {{ t('dashboard.systemOnline') }}
      </span>
    </div>
  </AdminLayout>
</template>

<style scoped>
.text-brand-400 { color: var(--color-brand-400); }
.text-brand-600 { color: var(--color-brand-600); }
.bg-brand-50 { background: var(--color-brand-50); }
.from-brand-500 { --tw-gradient-from: var(--color-brand-500); }
.text-success { color: var(--color-success); }
</style>
