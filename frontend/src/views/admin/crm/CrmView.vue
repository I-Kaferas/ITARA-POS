<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { formatMoney } from '../../../utils/format'

type Party = { id: string; name: string; code?: string; email?: string | null; phone?: string | null; crm_role?: string; job_title?: string | null; account?: { name: string } | null }
type Account = { id: string; name: string; legal_name?: string | null; email?: string | null; phone?: string | null; contacts_count?: number }
type Lead = { id: string; name: string; email?: string | null; phone?: string | null; company_name?: string | null; source?: string; status: string }
type Stage = { id: string; name: string; is_won: boolean; is_lost: boolean; opportunities?: Opportunity[] }
type Opportunity = { id: string; title: string; amount: number; status: string; stage?: { name: string }; customer?: { name: string } | null }
type Activity = { id: string; type: string; subject: string; status: string; customer?: { name: string } | null }
type Campaign = { id: string; name: string; channel: string; status: string; members_count?: number }
type Overview = { prospects: number; clients: number; accounts: number; contacts: number; leads: number; opportunities: number; pipeline_amount: number; tasks: number; campaigns: number }
type Dossier = { customer: Party; loyalty: { points: number; tier: string }; usage: Record<string, number> }
type Tab = 'pipeline' | 'prospects' | 'clients' | 'accounts' | 'contacts' | 'leads' | 'activities' | 'campaigns'

const tabs: Tab[] = ['pipeline', 'prospects', 'clients', 'accounts', 'contacts', 'leads', 'activities', 'campaigns']
const activityTypes = ['call', 'email', 'note', 'task'] as const

const { t } = useI18n()
const tab = ref<Tab>('pipeline')
const error = ref('')
const loading = ref(false)
const busy = ref(false)
const showForm = ref(false)
const showDossier = ref(false)
const overview = ref<Overview | null>(null)
const stages = ref<Stage[]>([])
const parties = ref<Party[]>([])
const accounts = ref<Account[]>([])
const leads = ref<Lead[]>([])
const activities = ref<Activity[]>([])
const campaigns = ref<Campaign[]>([])
const dossier = ref<Dossier | null>(null)
const form = ref(emptyForm())

function emptyForm() {
  return {
    name: '',
    email: '',
    phone: '',
    title: '',
    amount: 0,
    subject: '',
    type: 'call',
    channel: 'email',
    source: 'manual',
    customer_id: '',
    crm_account_id: '',
  }
}

const partyOptions = computed(() => parties.value)

async function load() {
  error.value = ''
  loading.value = true
  try {
    overview.value = (await api.get<{ data: Overview }>('/crm/overview')).data
    stages.value = (await api.get<{ data: Stage[] }>('/crm/pipeline')).data
    parties.value = (await api.get<{ data: Party[] }>('/crm/parties')).data
    accounts.value = (await api.get<{ data: Account[] }>('/crm/accounts')).data
    leads.value = (await api.get<{ data: Lead[] }>('/crm/leads')).data
    activities.value = (await api.get<{ data: Activity[] }>('/crm/activities')).data
    campaigns.value = (await api.get<{ data: Campaign[] }>('/crm/campaigns')).data
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function openForm() {
  form.value = emptyForm()
  if (parties.value[0]) form.value.customer_id = parties.value[0].id
  if (accounts.value[0]) form.value.crm_account_id = accounts.value[0].id
  showForm.value = true
}

async function submit() {
  if (busy.value) return
  busy.value = true
  error.value = ''
  try {
    const current = form.value
    if (tab.value === 'accounts') {
      await api.post('/crm/accounts', { name: current.name.trim() })
    } else if (tab.value === 'prospects' || tab.value === 'clients' || tab.value === 'contacts') {
      await api.post('/crm/parties', {
        name: current.name.trim(),
        email: current.email.trim() || undefined,
        phone: current.phone.trim() || undefined,
        crm_role: tab.value === 'prospects' ? 'prospect' : 'client',
        crm_account_id: tab.value === 'contacts' ? current.crm_account_id || undefined : undefined,
      })
    } else if (tab.value === 'leads') {
      await api.post('/crm/leads', {
        name: current.name.trim(),
        email: current.email.trim() || undefined,
        phone: current.phone.trim() || undefined,
        source: current.source,
        crm_account_id: current.crm_account_id || undefined,
      })
    } else if (tab.value === 'pipeline') {
      await api.post('/crm/opportunities', {
        title: current.title.trim(),
        amount: Number(current.amount) || 0,
        customer_id: current.customer_id || undefined,
        crm_account_id: current.crm_account_id || undefined,
      })
    } else if (tab.value === 'activities') {
      await api.post('/crm/activities', {
        type: current.type,
        subject: current.subject.trim(),
        customer_id: current.customer_id || undefined,
        direction: current.type === 'note' || current.type === 'task' ? undefined : 'outbound',
      })
    } else if (tab.value === 'campaigns') {
      await api.post('/crm/campaigns', { name: current.name.trim(), channel: current.channel, status: 'active' })
    }
    showForm.value = false
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = false
  }
}

async function convert(lead: Lead) {
  busy.value = true
  error.value = ''
  try {
    await api.post(`/crm/leads/${lead.id}/convert`, { crm_role: 'client' })
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = false
  }
}

async function complete(activity: Activity) {
  busy.value = true
  try {
    await api.post(`/crm/activities/${activity.id}/complete`)
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = false
  }
}

async function openDossier(party: Party) {
  error.value = ''
  try {
    dossier.value = (await api.get<{ data: Dossier }>(`/crm/customers/${party.id}/dossier`)).data
    showDossier.value = true
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

const prospects = computed(() => parties.value.filter(party => party.crm_role === 'prospect'))
const clients = computed(() => parties.value.filter(party => party.crm_role !== 'prospect'))
const contacts = computed(() => parties.value.filter(party => party.account))

onMounted(() => { void load() })
</script>

<template>
  <PageFrame>
    <template #title>{{ t('crm.title') }}</template>
    <template #subtitle>{{ t('crm.subtitle') }}</template>

    <div class="crm">
      <div class="crm-kpis">
        <KpiCard :label="t('crm.tabs.prospects')" :value="overview?.prospects ?? 0" icon="customers" />
        <KpiCard :label="t('crm.tabs.clients')" :value="overview?.clients ?? 0" icon="customers" />
        <KpiCard :label="t('crm.tabs.leads')" :value="overview?.leads ?? 0" icon="mail" />
        <KpiCard :label="t('crm.tabs.pipeline')" :value="formatMoney(overview?.pipeline_amount ?? 0)" icon="coins" />
      </div>

      <nav class="sub-nav" :aria-label="t('crm.title')">
        <button
          v-for="item in tabs"
          :key="item"
          type="button"
          class="sub-nav__link"
          :class="{ 'sub-nav__link--active': tab === item }"
          @click="tab = item"
        >
          {{ t(`crm.tabs.${item}`) }}
        </button>
      </nav>

      <p v-if="error" class="crm-alert">{{ error }}</p>

      <div class="crm-toolbar">
        <button class="btn-primary" type="button" @click="openForm">{{ t('crm.create') }}</button>
      </div>

      <div v-if="tab === 'pipeline'" class="crm-board">
        <section v-for="stage in stages" :key="stage.id" class="crm-column">
          <header>
            <strong>{{ stage.name }}</strong>
            <Badge variant="neutral">{{ stage.opportunities?.length ?? 0 }}</Badge>
          </header>
          <article v-for="item in stage.opportunities ?? []" :key="item.id" class="crm-card">
            <p class="font-medium">{{ item.title }}</p>
            <p>{{ item.customer?.name || '—' }}</p>
            <p>{{ formatMoney(item.amount) }}</p>
          </article>
        </section>
      </div>

      <DataTableShell v-else-if="tab === 'prospects' || tab === 'clients' || tab === 'contacts'" :title="t(`crm.tabs.${tab}`)" :loading="loading" :empty="!(tab === 'prospects' ? prospects : tab === 'clients' ? clients : contacts).length" :empty-title="t('crm.empty')">
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('crm.name') }}</th>
              <th>{{ t('crm.email') }}</th>
              <th>{{ t('crm.phone') }}</th>
              <th>{{ t('crm.company') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="party in (tab === 'prospects' ? prospects : tab === 'clients' ? clients : contacts)" :key="party.id">
              <td class="font-medium">{{ party.name }}</td>
              <td>{{ party.email || '—' }}</td>
              <td>{{ party.phone || '—' }}</td>
              <td>{{ party.account?.name || '—' }}</td>
              <td class="text-right"><button class="btn-secondary" type="button" @click="openDossier(party)">{{ t('crm.dossier') }}</button></td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell v-else-if="tab === 'accounts'" :title="t('crm.tabs.accounts')" :loading="loading" :empty="!accounts.length" :empty-title="t('crm.empty')">
        <table class="ui-table min-w-full">
          <thead><tr><th>{{ t('crm.name') }}</th><th>{{ t('crm.email') }}</th><th>{{ t('crm.phone') }}</th></tr></thead>
          <tbody>
            <tr v-for="account in accounts" :key="account.id">
              <td class="font-medium">{{ account.name }}</td>
              <td>{{ account.email || '—' }}</td>
              <td>{{ account.phone || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell v-else-if="tab === 'leads'" :title="t('crm.tabs.leads')" :loading="loading" :empty="!leads.length" :empty-title="t('crm.empty')">
        <table class="ui-table min-w-full">
          <thead><tr><th>{{ t('crm.name') }}</th><th>{{ t('crm.source') }}</th><th>{{ t('crm.status') }}</th><th></th></tr></thead>
          <tbody>
            <tr v-for="lead in leads" :key="lead.id">
              <td class="font-medium">{{ lead.name }}</td>
              <td>{{ lead.source || '—' }}</td>
              <td><Badge :variant="lead.status === 'converted' ? 'success' : 'info'">{{ lead.status }}</Badge></td>
              <td class="text-right">
                <button v-if="lead.status !== 'converted'" class="btn-secondary" type="button" :disabled="busy" @click="convert(lead)">{{ t('crm.convert') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell v-else-if="tab === 'activities'" :title="t('crm.tabs.activities')" :loading="loading" :empty="!activities.length" :empty-title="t('crm.empty')">
        <table class="ui-table min-w-full">
          <thead><tr><th>{{ t('crm.type') }}</th><th>{{ t('crm.subject') }}</th><th>{{ t('crm.name') }}</th><th>{{ t('crm.status') }}</th><th></th></tr></thead>
          <tbody>
            <tr v-for="activity in activities" :key="activity.id">
              <td>{{ t(`crm.activityTypes.${activity.type}`) }}</td>
              <td class="font-medium">{{ activity.subject }}</td>
              <td>{{ activity.customer?.name || '—' }}</td>
              <td><Badge :variant="activity.status === 'done' ? 'success' : 'warning'">{{ activity.status }}</Badge></td>
              <td class="text-right">
                <button v-if="activity.status !== 'done'" class="btn-secondary" type="button" :disabled="busy" @click="complete(activity)">{{ t('crm.complete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>

      <DataTableShell v-else :title="t('crm.tabs.campaigns')" :loading="loading" :empty="!campaigns.length" :empty-title="t('crm.empty')">
        <table class="ui-table min-w-full">
          <thead><tr><th>{{ t('crm.name') }}</th><th>{{ t('crm.channel') }}</th><th>{{ t('crm.status') }}</th></tr></thead>
          <tbody>
            <tr v-for="campaign in campaigns" :key="campaign.id">
              <td class="font-medium">{{ campaign.name }}</td>
              <td>{{ campaign.channel }}</td>
              <td><Badge variant="info">{{ campaign.status }}</Badge></td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>
    </div>

    <AppModal :open="showForm" :title="t('crm.create')" icon="customers" @close="showForm = false">
      <form class="crm-form" @submit.prevent="submit">
        <div v-if="tab === 'pipeline'">
          <FieldLabel icon="tag">{{ t('crm.opportunity') }}</FieldLabel>
          <input v-model="form.title" class="field" required />
          <FieldLabel icon="coins">{{ t('crm.amount') }}</FieldLabel>
          <input v-model.number="form.amount" class="field" type="number" min="0" />
        </div>
        <div v-else-if="tab === 'activities'">
          <FieldLabel icon="layers">{{ t('crm.type') }}</FieldLabel>
          <select v-model="form.type" class="field">
            <option v-for="type in activityTypes" :key="type" :value="type">{{ t(`crm.activityTypes.${type}`) }}</option>
          </select>
          <FieldLabel icon="mail">{{ t('crm.subject') }}</FieldLabel>
          <input v-model="form.subject" class="field" required />
        </div>
        <div v-else-if="tab === 'campaigns'">
          <FieldLabel icon="tag">{{ t('crm.name') }}</FieldLabel>
          <input v-model="form.name" class="field" required />
          <FieldLabel icon="mail">{{ t('crm.channel') }}</FieldLabel>
          <select v-model="form.channel" class="field">
            <option value="email">email</option>
            <option value="sms">sms</option>
            <option value="pos">pos</option>
          </select>
        </div>
        <div v-else>
          <FieldLabel icon="customers">{{ t('crm.name') }}</FieldLabel>
          <input v-model="form.name" class="field" required />
          <FieldLabel icon="mail">{{ t('crm.email') }}</FieldLabel>
          <input v-model="form.email" class="field" type="email" />
          <FieldLabel icon="account">{{ t('crm.phone') }}</FieldLabel>
          <input v-model="form.phone" class="field" />
        </div>
        <div v-if="tab === 'pipeline' || tab === 'activities' || tab === 'leads' || tab === 'contacts'">
          <FieldLabel icon="customers">{{ t('crm.party') }}</FieldLabel>
          <select v-model="form.customer_id" class="field">
            <option value="">—</option>
            <option v-for="party in partyOptions" :key="party.id" :value="party.id">{{ party.name }}</option>
          </select>
          <FieldLabel icon="building">{{ t('crm.company') }}</FieldLabel>
          <select v-model="form.crm_account_id" class="field">
            <option value="">—</option>
            <option v-for="account in accounts" :key="account.id" :value="account.id">{{ account.name }}</option>
          </select>
        </div>
      </form>
      <template #footer>
        <button class="btn-secondary" type="button" @click="showForm = false">{{ t('crm.close') }}</button>
        <button class="btn-primary" type="button" :disabled="busy" @click="submit">{{ t('crm.create') }}</button>
      </template>
    </AppModal>

    <AppModal :open="showDossier" :title="dossier?.customer.name || t('crm.dossier')" icon="customers" @close="showDossier = false">
      <p class="crm-note">{{ t('crm.shared') }}</p>
      <ul v-if="dossier" class="crm-usage">
        <li v-for="(count, key) in dossier.usage" :key="key">
          <span>{{ t(`crm.usage.${key}`) }}</span>
          <strong>{{ key === 'loyalty' ? count : count }}</strong>
        </li>
      </ul>
      <p v-if="dossier">{{ t('crm.loyalty') }} : {{ dossier.loyalty.points }} · {{ dossier.loyalty.tier }}</p>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.crm { display: flex; flex-direction: column; gap: 1rem; min-width: 0; }
.crm-kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr)); gap: 0.75rem; }
.crm-toolbar { display: flex; justify-content: flex-end; }
.crm-alert { color: var(--color-danger, #b91c1c); }
.crm-board { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 0.75rem; }
.crm-column { display: flex; flex-direction: column; gap: 0.5rem; padding: 0.75rem; border: 1px solid var(--color-border, #e5e7eb); border-radius: 0.75rem; background: var(--color-surface, #fff); }
.crm-column header { display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; }
.crm-card { padding: 0.6rem; border-radius: 0.6rem; background: var(--color-surface-muted, #f8fafc); }
.crm-form { display: flex; flex-direction: column; gap: 0.75rem; }
.crm-usage { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; list-style: none; padding: 0; margin: 0 0 1rem; }
.crm-usage li { display: flex; justify-content: space-between; gap: 0.5rem; padding: 0.45rem 0.6rem; border-radius: 0.5rem; background: var(--color-surface-muted, #f8fafc); }
.crm-note { margin-top: 0; }
</style>
