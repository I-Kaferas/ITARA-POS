<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { formatMoney } from '../../../utils/format'

type Company = {
  id: string
  name: string
  slug?: string
  status?: string
  modules: string[]
  license: { key?: string | null; status: string; seats: number; expires_on?: string | null }
  subscription: { plan?: string | null; status: string; renews_on?: string | null }
  users: number
  devices: number
  open_support: number
}
type DeviceRow = { id: string; company?: string | null; name?: string; code?: string; platform?: string | null; status?: string | null; last_sync_at?: string | null }
type UserRow = { id: string; company?: string | null; name: string; email: string; is_active?: boolean }
type Ticket = { id: string; company: string; tenant_id: string; subject: string; message: string; status: string; created_at?: string }
type Overview = { companies: number; users: number; devices: number; sales: number; revenue: number }

const { t } = useI18n()
const tab = ref<'companies' | 'licenses' | 'subscriptions' | 'devices' | 'modules' | 'users' | 'stats' | 'support'>('companies')
const companies = ref<Company[]>([])
const devices = ref<DeviceRow[]>([])
const users = ref<UserRow[]>([])
const tickets = ref<Ticket[]>([])
const overview = ref<Overview | null>(null)
const error = ref('')
const name = ref('')
const subject = ref('')
const message = ref('')
const ticketCompany = ref('')

const plans = [
  { id: 'pos_stock', modules: ['pos', 'stock'] },
  { id: 'pos_stock_restaurant', modules: ['pos', 'stock', 'restaurant'] },
  { id: 'pos_stock_hotel_restaurant', modules: ['pos', 'stock', 'hotel', 'restaurant'] },
]

async function load() {
  error.value = ''
  try {
    const [companyRes, deviceRes, userRes, ticketRes, overviewRes] = await Promise.all([
      api.get<{ data: Company[] }>('/platform/companies'),
      api.get<{ data: DeviceRow[] }>('/platform/devices'),
      api.get<{ data: UserRow[] }>('/platform/users'),
      api.get<{ data: Ticket[] }>('/platform/support'),
      api.get<{ data: Overview }>('/platform/overview'),
    ])
    companies.value = companyRes.data
    devices.value = deviceRes.data
    users.value = userRes.data
    tickets.value = ticketRes.data
    overview.value = overviewRes.data
    if (!ticketCompany.value && companyRes.data[0]) ticketCompany.value = companyRes.data[0].id
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

async function run(action: () => Promise<void>) {
  error.value = ''
  try {
    await action()
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

async function createCompany() {
  if (!name.value.trim()) return
  const value = name.value.trim()
  await run(async () => {
    await api.post('/platform/tenants', { name: value })
    name.value = ''
  })
}

async function applyPlan(company: Company, plan: string) {
  await run(() => api.patch(`/platform/companies/${company.id}`, { plan }).then(() => undefined))
}

async function setLicense(company: Company, status: string) {
  await run(() => api.patch(`/platform/companies/${company.id}`, { license_status: status }).then(() => undefined))
}

async function addTicket() {
  if (!ticketCompany.value || !subject.value.trim() || !message.value.trim()) return
  const payload = { tenant_id: ticketCompany.value, subject: subject.value.trim(), message: message.value.trim() }
  await run(async () => {
    await api.post('/platform/support', payload)
    subject.value = ''
    message.value = ''
  })
}

async function closeTicket(id: string) {
  await run(() => api.post(`/platform/support/${id}/close`).then(() => undefined))
}

onMounted(load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('platform.title') }}</template>
    <template #subtitle>{{ t('platform.subtitle') }}</template>

    <div class="mb-4 flex flex-wrap gap-2">
      <button v-for="item in ['companies', 'licenses', 'subscriptions', 'devices', 'modules', 'users', 'stats', 'support']" :key="item" type="button" class="chip" :class="{ 'chip--on': tab === item }" @click="tab = item as typeof tab">
        {{ t(`platform.tabs.${item}`) }}
      </button>
    </div>
    <p v-if="error" class="mb-4 text-sm text-red-600">{{ error }}</p>

    <section v-if="tab === 'companies'" class="panel">
      <form class="mb-4 flex flex-wrap gap-2" @submit.prevent="createCompany">
        <input v-model="name" class="field" :placeholder="t('platform.companyName')" />
        <button class="btn" type="submit">{{ t('platform.create') }}</button>
      </form>
      <table class="min-w-full text-sm">
        <thead><tr><th>{{ t('org.name') }}</th><th>{{ t('platform.tabs.modules') }}</th><th>{{ t('platform.tabs.users') }}</th><th>{{ t('platform.tabs.devices') }}</th></tr></thead>
        <tbody>
          <tr v-for="company in companies" :key="company.id">
            <td>{{ company.name }}</td>
            <td>{{ company.modules.join(' + ') }}</td>
            <td>{{ company.users }}</td>
            <td>{{ company.devices }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <section v-else-if="tab === 'licenses'" class="panel">
      <table class="min-w-full text-sm">
        <thead><tr><th>{{ t('org.name') }}</th><th>{{ t('platform.key') }}</th><th>{{ t('platform.status') }}</th><th></th></tr></thead>
        <tbody>
          <tr v-for="company in companies" :key="company.id">
            <td>{{ company.name }}</td>
            <td class="font-mono text-xs">{{ company.license.key || '—' }}</td>
            <td>{{ company.license.status }}</td>
            <td class="text-right">
              <button class="btn" type="button" @click="setLicense(company, company.license.status === 'active' ? 'suspended' : 'active')">
                {{ company.license.status === 'active' ? t('platform.suspend') : t('platform.activate') }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <section v-else-if="tab === 'subscriptions' || tab === 'modules'" class="space-y-3">
      <article v-for="company in companies" :key="company.id" class="panel">
        <p class="font-semibold">{{ company.name }}</p>
        <p class="text-sm text-slate-500">{{ company.subscription.plan || t('platform.unset') }} · {{ company.modules.join(' + ') }}</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button v-for="plan in plans" :key="plan.id" type="button" class="chip" :class="{ 'chip--on': company.subscription.plan === plan.id }" @click="applyPlan(company, plan.id)">
            {{ t(`platform.plans.${plan.id}`) }}
          </button>
        </div>
      </article>
    </section>

    <section v-else-if="tab === 'devices'" class="panel">
      <table class="min-w-full text-sm">
        <thead><tr><th>{{ t('org.name') }}</th><th>{{ t('platform.company') }}</th><th>{{ t('desk.platform') }}</th><th>{{ t('platform.status') }}</th></tr></thead>
        <tbody>
          <tr v-for="device in devices" :key="device.id">
            <td>{{ device.name || device.code }}</td>
            <td>{{ device.company || '—' }}</td>
            <td>{{ device.platform || '—' }}</td>
            <td>{{ device.status || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!devices.length" class="text-sm text-slate-500">{{ t('org.empty') }}</p>
    </section>

    <section v-else-if="tab === 'users'" class="panel">
      <table class="min-w-full text-sm">
        <thead><tr><th>{{ t('org.name') }}</th><th>{{ t('platform.company') }}</th><th>Email</th></tr></thead>
        <tbody>
          <tr v-for="user in users" :key="user.id">
            <td>{{ user.name }}</td>
            <td>{{ user.company || '—' }}</td>
            <td>{{ user.email }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <section v-else-if="tab === 'stats'" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <div class="panel"><p class="label">{{ t('platform.tabs.companies') }}</p><p class="value">{{ overview?.companies ?? 0 }}</p></div>
      <div class="panel"><p class="label">{{ t('platform.tabs.users') }}</p><p class="value">{{ overview?.users ?? 0 }}</p></div>
      <div class="panel"><p class="label">{{ t('platform.tabs.devices') }}</p><p class="value">{{ overview?.devices ?? 0 }}</p></div>
      <div class="panel"><p class="label">{{ t('reports.revenue') }}</p><p class="value">{{ formatMoney(overview?.revenue ?? 0) }}</p></div>
    </section>

    <section v-else class="space-y-4">
      <form class="panel grid gap-3" @submit.prevent="addTicket">
        <div>
          <FieldLabel icon="store-pin">{{ t('platform.company') }}</FieldLabel>
          <select v-model="ticketCompany" class="field">
            <option v-for="company in companies" :key="company.id" :value="company.id">{{ company.name }}</option>
          </select>
        </div>
        <input v-model="subject" class="field" :placeholder="t('platform.subject')" />
        <textarea v-model="message" class="field" rows="3" :placeholder="t('platform.message')" />
        <button class="btn" type="submit">{{ t('platform.create') }}</button>
      </form>
      <article v-for="ticket in tickets" :key="ticket.id" class="panel">
        <p class="font-semibold">{{ ticket.subject }} <span class="text-sm font-normal text-slate-500">{{ ticket.company }} · {{ ticket.status }}</span></p>
        <p class="text-sm">{{ ticket.message }}</p>
        <button v-if="ticket.status === 'open'" class="btn mt-2" type="button" @click="closeTicket(ticket.id)">{{ t('platform.close') }}</button>
      </article>
    </section>
  </PageFrame>
</template>

<style scoped>
.panel { border-radius: 0.85rem; background: white; padding: 1rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); }
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn { border-radius: 0.5rem; padding: 0.45rem 0.8rem; font-weight: 600; color: white; background: var(--color-brand-600); }
.chip { border-radius: 999px; border: 1px solid #cbd5e1; padding: 0.35rem 0.7rem; font-size: 0.8rem; }
.chip--on { border-color: var(--color-brand-600); color: var(--color-brand-700); background: #f8fafc; }
.label { margin: 0; font-size: 0.75rem; color: #64748b; }
.value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; }
th, td { padding: 0.55rem 0.4rem; text-align: left; border-top: 1px solid #f1f5f9; }
</style>
