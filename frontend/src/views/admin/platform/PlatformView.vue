<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useAuthStore } from '../../../stores/auth'
import { useBrandingStore } from '../../../stores/branding'
import { useContextStore } from '../../../stores/context'
import { MODULE_CODES } from '../../../modules/registry'
import PlatformBackupsPanel from './PlatformBackupsPanel.vue'
import PlatformPlansPanel from './PlatformPlansPanel.vue'
import { formatDateTime, formatMoney } from '../../../utils/format'

type Company = {
  id: string
  name: string
  slug?: string
  status?: string
  modules: string[]
  license: { key?: string | null; status: string; seats: number; expires_on?: string | null }
  subscription: { plan?: string | null; status: string; renews_on?: string | null }
  billing?: {
    plan: string
    status: string
    billing_cycle?: string
    renews_on?: string | null
    grace_ends_on?: string | null
    trial_ends_on?: string | null
    pending_plan?: string | null
    open_invoice?: { id: string; number: string; amount: number } | null
  } | null
  users: number
  devices: number
  open_support: number
}
type DeviceRow = { id: string; company?: string | null; name?: string; code?: string; platform?: string | null; status?: string | null; last_sync_at?: string | null }
type UserRow = { id: string; company?: string | null; name: string; email: string; is_active?: boolean }
type Ticket = { id: string; company: string; tenant_id: string; subject: string; message: string; status: string; created_at?: string }
type AuditRow = { id: string; action: string; tenant_id?: string | null; payload?: Record<string, unknown> | null; ip_address?: string | null; created_at?: string; actor?: { name: string; email: string } | null }
type Overview = { companies: number; users: number; devices: number; sales: number; revenue: number; plans?: Record<string, number> }
type Tab = 'companies' | 'licenses' | 'subscriptions' | 'devices' | 'modules' | 'users' | 'stats' | 'support' | 'audit' | 'backups'
type BadgeVariant = 'success' | 'neutral' | 'brand' | 'warning' | 'danger' | 'info'

const moduleCodes = MODULE_CODES
const subscriptionStatuses = ['active', 'trial', 'past_due', 'suspended', 'cancelled'] as const
const licenseStatuses = ['active', 'suspended', 'expired'] as const
const companyStatuses = ['trial', 'active', 'past_due', 'suspended', 'cancelled', 'archived'] as const
const plans = [
  { id: 'pos_stock', modules: ['pos', 'inventory'] },
  { id: 'pos_stock_restaurant', modules: ['pos', 'inventory', 'restaurant'] },
  { id: 'pos_stock_hotel_restaurant', modules: ['pos', 'inventory', 'hotel', 'restaurant'] },
]
const tabs: { id: Tab; icon: string }[] = [
  { id: 'companies', icon: 'building' },
  { id: 'licenses', icon: 'key' },
  { id: 'subscriptions', icon: 'coins' },
  { id: 'modules', icon: 'layers' },
  { id: 'devices', icon: 'device-tablet' },
  { id: 'users', icon: 'customers' },
  { id: 'stats', icon: 'dashboard' },
  { id: 'support', icon: 'mail' },
  { id: 'audit', icon: 'receipt' },
  { id: 'backups', icon: 'layers' },
]

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const brandingStore = useBrandingStore()
const context = useContextStore()
const allowed = computed(() => auth.user?.is_super_admin === true && !auth.user.tenant_id)

const tab = ref<Tab>('companies')
const companies = ref<Company[]>([])
const devices = ref<DeviceRow[]>([])
const users = ref<UserRow[]>([])
const tickets = ref<Ticket[]>([])
const audit = ref<AuditRow[]>([])
const overview = ref<Overview | null>(null)
const error = ref('')
const notice = ref('')
const loading = ref(false)
const busy = ref(false)
const search = ref('')
const ticketFilter = ref<'all' | 'open' | 'closed'>('all')
const showCreate = ref(false)
const showManage = ref(false)
const subject = ref('')
const message = ref('')
const ticketCompany = ref('')
const createForm = ref(emptyCreate())
const editor = ref(emptyEditor())

function emptyCreate() {
  return {
    name: '',
    slug: '',
    currency_code: 'FBU',
    locale: 'fr',
    timezone: 'Africa/Bujumbura',
    email: '',
    phone: '',
    legal_name: '',
    trade_name: '',
    website: '',
    country_code: 'BI',
    tax_regime: '',
    tax_id: '',
    registration_number: '',
    status: 'trial',
    plan: 'pos_stock',
    admin_name: '',
    admin_email: '',
    admin_password: '',
  }
}

function emptyEditor() {
  return {
    id: '',
    name: '',
    status: 'active',
    plan: '',
    modules: ['pos', 'inventory'] as string[],
    license_status: 'active',
    seats: 0,
    expires_on: '',
    subscription_status: 'active',
    renews_on: '',
  }
}

const query = computed(() => search.value.trim().toLowerCase())

const filteredCompanies = computed(() => {
  const q = query.value
  if (!q) return companies.value
  return companies.value.filter(company =>
    [company.name, company.slug, company.id, company.license.key].some(value => (value ?? '').toLowerCase().includes(q)),
  )
})

const filteredDevices = computed(() => {
  const q = query.value
  if (!q) return devices.value
  return devices.value.filter(device =>
    [device.name, device.code, device.company, device.platform].some(value => (value ?? '').toLowerCase().includes(q)),
  )
})

const filteredUsers = computed(() => {
  const q = query.value
  if (!q) return users.value
  return users.value.filter(user =>
    [user.name, user.email, user.company].some(value => (value ?? '').toLowerCase().includes(q)),
  )
})

const filteredTickets = computed(() => {
  return tickets.value.filter(ticket => ticketFilter.value === 'all' || ticket.status === ticketFilter.value)
})

const planRows = computed(() => Object.entries(overview.value?.plans ?? {}))

function planLabel(plan?: string | null) {
  if (!plan || plan === 'unset') return t('platform.unset')
  const key = `platform.plans.${plan}`
  const label = t(key)
  return label === key ? plan : label
}

function statusVariant(status?: string | null): BadgeVariant {
  if (status === 'active') return 'success'
  if (status === 'trial') return 'info'
  if (status === 'suspended' || status === 'past_due') return 'warning'
  if (status === 'expired' || status === 'cancelled') return 'danger'
  return 'neutral'
}

function statusLabel(status?: string | null) {
  if (!status) return '—'
  if (status === 'active') return t('platform.active')
  if (status === 'suspended') return t('platform.suspended')
  if (status === 'expired') return t('platform.expired')
  if (status === 'archived') return t('platform.archived')
  if ((subscriptionStatuses as readonly string[]).includes(status)) return t(`platform.subscriptionStatuses.${status}`)
  return status
}

function tenantName(id?: string | null) {
  if (!id) return '—'
  return companies.value.find(company => company.id === id)?.name ?? id
}

function sameModules(left: string[], right: string[]) {
  return left.length === right.length && left.every(code => right.includes(code))
}

async function load() {
  error.value = ''
  loading.value = true
  try {
    const companyRes = await api.get<{ data: Company[] }>('/platform/companies')
    const deviceRes = await api.get<{ data: DeviceRow[] }>('/platform/devices')
    const userRes = await api.get<{ data: UserRow[] }>('/platform/users')
    const ticketRes = await api.get<{ data: Ticket[] }>('/platform/support')
    const overviewRes = await api.get<{ data: Overview }>('/platform/overview')
    const auditRes = await api.get<{ data: AuditRow[] }>('/platform/audit')
    companies.value = companyRes.data
    devices.value = deviceRes.data
    users.value = userRes.data
    tickets.value = ticketRes.data
    overview.value = overviewRes.data
    audit.value = auditRes.data
    if (!ticketCompany.value && companyRes.data[0]) ticketCompany.value = companyRes.data[0].id
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function run(action: () => Promise<void>) {
  if (busy.value) return
  error.value = ''
  notice.value = ''
  busy.value = true
  try {
    await action()
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = false
  }
}

function openCreate() {
  createForm.value = emptyCreate()
  error.value = ''
  showCreate.value = true
}

const sectionByRoute: Record<string, Tab> = {
  platform: 'stats',
  'platform-tenants': 'companies',
  'platform-plans': 'subscriptions',
  'platform-users': 'users',
  'platform-support': 'support',
  'platform-audit': 'audit',
  'platform-backups': 'backups',
}
const routeByTab: Partial<Record<Tab, string>> = {
  stats: 'platform',
  companies: 'platform-tenants',
  subscriptions: 'platform-plans',
  users: 'platform-users',
  support: 'platform-support',
  audit: 'platform-audit',
  backups: 'platform-backups',
}

function applyRouteSection() {
  const section = sectionByRoute[String(route.name)]
  if (section) tab.value = section
}

applyRouteSection()

function selectTab(id: Tab) {
  tab.value = id
  const name = routeByTab[id]
  if (name && route.name !== name) void router.replace({ name })
}

async function createCompany() {
  if (!createForm.value.name.trim()) return
  const form = createForm.value
  if (form.admin_email.trim() && form.admin_password.length < 8) {
    error.value = t('platform.adminPasswordHint')
    return
  }
  await run(async () => {
    await api.post('/platform/tenants', {
      name: form.name.trim(),
      slug: form.slug.trim() || undefined,
      currency_code: form.currency_code.trim() || undefined,
      locale: form.locale.trim() || undefined,
      timezone: form.timezone.trim() || undefined,
      email: form.email.trim() || undefined,
      phone: form.phone.trim() || undefined,
      legal_name: form.legal_name.trim() || undefined,
      trade_name: form.trade_name.trim() || undefined,
      website: form.website.trim() || undefined,
      country_code: form.country_code.trim() || undefined,
      tax_regime: form.tax_regime.trim() || undefined,
      tax_id: form.tax_id.trim() || undefined,
      registration_number: form.registration_number.trim() || undefined,
      status: form.status,
      plan: form.plan,
      admin_name: form.admin_name.trim() || undefined,
      admin_email: form.admin_email.trim() || undefined,
      admin_password: form.admin_password || undefined,
    })
    showCreate.value = false
  })
}

function openManage(company: Company) {
  editor.value = {
    id: company.id,
    name: company.name,
    status: company.status || 'active',
    plan: company.subscription.plan || '',
    modules: [...company.modules],
    license_status: company.license.status || 'active',
    seats: company.license.seats ?? 0,
    expires_on: (company.license.expires_on ?? '').slice(0, 10),
    subscription_status: company.subscription.status || 'active',
    renews_on: (company.subscription.renews_on ?? '').slice(0, 10),
  }
  error.value = ''
  showManage.value = true
}

function applyEditorPlan(planId: string) {
  const plan = plans.find(item => item.id === planId)
  if (!plan) return
  editor.value.plan = planId
  editor.value.modules = [...plan.modules]
}

function toggleEditorModule(code: string) {
  const current = editor.value.modules
  const next = current.includes(code) ? current.filter(item => item !== code) : [...current, code]
  if (!next.length) return
  editor.value.modules = next
  const match = plans.find(plan => sameModules(plan.modules, next))
  if (match) editor.value.plan = match.id
}

async function saveCompany() {
  const form = editor.value
  await run(async () => {
    await api.patch(`/platform/companies/${form.id}`, {
      status: form.status,
      plan: form.plan || null,
      modules: form.modules,
      license_status: form.license_status,
      license_seats: Number(form.seats) || 0,
      license_expires_on: form.expires_on || null,
      subscription_status: form.subscription_status,
      renews_on: form.renews_on || null,
    })
    showManage.value = false
  })
}

async function setCompanyStatus(company: Company, status: string) {
  await run(() => api.patch(`/platform/companies/${company.id}`, { status }).then(() => undefined))
}

function commercialPlan(company: Company) {
  return company.billing?.plan || company.subscription.plan
}

function commercialStatus(company: Company) {
  return company.billing?.status || company.subscription.status
}

async function startGrace(company: Company) {
  await run(() => api.post(`/platform/tenants/${company.id}/subscription/grace`).then(() => undefined))
}

async function suspendBilling(company: Company) {
  await run(() => api.post(`/platform/tenants/${company.id}/subscription/suspend`).then(() => undefined))
}

async function collectInvoice(company: Company) {
  const invoice = company.billing?.open_invoice
  if (!invoice) return
  await run(() => api.post(`/platform/invoices/${invoice.id}/payments`, { method: 'manual', status: 'succeeded' }).then(() => undefined))
}

async function copyId(id: string) {
  notice.value = ''
  try {
    await navigator.clipboard.writeText(id)
    notice.value = t('platform.copied')
  } catch {
    notice.value = id
  }
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

async function switchAccount() {
  await auth.logout()
  brandingStore.clear()
  context.reset()
  await router.push({ name: 'login' })
}

watch(() => route.name, applyRouteSection)

onMounted(() => {
  applyRouteSection()
  if (allowed.value) void load()
})
</script>

<template>
  <PageFrame>
    <template #title>{{ t('platform.title') }}</template>
    <template #subtitle>{{ t('platform.subtitle') }}</template>

    <EmptyState
      v-if="!allowed"
      icon="building"
      :title="t('platform.title')"
      :description="t('platform.denied', { email: auth.user?.email || '—' })"
    >
      <button class="btn-primary" type="button" @click="switchAccount">{{ t('platform.switchAccount') }}</button>
    </EmptyState>

    <div v-else class="platform">
      <div class="platform-kpis">
        <KpiCard :label="t('platform.tabs.companies')" :value="overview?.companies ?? 0" icon="building" />
        <KpiCard :label="t('platform.tabs.users')" :value="overview?.users ?? 0" icon="customers" accent="var(--color-info, #2563eb)" icon-bg="var(--color-info-50, #eff6ff)" />
        <KpiCard :label="t('platform.tabs.devices')" :value="overview?.devices ?? 0" icon="device-tablet" accent="#0f766e" icon-bg="#f0fdfa" />
        <KpiCard :label="t('platform.sales')" :value="overview?.sales ?? 0" icon="sales" accent="#b45309" icon-bg="#fffbeb" />
        <KpiCard :label="t('reports.revenue')" :value="formatMoney(overview?.revenue ?? 0)" icon="coins" accent="#15803d" icon-bg="#f0fdf4" />
      </div>

      <nav class="sub-nav" :aria-label="t('platform.title')">
        <button
          v-for="item in tabs"
          :key="item.id"
          type="button"
          class="sub-nav__link"
          :class="{ 'sub-nav__link--active': tab === item.id }"
          @click="selectTab(item.id)"
        >
          <span class="sub-nav__mark"><AppIcon :name="item.icon" :size="18" /></span>
          <span>{{ t(`platform.tabs.${item.id}`) }}</span>
        </button>
      </nav>

      <p v-if="error" class="platform-alert">{{ error }}</p>
      <p v-else-if="notice" class="platform-note">{{ notice }}</p>

      <DataTableShell
        v-if="tab === 'companies'"
        :title="t('platform.tabs.companies')"
        :meta="t('platform.subtitle')"
        :loading="loading"
        :empty="!loading && !filteredCompanies.length"
        :empty-title="t('platform.empty')"
        :empty-icon="'building'"
        :loading-label="t('platform.loading')"
      >
        <template #toolbar>
          <input v-model="search" class="field platform-search" type="search" :placeholder="t('platform.search')" />
          <button class="btn-primary" type="button" @click="openCreate">{{ t('platform.create') }}</button>
        </template>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('org.name') }}</th>
              <th>{{ t('platform.status') }}</th>
              <th>{{ t('platform.tabs.modules') }}</th>
              <th>{{ t('platform.tabs.users') }}</th>
              <th>{{ t('platform.tabs.devices') }}</th>
              <th>{{ t('platform.openSupport') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="company in filteredCompanies" :key="company.id">
              <td>
                <p class="font-medium">{{ company.name }}</p>
                <p class="platform-muted">{{ company.slug }}</p>
              </td>
              <td><Badge :variant="statusVariant(company.status)" dot>{{ statusLabel(company.status) }}</Badge></td>
              <td>{{ company.modules.map(code => t(`platform.moduleNames.${code}`)).join(' · ') || '—' }}</td>
              <td>{{ company.users }}</td>
              <td>{{ company.devices }}</td>
              <td>{{ company.open_support }}</td>
              <td class="text-right">
                <button class="btn-secondary" type="button" @click="openManage(company)">{{ t('platform.edit') }}</button>
                <button class="btn-secondary" type="button" :disabled="busy" @click="copyId(company.id)">{{ t('platform.copyId') }}</button>
                <button class="btn-secondary" type="button" :disabled="busy" @click="setCompanyStatus(company, company.status === 'active' ? 'suspended' : 'active')">
                  {{ company.status === 'active' ? t('platform.suspend') : t('platform.activate') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell
        v-else-if="tab === 'licenses'"
        :title="t('platform.tabs.licenses')"
        :loading="loading"
        :empty="!loading && !filteredCompanies.length"
        :empty-title="t('platform.empty')"
        empty-icon="key"
        :loading-label="t('platform.loading')"
      >
        <template #toolbar>
          <input v-model="search" class="field platform-search" type="search" :placeholder="t('platform.search')" />
        </template>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('org.name') }}</th>
              <th>{{ t('platform.key') }}</th>
              <th>{{ t('platform.status') }}</th>
              <th>{{ t('platform.seats') }}</th>
              <th>{{ t('platform.expires') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="company in filteredCompanies" :key="company.id">
              <td class="font-medium">{{ company.name }}</td>
              <td class="font-mono text-xs">{{ company.license.key || '—' }}</td>
              <td><Badge :variant="statusVariant(company.license.status)" dot>{{ statusLabel(company.license.status) }}</Badge></td>
              <td>{{ company.license.seats }}</td>
              <td>{{ company.license.expires_on || '—' }}</td>
              <td class="text-right">
                <button class="btn-secondary" type="button" @click="openManage(company)">{{ t('platform.edit') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <div v-else-if="tab === 'subscriptions'" class="platform-billing">
      <PlatformPlansPanel />
      <DataTableShell
        :title="t('platform.tabs.subscriptions')"
        :loading="loading"
        :empty="!loading && !filteredCompanies.length"
        :empty-title="t('platform.empty')"
        empty-icon="coins"
        :loading-label="t('platform.loading')"
      >
        <template #toolbar>
          <input v-model="search" class="field platform-search" type="search" :placeholder="t('platform.search')" />
        </template>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('org.name') }}</th>
              <th>{{ t('platform.tabs.subscriptions') }}</th>
              <th>{{ t('platform.status') }}</th>
              <th>{{ t('platform.renews') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="company in filteredCompanies" :key="company.id">
              <td class="font-medium">{{ company.name }}</td>
              <td>
                {{ planLabel(commercialPlan(company)) }}
                <span v-if="company.billing?.pending_plan" class="platform-muted">{{ t('platform.billing.pending', { plan: planLabel(company.billing.pending_plan) }) }}</span>
              </td>
              <td><Badge :variant="statusVariant(commercialStatus(company))" dot>{{ statusLabel(commercialStatus(company)) }}</Badge></td>
              <td>{{ company.billing?.renews_on || company.subscription.renews_on || company.billing?.grace_ends_on || '—' }}</td>
              <td class="text-right platform-actions">
                <button v-if="company.billing?.open_invoice" class="btn-secondary" type="button" @click="collectInvoice(company)">{{ t('platform.billing.collect') }}</button>
                <button v-if="commercialStatus(company) !== 'past_due'" class="btn-secondary" type="button" @click="startGrace(company)">{{ t('platform.billing.grace') }}</button>
                <button v-if="commercialStatus(company) !== 'suspended'" class="btn-secondary" type="button" @click="suspendBilling(company)">{{ t('platform.billing.suspend') }}</button>
                <button class="btn-secondary" type="button" @click="openManage(company)">{{ t('platform.edit') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>
      </div>

      <DataTableShell
        v-else-if="tab === 'modules'"
        :title="t('platform.tabs.modules')"
        :meta="t('platform.modulesHint')"
        :loading="loading"
        :empty="!loading && !filteredCompanies.length"
        :empty-title="t('platform.empty')"
        empty-icon="layers"
        :loading-label="t('platform.loading')"
      >
        <template #toolbar>
          <input v-model="search" class="field platform-search" type="search" :placeholder="t('platform.search')" />
        </template>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('org.name') }}</th>
              <th v-for="code in moduleCodes" :key="code">{{ t(`platform.moduleNames.${code}`) }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="company in filteredCompanies" :key="company.id">
              <td class="font-medium">{{ company.name }}</td>
              <td v-for="code in moduleCodes" :key="code">
                <Badge :variant="company.modules.includes(code) ? 'success' : 'neutral'" dot>
                  {{ company.modules.includes(code) ? t('platform.active') : t('platform.inactive') }}
                </Badge>
              </td>
              <td class="text-right">
                <button class="btn-secondary" type="button" @click="openManage(company)">{{ t('platform.edit') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell
        v-else-if="tab === 'devices'"
        :title="t('platform.tabs.devices')"
        :loading="loading"
        :empty="!loading && !filteredDevices.length"
        :empty-title="t('platform.empty')"
        empty-icon="device-tablet"
        :loading-label="t('platform.loading')"
      >
        <template #toolbar>
          <input v-model="search" class="field platform-search" type="search" :placeholder="t('platform.search')" />
        </template>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('org.name') }}</th>
              <th>{{ t('platform.company') }}</th>
              <th>{{ t('desk.platform') }}</th>
              <th>{{ t('platform.status') }}</th>
              <th>{{ t('platform.lastSync') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="device in filteredDevices" :key="device.id">
              <td class="font-medium">{{ device.name || device.code }}</td>
              <td>{{ device.company || '—' }}</td>
              <td>{{ device.platform || '—' }}</td>
              <td><Badge :variant="statusVariant(device.status)" dot>{{ device.status || '—' }}</Badge></td>
              <td>{{ formatDateTime(device.last_sync_at) }}</td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell
        v-else-if="tab === 'users'"
        :title="t('platform.tabs.users')"
        :loading="loading"
        :empty="!loading && !filteredUsers.length"
        :empty-title="t('platform.empty')"
        empty-icon="customers"
        :loading-label="t('platform.loading')"
      >
        <template #toolbar>
          <input v-model="search" class="field platform-search" type="search" :placeholder="t('platform.search')" />
        </template>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('org.name') }}</th>
              <th>{{ t('platform.company') }}</th>
              <th>{{ t('platform.email') }}</th>
              <th>{{ t('platform.status') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="user in filteredUsers" :key="user.id">
              <td class="font-medium">{{ user.name }}</td>
              <td>{{ user.company || '—' }}</td>
              <td>{{ user.email }}</td>
              <td><Badge :variant="user.is_active ? 'success' : 'neutral'" dot>{{ user.is_active ? t('platform.active') : t('platform.inactive') }}</Badge></td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <section v-else-if="tab === 'stats'" class="platform-stats">
        <article v-for="[plan, count] in planRows" :key="plan" class="platform-plan">
          <p class="platform-muted">{{ planLabel(plan) }}</p>
          <p class="platform-plan__value">{{ count }}</p>
        </article>
        <p v-if="!planRows.length && !loading" class="platform-muted">{{ t('platform.empty') }}</p>
      </section>

      <PlatformBackupsPanel v-else-if="tab === 'backups'" />

      <DataTableShell
        v-else-if="tab === 'audit'"
        :title="t('platform.tabs.audit')"
        :meta="t('platform.subtitle')"
        :loading="loading"
        :empty="!loading && !audit.length"
        :empty-title="t('platform.empty')"
      >
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('platform.when') }}</th>
              <th>{{ t('platform.actor') }}</th>
              <th>{{ t('platform.action') }}</th>
              <th>{{ t('platform.company') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in audit" :key="row.id">
              <td>{{ row.created_at ? formatDateTime(row.created_at) : '—' }}</td>
              <td>{{ row.actor?.name || '—' }}</td>
              <td><Badge variant="neutral">{{ row.action }}</Badge></td>
              <td>{{ tenantName(row.tenant_id) }}</td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <div v-else-if="tab === 'support'" class="platform-support">
        <form class="platform-card" @submit.prevent="addTicket">
          <div>
            <FieldLabel icon="building">{{ t('platform.company') }}</FieldLabel>
            <select v-model="ticketCompany" class="field" :disabled="busy">
              <option v-for="company in companies" :key="company.id" :value="company.id">{{ company.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="mail">{{ t('platform.subject') }}</FieldLabel>
            <input v-model="subject" class="field" :disabled="busy" />
          </div>
          <div>
            <FieldLabel icon="mail">{{ t('platform.message') }}</FieldLabel>
            <textarea v-model="message" class="field" rows="4" :disabled="busy" />
          </div>
          <button class="btn-primary" type="submit" :disabled="busy || !ticketCompany || !subject.trim() || !message.trim()">{{ t('platform.create') }}</button>
        </form>

        <DataTableShell
          :title="t('platform.tabs.support')"
          :loading="loading"
          :empty="!loading && !filteredTickets.length"
          :empty-title="t('platform.empty')"
          empty-icon="mail"
          :loading-label="t('platform.loading')"
        >
          <template #toolbar>
            <select v-model="ticketFilter" class="field">
              <option value="all">{{ t('platform.all') }}</option>
              <option value="open">{{ t('platform.active') }}</option>
              <option value="closed">{{ t('platform.close') }}</option>
            </select>
          </template>
          <table class="ui-table min-w-full">
            <thead>
              <tr>
                <th>{{ t('platform.subject') }}</th>
                <th>{{ t('platform.company') }}</th>
                <th>{{ t('platform.status') }}</th>
                <th>{{ t('platform.message') }}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="ticket in filteredTickets" :key="ticket.id">
                <td class="font-medium">{{ ticket.subject }}</td>
                <td>{{ ticket.company }}</td>
                <td><Badge :variant="ticket.status === 'open' ? 'warning' : 'neutral'" dot>{{ ticket.status }}</Badge></td>
                <td class="platform-message">{{ ticket.message }}</td>
                <td class="text-right">
                  <button v-if="ticket.status === 'open'" class="btn-secondary" type="button" :disabled="busy" @click="closeTicket(ticket.id)">{{ t('platform.close') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </DataTableShell>
      </div>
    </div>

    <AppModal :open="showCreate" :title="t('platform.createTitle')" icon="building" size="lg" @close="showCreate = false">
      <form class="platform-form" @submit.prevent="createCompany">
        <div>
          <FieldLabel icon="building">{{ t('platform.companyName') }}</FieldLabel>
          <input v-model="createForm.name" class="field" required />
        </div>
        <div class="platform-form__grid">
          <div>
            <FieldLabel icon="tag">{{ t('platform.slug') }}</FieldLabel>
            <input v-model="createForm.slug" class="field" />
          </div>
          <div>
            <FieldLabel icon="coins">{{ t('platform.currency') }}</FieldLabel>
            <input v-model="createForm.currency_code" class="field" maxlength="3" />
          </div>
          <div>
            <FieldLabel icon="account">{{ t('platform.locale') }}</FieldLabel>
            <input v-model="createForm.locale" class="field" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('platform.timezone') }}</FieldLabel>
            <input v-model="createForm.timezone" class="field" />
          </div>
          <div>
            <FieldLabel icon="mail">{{ t('platform.email') }}</FieldLabel>
            <input v-model="createForm.email" class="field" type="email" />
          </div>
          <div>
            <FieldLabel icon="account">{{ t('platform.phone') }}</FieldLabel>
            <input v-model="createForm.phone" class="field" />
          </div>
          <div>
            <FieldLabel icon="building">{{ t('platform.legalName') }}</FieldLabel>
            <input v-model="createForm.legal_name" class="field" />
          </div>
          <div>
            <FieldLabel icon="tag">{{ t('platform.tradeName') }}</FieldLabel>
            <input v-model="createForm.trade_name" class="field" />
          </div>
          <div>
            <FieldLabel icon="mail">{{ t('platform.website') }}</FieldLabel>
            <input v-model="createForm.website" class="field" />
          </div>
          <div>
            <FieldLabel icon="building">{{ t('platform.country') }}</FieldLabel>
            <input v-model="createForm.country_code" class="field" maxlength="2" />
          </div>
          <div>
            <FieldLabel icon="receipt">{{ t('platform.taxRegime') }}</FieldLabel>
            <input v-model="createForm.tax_regime" class="field" />
          </div>
          <div>
            <FieldLabel icon="receipt">{{ t('platform.taxId') }}</FieldLabel>
            <input v-model="createForm.tax_id" class="field" />
          </div>
          <div>
            <FieldLabel icon="receipt">{{ t('platform.registrationNumber') }}</FieldLabel>
            <input v-model="createForm.registration_number" class="field" />
          </div>
          <div>
            <FieldLabel icon="building">{{ t('platform.status') }}</FieldLabel>
            <select v-model="createForm.status" class="field">
              <option v-for="status in companyStatuses" :key="status" :value="status">{{ statusLabel(status) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="coins">{{ t('platform.plan') }}</FieldLabel>
            <select v-model="createForm.plan" class="field">
              <option v-for="plan in plans" :key="plan.id" :value="plan.id">{{ planLabel(plan.id) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="customers">{{ t('platform.adminName') }}</FieldLabel>
            <input v-model="createForm.admin_name" class="field" />
          </div>
          <div>
            <FieldLabel icon="mail">{{ t('platform.adminEmail') }}</FieldLabel>
            <input v-model="createForm.admin_email" class="field" type="email" autocomplete="off" />
          </div>
          <div>
            <FieldLabel icon="key">{{ t('platform.adminPassword') }}</FieldLabel>
            <input v-model="createForm.admin_password" class="field" type="password" autocomplete="new-password" />
          </div>
        </div>
        <p class="platform-note">{{ t('platform.adminPasswordHint') }}</p>
      </form>
      <template #footer>
        <button class="btn-secondary" type="button" @click="showCreate = false">{{ t('platform.close') }}</button>
        <button class="btn-primary" type="button" :disabled="busy || !createForm.name.trim()" @click="createCompany">{{ t('platform.create') }}</button>
      </template>
    </AppModal>

    <AppModal :open="showManage" :title="editor.name || t('platform.manageTitle')" :subtitle="t('platform.manageTitle')" icon="building" size="xl" @close="showManage = false">
      <form class="platform-form" @submit.prevent="saveCompany">
        <div class="platform-form__grid">
          <div>
            <FieldLabel icon="building">{{ t('platform.status') }}</FieldLabel>
            <select v-model="editor.status" class="field">
              <option v-for="status in companyStatuses" :key="status" :value="status">{{ statusLabel(status) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="key">{{ t('platform.tabs.licenses') }}</FieldLabel>
            <select v-model="editor.license_status" class="field">
              <option v-for="status in licenseStatuses" :key="status" :value="status">{{ statusLabel(status) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="customers">{{ t('platform.seats') }}</FieldLabel>
            <input v-model.number="editor.seats" class="field" type="number" min="0" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('platform.expires') }}</FieldLabel>
            <input v-model="editor.expires_on" class="field" type="date" />
          </div>
          <div>
            <FieldLabel icon="coins">{{ t('platform.tabs.subscriptions') }}</FieldLabel>
            <select v-model="editor.subscription_status" class="field">
              <option v-for="status in subscriptionStatuses" :key="status" :value="status">{{ t(`platform.subscriptionStatuses.${status}`) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('platform.renews') }}</FieldLabel>
            <input v-model="editor.renews_on" class="field" type="date" />
          </div>
        </div>

        <div>
          <FieldLabel icon="layers">{{ t('platform.tabs.subscriptions') }}</FieldLabel>
          <div class="platform-choices">
            <button
              v-for="plan in plans"
              :key="plan.id"
              type="button"
              class="platform-choice"
              :class="{ 'platform-choice--on': editor.plan === plan.id }"
              @click="applyEditorPlan(plan.id)"
            >
              {{ t(`platform.plans.${plan.id}`) }}
            </button>
          </div>
        </div>

        <div>
          <FieldLabel icon="layers">{{ t('platform.tabs.modules') }}</FieldLabel>
          <p class="platform-muted">{{ t('platform.modulesHint') }}</p>
          <div class="platform-choices">
            <button
              v-for="code in moduleCodes"
              :key="code"
              type="button"
              class="platform-choice"
              :class="{ 'platform-choice--on': editor.modules.includes(code) }"
              @click="toggleEditorModule(code)"
            >
              {{ t(`platform.moduleNames.${code}`) }}
            </button>
          </div>
        </div>
      </form>
      <template #footer>
        <button class="btn-secondary" type="button" @click="showManage = false">{{ t('platform.close') }}</button>
        <button class="btn-primary" type="button" :disabled="busy" @click="saveCompany">{{ t('platform.save') }}</button>
      </template>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.platform { display: flex; flex-direction: column; gap: var(--section-gap, 1rem); width: 100%; min-width: 0; }
.platform-billing { display: flex; flex-direction: column; gap: 1rem; }
.platform-actions { display: flex; flex-wrap: wrap; gap: 0.35rem; justify-content: flex-end; }
.platform-kpis { display: grid; gap: 0.75rem; width: 100%; grid-template-columns: repeat(auto-fit, minmax(9.25rem, 1fr)); }
.platform-search { min-width: 14rem; }
.platform-alert { margin: 0; color: var(--color-danger, #b91c1c); font-size: 0.875rem; }
.platform-note { margin: 0; color: var(--color-text-secondary); font-size: 0.875rem; }
.platform-muted { margin: 0.15rem 0 0; color: var(--color-text-muted); font-size: 0.75rem; }
.platform-stats { display: grid; gap: 0.75rem; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); }
.platform-plan, .platform-card {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg, 0.85rem);
  background: var(--color-surface);
  padding: 1rem;
}
.platform-plan__value { margin: 0.35rem 0 0; font-size: 1.5rem; font-weight: 700; }
.platform-support { display: grid; gap: 1rem; }
.platform-form { display: grid; gap: 0.9rem; }
.platform-form__grid { display: grid; gap: 0.9rem; grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr)); }
.platform-choices { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 0.45rem; }
.platform-choice {
  border: 1px solid var(--color-border-strong, #cbd5e1);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  padding: 0.4rem 0.75rem;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
}
.platform-choice--on {
  border-color: var(--color-brand-600);
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-700));
}
.platform-message { max-width: 28rem; white-space: normal; }
.sub-nav__link { border: 0; background: transparent; cursor: pointer; font-family: inherit; }
button.btn-secondary + button.btn-secondary { margin-left: 0.4rem; }
</style>
