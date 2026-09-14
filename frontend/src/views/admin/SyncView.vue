<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../api/client'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import { formatDateTime } from '../../utils/format'

type Device = { id: string; name: string; code?: string; platform?: string | null; device_type?: string | null; status?: string | null; last_sync_at?: string | null; is_active?: boolean }
type EventRow = { id: string; event_type: string; entity_type: string; occurred_at?: string | null }
type Status = { server_sequence: number; sales: number; server_time: string; devices: Device[]; events: EventRow[] }

const { t } = useI18n()
const status = ref<Status | null>(null)
const error = ref('')

onMounted(load)

async function load() {
  error.value = ''
  try {
    status.value = (await api.get<{ data: Status }>('/sync/status')).data
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('desk.sync') }}</template>
    <template #subtitle>{{ t('desk.syncHint') }}</template>

    <div class="space-y-4">
      <div class="flex justify-end"><button class="btn-secondary" @click="load">{{ t('common.refresh') }}</button></div>
      <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>
      <div v-if="status" class="grid gap-3 sm:grid-cols-3">
        <div class="rounded-2xl border border-slate-200 bg-white p-4"><span class="text-xs text-slate-500">{{ t('desk.sequence') }}</span><strong class="mt-1 block text-2xl">{{ status.server_sequence || 0 }}</strong></div>
        <div class="rounded-2xl border border-slate-200 bg-white p-4"><span class="text-xs text-slate-500">{{ t('desk.salesOnServer') }}</span><strong class="mt-1 block text-2xl">{{ status.sales }}</strong></div>
        <div class="rounded-2xl border border-slate-200 bg-white p-4"><span class="text-xs text-slate-500">{{ t('desk.serverTime') }}</span><strong class="mt-1 block">{{ formatDateTime(status.server_time) }}</strong></div>
      </div>
      <section class="rounded-2xl border border-slate-200 bg-white">
        <h3 class="m-0 px-4 pt-4">{{ t('desk.terminals') }}</h3>
        <table class="min-w-full text-sm">
          <thead><tr><th class="px-4 py-3 text-left">{{ t('org.name') }}</th><th class="px-4 py-3 text-left">{{ t('desk.platform') }}</th><th class="px-4 py-3 text-left">{{ t('desk.lastSync') }}</th></tr></thead>
          <tbody>
            <tr v-for="device in status?.devices ?? []" :key="device.id">
              <td class="px-4 py-3">{{ device.name }} <span class="text-slate-400">{{ device.code }}</span></td>
              <td class="px-4 py-3">{{ device.platform || device.device_type || '—' }}</td>
              <td class="px-4 py-3">{{ device.last_sync_at ? formatDateTime(device.last_sync_at) : t('desk.never') }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="status && !status.devices.length" class="px-4 py-6 text-sm text-slate-500">{{ t('desk.noDevices') }}</p>
      </section>
      <section class="rounded-2xl border border-slate-200 bg-white">
        <h3 class="m-0 px-4 pt-4">{{ t('desk.events') }}</h3>
        <table class="min-w-full text-sm">
          <tbody>
            <tr v-for="event in status?.events ?? []" :key="event.id">
              <td class="px-4 py-3 font-medium">{{ event.event_type }}</td>
              <td class="px-4 py-3 text-slate-500">{{ event.entity_type }}</td>
              <td class="px-4 py-3">{{ formatDateTime(event.occurred_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="status && !status.events.length" class="px-4 py-6 text-sm text-slate-500">{{ t('desk.noEvents') }}</p>
      </section>
    </div>
  </AdminLayout>
</template>
