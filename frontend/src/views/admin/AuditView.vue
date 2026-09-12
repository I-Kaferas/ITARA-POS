<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import { formatDate } from '../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()
const action = ref('')
const from = ref('')
const to = ref('')

async function load() {
  const params: Record<string, string> = {}
  if (action.value) params.action = action.value
  if (from.value) params.from = from.value
  if (to.value) params.to = to.value
  await store.loadAuditLogs(params)
}

onMounted(load)
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.audit') }}</template>
    <template #subtitle>{{ t('audit.subtitle') }}</template>

    <div class="mb-4 flex flex-wrap items-end gap-3">
      <div>
        <label class="mb-1 block text-xs font-medium text-slate-500">Action</label>
        <input v-model="action" class="field" placeholder="sale.completed" />
      </div>
      <div>
        <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('reports.from') }}</label>
        <input v-model="from" type="date" class="field" />
      </div>
      <div>
        <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('reports.to') }}</label>
        <input v-model="to" type="date" class="field" />
      </div>
      <button class="btn-secondary" @click="load">{{ t('common.search') }}</button>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-left font-medium">Action</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('audit.entity') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('org.tabs.users') }}</th>
            <th class="px-4 py-3 text-left font-medium">IP</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="row in store.auditLogs" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 font-mono text-xs">{{ row.action }}</td>
            <td class="px-4 py-3">
              <span class="font-mono text-xs text-slate-500">{{ row.entity_type }}</span>
              <div class="font-mono text-[11px] text-slate-400">{{ row.entity_id }}</div>
            </td>
            <td class="px-4 py-3">{{ row.user?.name ?? '—' }}</td>
            <td class="px-4 py-3 text-slate-500">{{ row.ip_address ?? '—' }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!store.auditLogs.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>
  </AdminLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
</style>
