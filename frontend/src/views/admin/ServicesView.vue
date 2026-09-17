<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api } from '../../api/client'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppModal from '../../components/ui/AppModal.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import { formatDate, formatMoney } from '../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../utils/listFilters'

type Offering = { id: string; name: string; category: string; price: number; duration_minutes: number }
type Appointment = {
  id: string
  customer_name: string
  status: string
  scheduled_at: string
  completion_notes?: string | null
  paid_amount?: number | null
  offering?: Offering | null
  employee?: { id: string; name: string } | null
}

const { t } = useI18n()
const store = useBackofficeStore()
const offerings = ref<Offering[]>([])
const rows = ref<Appointment[]>([])
const showModal = ref(false)
const notes = ref<Record<string, string>>({})
const employees = ref<Record<string, string>>({})
const form = ref({ service_offering_id: '', customer_name: '', scheduled_at: '' })
const filters = ref<ListFilters>(emptyListFilters('all'))
const statusOptions = computed(() =>
  ['booked', 'assigned', 'completed', 'paid'].map(value => ({
    value,
    label: statusLabel(value),
  })),
)
const filtered = computed(() => rows.value.filter(row =>
  matchesSearch(
    `${row.customer_name} ${row.offering?.name ?? ''} ${row.offering?.category ?? ''} ${row.employee?.name ?? ''}`,
    filters.value.search,
  )
  && (!filters.value.status || row.status === filters.value.status)
  && inPeriod(row.scheduled_at, filters.value),
))

onMounted(load)

async function load() {
  await store.loadUsers()
  offerings.value = (await api.get<{ data: Offering[] }>('/service-offerings')).data
  rows.value = (await api.get<{ data: Appointment[] }>('/service-appointments')).data
}

function openCreate() {
  form.value = {
    service_offering_id: offerings.value[0]?.id ?? '',
    customer_name: '',
    scheduled_at: new Date().toISOString().slice(0, 16),
  }
  showModal.value = true
}

async function book() {
  await api.post('/service-appointments', form.value)
  showModal.value = false
  await load()
}

async function assign(row: Appointment) {
  const employeeId = employees.value[row.id]
  if (!employeeId) return
  await api.post(`/service-appointments/${row.id}/assign`, { employee_id: employeeId })
  await load()
}

async function complete(row: Appointment) {
  await api.post(`/service-appointments/${row.id}/complete`, { notes: notes.value[row.id] ?? '' })
  await load()
}

async function pay(row: Appointment) {
  await api.post(`/service-appointments/${row.id}/pay`, { method: 'cash' })
  await load()
}

function statusLabel(status: string) {
  const key = `services.status.${status}`
  const label = t(key)
  return label === key ? status : label
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('services.title') }}</template>
    <template #subtitle>{{ t('services.subtitle') }}</template>
    <template #actions>
      <button class="btn-primary" @click="openCreate">+ {{ t('services.book') }}</button>
    </template>

    <ModuleFilters
      v-model="filters"
      class="mb-4"
      :statuses="statusOptions"
      show-search
      show-period
      show-status
    />

    <div class="overflow-hidden rounded-xl border border-slate-200 bg-white">
      <table class="min-w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
          <tr>
            <th class="px-4 py-3 text-left">{{ t('services.service') }}</th>
            <th class="px-4 py-3 text-left">{{ t('services.customer') }}</th>
            <th class="px-4 py-3 text-left">{{ t('services.when') }}</th>
            <th class="px-4 py-3 text-left">{{ t('services.step') }}</th>
            <th class="px-4 py-3 text-left"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in filtered" :key="row.id" class="border-t border-slate-100">
            <td class="px-4 py-3">
              <div class="font-medium">{{ row.offering?.name }}</div>
              <div class="text-xs text-slate-500">{{ row.offering?.category }} · {{ formatMoney(row.offering?.price ?? 0) }}</div>
            </td>
            <td class="px-4 py-3">{{ row.customer_name }}</td>
            <td class="px-4 py-3">{{ formatDate(row.scheduled_at) }}</td>
            <td class="px-4 py-3">{{ statusLabel(row.status) }}</td>
            <td class="px-4 py-3">
              <div v-if="row.status === 'booked'" class="flex gap-2">
                <select v-model="employees[row.id]" class="field">
                  <option value="">{{ t('services.employee') }}</option>
                  <option v-for="user in store.users" :key="user.id" :value="user.id">{{ user.name }}</option>
                </select>
                <button class="btn-secondary" @click="assign(row)">{{ t('services.assign') }}</button>
              </div>
              <div v-else-if="row.status === 'assigned'" class="flex gap-2">
                <input v-model="notes[row.id]" class="field" :placeholder="t('services.notes')" />
                <button class="btn-secondary" @click="complete(row)">{{ t('services.complete') }}</button>
              </div>
              <button v-else-if="row.status === 'completed'" class="btn-primary" @click="pay(row)">{{ t('services.pay') }}</button>
              <span v-else class="text-xs text-slate-500">{{ row.employee?.name }}</span>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('services.empty') }}</p>
    </div>

    <AppModal :open="showModal" :title="t('services.book')" @close="showModal = false">
      <form class="space-y-3" @submit.prevent="book">
        <div>
          <FieldLabel icon="layers">{{ t('services.service') }}</FieldLabel>
          <select v-model="form.service_offering_id" class="field" required>
            <option v-for="item in offerings" :key="item.id" :value="item.id">{{ item.name }} · {{ item.category }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="customers">{{ t('services.customer') }}</FieldLabel>
          <input v-model="form.customer_name" class="field" required />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('services.when') }}</FieldLabel>
          <input v-model="form.scheduled_at" type="datetime-local" class="field" required />
        </div>
        <button class="btn-primary" type="submit">{{ t('services.book') }}</button>
      </form>
    </AppModal>
  </PageFrame>
</template>
