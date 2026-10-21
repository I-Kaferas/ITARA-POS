<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../components/layout/PageFrame.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import FilterFold from '../../components/ui/FilterFold.vue'
import ListPager from '../../components/ui/ListPager.vue'
import { useClientPager } from '../../composables/useClientPager'
import { useBackofficeStore } from '../../stores/backoffice'
import { formatDate, formatMoney } from '../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()
const action = ref('')
const from = ref('')
const to = ref('')

const auditRows = computed(() => store.auditLogs)
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(auditRows)

async function load() {
  const params: Record<string, string> = {}
  if (action.value) params.action = action.value
  if (from.value) params.from = from.value
  if (to.value) params.to = to.value
  await store.loadAuditLogs(params)
}

function moneyField(value: unknown) {
  return typeof value === 'number' ? formatMoney(value) : '—'
}

onMounted(load)
watchLiveSearch(action, load)
watchLiveSearch([from, to], load, 0)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.audit') }}</template>
    <template #subtitle>{{ t('audit.subtitle') }}</template>

    <FilterFold class="mb-4">
    <div class="flex flex-wrap items-end gap-3">
      <div>
        <FieldLabel icon="filter">Action</FieldLabel>
        <input v-model="action" type="search" class="field" placeholder="sale.completed" />
      </div>
      <div>
        <FieldLabel icon="calendar">{{ t('reports.from') }}</FieldLabel>
        <input v-model="from" type="date" class="field" />
      </div>
      <div>
        <FieldLabel icon="calendar">{{ t('reports.to') }}</FieldLabel>
        <input v-model="to" type="date" class="field" />
      </div>
    </div>
    </FilterFold>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('audit.user') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('audit.action') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('audit.product') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('audit.old') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('audit.new') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('audit.device') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('audit.time') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="row in paged" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3">{{ row.user?.name ?? row.payload?.user ?? '—' }}</td>
            <td class="px-4 py-3 font-mono text-xs">{{ row.action }}</td>
            <td class="px-4 py-3">{{ row.payload?.product ?? row.entity_type }}</td>
            <td class="px-4 py-3 text-right">{{ moneyField(row.payload?.old) }}</td>
            <td class="px-4 py-3 text-right">{{ moneyField(row.payload?.new) }}</td>
            <td class="px-4 py-3">{{ row.payload?.device ?? '—' }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
          </tr>
        </tbody>
      </table>
      <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
      <p v-if="!store.auditLogs.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>
  </PageFrame>
</template>

<style scoped>

.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
</style>
