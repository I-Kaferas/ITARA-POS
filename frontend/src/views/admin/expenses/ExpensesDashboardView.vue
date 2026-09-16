<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatMoney } from '../../../utils/format'
import { emptyListFilters, listFilterParams, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const filters = ref<ListFilters>(emptyListFilters('month'))
const total = ref(0)
const byCategory = ref<Array<{ name: string; total: number; count: number }>>([])
const categories = ref<Array<{ id: string; name: string }>>([])

const categoryOptions = computed(() => categories.value.map(item => ({ id: item.id, name: item.name })))

onMounted(async () => {
  categories.value = (await store.loadExpenseCategories()) as Array<{ id: string; name: string }>
  await load()
})

async function load() {
  const data = await store.loadExpenseDashboard(
    listFilterParams(filters.value, { categoryKey: 'expense_category_id' }),
  ) as { total?: number; by_category?: typeof byCategory.value }
  total.value = data.total ?? 0
  byCategory.value = data.by_category ?? []
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('expenses.tabs.dashboard') }}</template>
    <template #subtitle>{{ t('expenses.linksHint') }}</template>
    <div class="mb-4 space-y-3">
      <div class="flex items-center justify-between">
        <p class="m-0 text-sm text-slate-500">{{ t('expenses.kpi.total') }} · {{ formatMoney(total) }}</p>
        <button class="btn-primary" type="button" @click="router.push({ name: 'expenses' })">{{ t('expenses.new') }}</button>
      </div>
      <ModuleFilters
        v-model="filters"
        :categories="categoryOptions"
        :show-search="false"
        show-period
        show-category
        @apply="load"
      />
    </div>
    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <article v-for="row in byCategory" :key="row.name" class="rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200">
        <p class="m-0 text-sm text-slate-500">{{ row.name }}</p>
        <p class="m-0 mt-1 text-lg font-semibold">{{ formatMoney(row.total) }}</p>
      </article>
    </div>
    <p v-if="!byCategory.length" class="text-sm text-slate-500">{{ t('org.empty') }}</p>
  </AdminLayout>
</template>

<style scoped>
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
</style>
