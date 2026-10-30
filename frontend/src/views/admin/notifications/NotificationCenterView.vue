<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import Badge from '../../../components/ui/Badge.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { formatDateTime } from '../../../utils/format'
import AppIcon from '../../../components/ui/AppIcon.vue'

type InboxItem = {
  id: string
  event: string
  title: string
  body: string
  context?: { link?: string } | null
  read_at: string | null
  created_at: string
}

type Rule = { event: string; channels: string[]; customized: boolean }

type ChannelRow = {
  channel: string
  enabled: boolean
  configured: boolean
  locked: boolean
  config: Record<string, string | boolean>
}

type Delivery = {
  id: string
  event: string
  channel: string
  status: string
  recipient: string | null
  title: string
  error: string | null
  created_at: string
  user?: { name?: string } | null
}

type Draft = { enabled: boolean; config: Record<string, string>; secrets: Record<string, boolean> }

const events = ['new_order', 'payment', 'low_stock', 'reservation', 'unpaid_invoice', 'approval', 'anomaly', 'maintenance']
const channelOrder = ['application', 'email', 'sms', 'whatsapp', 'push']
const eventIcon: Record<string, string> = {
  new_order: 'receipt',
  payment: 'coins',
  low_stock: 'package',
  reservation: 'calendar',
  unpaid_invoice: 'alert',
  approval: 'check',
  anomaly: 'alert',
  maintenance: 'shift',
}
const channelIcon: Record<string, string> = {
  application: 'bell',
  email: 'mail',
  sms: 'phone',
  whatsapp: 'phone',
  push: 'device-tablet',
}
const tabIcon = { inbox: 'mail', rules: 'filter', channels: 'bell', journal: 'receipt' } as const
const fieldMap: Record<string, { key: string; label: string; secret?: boolean; type?: string }[]> = {
  email: [
    { key: 'from_name', label: 'fromName' },
    { key: 'from_address', label: 'fromAddress', type: 'email' },
  ],
  sms: [
    { key: 'endpoint', label: 'endpoint' },
    { key: 'sender', label: 'sender' },
    { key: 'api_key', label: 'apiKey', secret: true },
  ],
  whatsapp: [
    { key: 'phone_number_id', label: 'phoneNumberId' },
    { key: 'access_token', label: 'accessToken', secret: true },
  ],
  push: [
    { key: 'server_key', label: 'serverKey', secret: true },
  ],
}

const { t } = useI18n()
const router = useRouter()
const tab = ref<'inbox' | 'rules' | 'channels' | 'journal'>('inbox')
const canManage = ref(false)
const message = ref('')
const error = ref('')
const loading = ref(false)

const items = ref<InboxItem[]>([])
const unread = ref(0)
const page = ref(1)
const lastPage = ref(1)
const eventFilter = ref('')

const scope = ref<'user' | 'tenant'>('user')
const rules = ref<Rule[]>([])

const channels = ref<ChannelRow[]>([])
const drafts = ref<Record<string, Draft>>({})
const testEvent = ref('payment')
const pushToken = ref('')

const deliveries = ref<Delivery[]>([])
const deliveryChannel = ref('')
const journalPage = ref(1)
const journalLastPage = ref(1)

const tabs = computed(() => {
  const base: Array<'inbox' | 'rules' | 'channels' | 'journal'> = ['inbox', 'rules']
  if (canManage.value) base.push('channels', 'journal')
  return base
})

function labelEvent(event: string) {
  return t(`notifications.events.${event}`)
}

function labelChannel(channel: string) {
  return t(`notifications.channel.${channel}`)
}

function setMessage(text: string) {
  error.value = ''
  message.value = text
}

function setError(caught: unknown) {
  message.value = ''
  error.value = extractApiErrorMessage(caught)
}

async function loadInbox() {
  loading.value = true
  try {
    const params = new URLSearchParams({ per_page: '20', page: String(page.value) })
    if (eventFilter.value) params.set('event', eventFilter.value)
    const payload = await api.get<{ data: InboxItem[]; meta: { unread: number; last_page: number; can_manage: boolean } }>(
      `/notification-center?${params}`,
    )
    items.value = payload.data ?? []
    unread.value = payload.meta?.unread ?? 0
    lastPage.value = payload.meta?.last_page ?? 1
    canManage.value = Boolean(payload.meta?.can_manage)
  } catch (caught) {
    setError(caught)
  } finally {
    loading.value = false
  }
}

async function refreshInbox() {
  page.value = 1
  loading.value = true
  try {
    const params = new URLSearchParams({ per_page: '20', page: '1', refresh: '1' })
    if (eventFilter.value) params.set('event', eventFilter.value)
    const payload = await api.get<{ data: InboxItem[]; meta: { unread: number; last_page: number; can_manage: boolean } }>(
      `/notification-center?${params}`,
    )
    items.value = payload.data ?? []
    unread.value = payload.meta?.unread ?? 0
    lastPage.value = payload.meta?.last_page ?? 1
    canManage.value = Boolean(payload.meta?.can_manage)
  } catch (caught) {
    setError(caught)
  } finally {
    loading.value = false
  }
}

async function openItem(item: InboxItem) {
  if (!item.read_at) {
    try {
      await api.post(`/notification-center/${item.id}/read`)
      item.read_at = new Date().toISOString()
      unread.value = Math.max(0, unread.value - 1)
    } catch (caught) {
      setError(caught)
      return
    }
  }
  const link = item.context?.link
  if (link) void router.push(link)
}

async function markAll() {
  try {
    await api.post('/notification-center/read-all')
    items.value = items.value.map(item => ({ ...item, read_at: item.read_at ?? new Date().toISOString() }))
    unread.value = 0
  } catch (caught) {
    setError(caught)
  }
}

async function removeItem(item: InboxItem) {
  try {
    await api.delete(`/notification-center/${item.id}`)
    items.value = items.value.filter(row => row.id !== item.id)
    if (!item.read_at) unread.value = Math.max(0, unread.value - 1)
  } catch (caught) {
    setError(caught)
  }
}

async function loadRules() {
  loading.value = true
  try {
    const payload = await api.get<{ data: Rule[]; meta: { can_manage: boolean } }>(
      `/notification-center/preferences?scope=${scope.value}`,
    )
    rules.value = payload.data ?? []
    canManage.value = Boolean(payload.meta?.can_manage)
  } catch (caught) {
    setError(caught)
  } finally {
    loading.value = false
  }
}

function onToggle(rule: Rule, channel: string, event: Event) {
  const checked = event.target instanceof HTMLInputElement && event.target.checked
  rule.channels = checked
    ? [...new Set([...rule.channels, channel])]
    : rule.channels.filter(value => value !== channel)
}

async function saveRules() {
  try {
    const payload = await api.put<{ data: Rule[] }>('/notification-center/preferences', {
      scope: scope.value,
      rules: rules.value.map(rule => ({ event: rule.event, channels: rule.channels })),
    })
    rules.value = payload.data ?? rules.value
    setMessage(t('notifications.saved'))
  } catch (caught) {
    setError(caught)
  }
}

async function resetRules() {
  try {
    const payload = await api.put<{ data: Rule[] }>('/notification-center/preferences', {
      scope: 'user',
      reset: true,
      rules: [],
    })
    scope.value = 'user'
    rules.value = payload.data ?? []
    setMessage(t('notifications.saved'))
  } catch (caught) {
    setError(caught)
  }
}

function draftFrom(row: ChannelRow): Draft {
  const config: Record<string, string> = {}
  const secrets: Record<string, boolean> = {}
  for (const [key, value] of Object.entries(row.config ?? {})) {
    if (key.endsWith('_set')) secrets[key.slice(0, -4)] = Boolean(value)
    else config[key] = typeof value === 'string' ? value : ''
  }
  return { enabled: row.enabled, config, secrets }
}

async function loadChannels() {
  loading.value = true
  try {
    const payload = await api.get<{ data: ChannelRow[] }>('/notification-center/channels')
    channels.value = payload.data ?? []
    const next: Record<string, Draft> = {}
    for (const row of channels.value) next[row.channel] = draftFrom(row)
    drafts.value = next
  } catch (caught) {
    setError(caught)
  } finally {
    loading.value = false
  }
}

async function saveChannel(channel: string) {
  const draft = drafts.value[channel]
  if (!draft) return
  try {
    const payload = await api.put<{ data: ChannelRow }>(`/notification-center/channels/${channel}`, {
      enabled: draft.enabled,
      config: draft.config,
    })
    if (payload.data) drafts.value[channel] = draftFrom(payload.data)
    setMessage(t('notifications.saved'))
  } catch (caught) {
    setError(caught)
  }
}

async function sendTest(channel: string) {
  try {
    await api.post('/notification-center/test', { event: testEvent.value, channel })
    setMessage(t('notifications.testSent'))
    if (tab.value === 'journal') await loadJournal()
  } catch (caught) {
    setError(caught)
  }
}

async function registerToken() {
  if (!pushToken.value.trim()) return
  try {
    await api.post('/notification-center/push-tokens', { token: pushToken.value.trim(), platform: 'web' })
    pushToken.value = ''
    setMessage(t('notifications.tokenSaved'))
  } catch (caught) {
    setError(caught)
  }
}

async function loadJournal() {
  loading.value = true
  try {
    const params = new URLSearchParams({ per_page: '25', page: String(journalPage.value) })
    if (eventFilter.value) params.set('event', eventFilter.value)
    if (deliveryChannel.value) params.set('channel', deliveryChannel.value)
    const payload = await api.get<{ data: Delivery[]; meta: { last_page: number } }>(`/notification-center/deliveries?${params}`)
    deliveries.value = payload.data ?? []
    journalLastPage.value = payload.meta?.last_page ?? 1
  } catch (caught) {
    setError(caught)
  } finally {
    loading.value = false
  }
}

function show(next: typeof tab.value) {
  tab.value = next
  message.value = ''
  error.value = ''
  if (next === 'inbox') void loadInbox()
  if (next === 'rules') void loadRules()
  if (next === 'channels') void loadChannels()
  if (next === 'journal') void loadJournal()
}

function deliveryTone(status: string): 'success' | 'danger' | 'warning' | 'neutral' {
  if (status === 'sent') return 'success'
  if (status === 'failed') return 'danger'
  if (status === 'pending') return 'warning'
  return 'neutral'
}

function hint(channel: string) {
  const hints: Record<string, string> = {
    email: t('notifications.emailHint'),
    sms: t('notifications.smsHint'),
    whatsapp: t('notifications.whatsappHint'),
    push: t('notifications.pushHint'),
  }
  return hints[channel] ?? ''
}

watch(eventFilter, () => {
  page.value = 1
  journalPage.value = 1
  if (tab.value === 'inbox') void loadInbox()
  if (tab.value === 'journal') void loadJournal()
})

watch(scope, () => {
  if (tab.value === 'rules') void loadRules()
})

onMounted(() => {
  void loadInbox()
})
</script>

<template>
  <PageFrame>
    <template #title>{{ t('notifications.title') }}</template>
    <template #subtitle>{{ t('notifications.subtitle') }}</template>

    <div class="nc">
      <div class="nc-tabs" role="tablist">
        <button
          v-for="name in tabs"
          :key="name"
          type="button"
          class="nc-tab"
          :class="{ 'is-on': tab === name }"
          role="tab"
          :aria-selected="tab === name"
          @click="show(name)"
        >
          <AppIcon :name="tabIcon[name]" :size="15" />
          {{ t(`notifications.${name}`) }}
        </button>
      </div>

      <p v-if="message" class="nc-note nc-note--ok">{{ message }}</p>
      <p v-if="error" class="nc-note nc-note--bad">{{ error }}</p>
      <p v-if="loading" class="nc-note">{{ t('common.loading') }}</p>

      <section v-if="tab === 'inbox'" class="nc-panel">
        <div class="nc-kpis">
          <KpiCard :label="t('notifications.unread', { count: '' }).trim()" :value="unread" :count-to="unread" icon="bell" tone="amber" />
          <KpiCard :label="t('notifications.inbox')" :value="items.length" :count-to="items.length" icon="mail" tone="navy" />
        </div>

        <div class="nc-bar">
          <label>
            <FieldLabel icon="filter">{{ t('notifications.filterEvent') }}</FieldLabel>
            <select v-model="eventFilter" class="field">
              <option value="">{{ t('notifications.all') }}</option>
              <option v-for="event in events" :key="event" :value="event">{{ labelEvent(event) }}</option>
            </select>
          </label>
          <div class="nc-bar__actions">
            <button type="button" class="ui-btn ui-btn--secondary" @click="refreshInbox">
              <AppIcon name="refresh" :size="15" /> {{ t('notifications.refresh') }}
            </button>
            <button type="button" class="ui-btn ui-btn--primary" :disabled="!unread" @click="markAll">
              {{ t('notifications.markAll') }}
            </button>
          </div>
        </div>

        <EmptyState v-if="!items.length && !loading" icon="bell" :title="t('notifications.empty')" />
        <ul v-else class="nc-list">
          <li v-for="item in items" :key="item.id" class="nc-item" :class="{ 'is-new': !item.read_at }">
            <button type="button" class="nc-item__open" @click="openItem(item)">
              <span class="nc-item__icon" aria-hidden="true">
                <AppIcon :name="eventIcon[item.event] || 'bell'" :size="18" />
              </span>
              <span class="nc-item__copy">
                <span class="nc-item__event">{{ labelEvent(item.event) }}</span>
                <strong>{{ item.title }}</strong>
                <span>{{ item.body }}</span>
                <time>{{ formatDateTime(item.created_at) }}</time>
              </span>
            </button>
            <button type="button" class="ui-btn ui-btn--ghost" @click="removeItem(item)">
              <AppIcon name="trash" :size="15" /> {{ t('common.delete') }}
            </button>
          </li>
        </ul>

        <div v-if="lastPage > 1" class="nc-pager">
          <button type="button" class="ui-btn ui-btn--secondary" :disabled="page <= 1" @click="page -= 1; loadInbox()">{{ page }} / {{ lastPage }}</button>
          <button type="button" class="ui-btn ui-btn--secondary" :disabled="page >= lastPage" @click="page += 1; loadInbox()">→</button>
        </div>
      </section>

      <section v-else-if="tab === 'rules'" class="nc-panel">
        <div class="nc-bar">
          <label v-if="canManage">
            <FieldLabel icon="filter">{{ t('notifications.scopeMine') }}</FieldLabel>
            <select v-model="scope" class="field">
              <option value="user">{{ t('notifications.scopeMine') }}</option>
              <option value="tenant">{{ t('notifications.scopeTenant') }}</option>
            </select>
          </label>
          <div class="nc-bar__actions">
            <button type="button" class="ui-btn ui-btn--primary" @click="saveRules">
              <AppIcon name="check" :size="15" /> {{ t('notifications.save') }}
            </button>
            <button v-if="scope === 'user'" type="button" class="ui-btn ui-btn--secondary" @click="resetRules">{{ t('notifications.reset') }}</button>
          </div>
        </div>

        <div class="nc-table-wrap">
          <table>
            <thead>
              <tr>
                <th>{{ t('notifications.filterEvent') }}</th>
                <th v-for="channel in channelOrder" :key="channel">{{ labelChannel(channel) }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="rule in rules" :key="rule.event">
                <td>
                  <span class="nc-rule">
                    <AppIcon :name="eventIcon[rule.event] || 'bell'" :size="15" />
                    {{ labelEvent(rule.event) }}
                  </span>
                  <Badge v-if="rule.customized" variant="brand">{{ t('notifications.customized') }}</Badge>
                </td>
                <td v-for="channel in channelOrder" :key="channel" class="nc-check">
                  <input
                    type="checkbox"
                    :checked="rule.channels.includes(channel)"
                    :aria-label="`${labelEvent(rule.event)} ${labelChannel(channel)}`"
                    @change="onToggle(rule, channel, $event)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-else-if="tab === 'channels'" class="nc-panel">
        <div class="nc-channels">
          <article v-for="row in channels" :key="row.channel" class="nc-channel">
            <header>
              <span class="nc-item__icon" aria-hidden="true">
                <AppIcon :name="channelIcon[row.channel] || 'bell'" :size="18" />
              </span>
              <h3>{{ labelChannel(row.channel) }}</h3>
              <Badge :variant="row.configured ? 'success' : 'warning'" dot>
                {{ row.configured ? t('notifications.configured') : t('notifications.notConfigured') }}
              </Badge>
            </header>
            <p v-if="row.locked" class="nc-muted">{{ t('notifications.locked') }}</p>
            <template v-else-if="drafts[row.channel]">
              <p v-if="hint(row.channel)" class="nc-muted">{{ hint(row.channel) }}</p>
              <label class="nc-switch">
                <input v-model="drafts[row.channel].enabled" type="checkbox" />
                <span>{{ t('notifications.enabled') }}</span>
              </label>
              <div v-for="field in fieldMap[row.channel] ?? []" :key="field.key">
                <FieldLabel icon="tag">{{ t(`notifications.fields.${field.label}`) }}</FieldLabel>
                <input
                  v-model="drafts[row.channel].config[field.key]"
                  :type="field.secret ? 'password' : (field.type ?? 'text')"
                  class="field"
                  :placeholder="field.secret && drafts[row.channel].secrets[field.key] ? t('notifications.fields.secretKept') : ''"
                  autocomplete="off"
                />
              </div>
              <div v-if="row.channel === 'push'">
                <FieldLabel icon="key">{{ t('notifications.pushToken') }}</FieldLabel>
                <div class="nc-token">
                  <input v-model="pushToken" class="field" autocomplete="off" />
                  <button type="button" class="ui-btn ui-btn--secondary" @click="registerToken">{{ t('notifications.registerToken') }}</button>
                </div>
              </div>
              <div class="nc-bar__actions">
                <button type="button" class="ui-btn ui-btn--primary" @click="saveChannel(row.channel)">
                  <AppIcon name="check" :size="15" /> {{ t('notifications.save') }}
                </button>
                <button type="button" class="ui-btn ui-btn--secondary" @click="sendTest(row.channel)">{{ t('notifications.test') }}</button>
              </div>
            </template>
          </article>
        </div>
        <label class="nc-test">
          <FieldLabel icon="bell">{{ t('notifications.testEvent') }}</FieldLabel>
          <select v-model="testEvent" class="field">
            <option v-for="event in events" :key="event" :value="event">{{ labelEvent(event) }}</option>
          </select>
        </label>
      </section>

      <section v-else class="nc-panel">
        <div class="nc-bar">
          <label>
            <FieldLabel icon="filter">{{ t('notifications.filterEvent') }}</FieldLabel>
            <select v-model="eventFilter" class="field">
              <option value="">{{ t('notifications.all') }}</option>
              <option v-for="event in events" :key="event" :value="event">{{ labelEvent(event) }}</option>
            </select>
          </label>
          <label>
            <FieldLabel icon="filter">{{ t('notifications.filterChannel') }}</FieldLabel>
            <select v-model="deliveryChannel" class="field" @change="journalPage = 1; loadJournal()">
              <option value="">{{ t('notifications.all') }}</option>
              <option v-for="channel in channelOrder" :key="channel" :value="channel">{{ labelChannel(channel) }}</option>
            </select>
          </label>
        </div>
        <EmptyState v-if="!deliveries.length && !loading" icon="receipt" :title="t('notifications.empty')" />
        <div v-else class="nc-table-wrap">
          <table>
            <thead>
              <tr>
                <th>{{ t('notifications.when') }}</th>
                <th>{{ t('notifications.filterEvent') }}</th>
                <th>{{ t('notifications.filterChannel') }}</th>
                <th>{{ t('notifications.recipient') }}</th>
                <th>{{ t('notifications.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in deliveries" :key="row.id">
                <td>{{ formatDateTime(row.created_at) }}</td>
                <td>{{ labelEvent(row.event) }}</td>
                <td>{{ labelChannel(row.channel) }}</td>
                <td>{{ row.user?.name || row.recipient || '—' }}</td>
                <td>
                  <Badge :variant="deliveryTone(row.status)" dot>{{ t(`notifications.delivery.${row.status}`) }}</Badge>
                  <span v-if="row.error" class="nc-error">{{ row.error }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.nc {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  align-self: stretch;
  width: 100%;
  min-width: 0;
}

.nc-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}
.nc-tab {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border: 1px solid var(--color-border);
  background: #fff;
  color: var(--color-text-primary);
  border-radius: 999px;
  padding: 0.4rem 0.85rem;
  font: inherit;
  font-size: 0.85rem;
  font-weight: 650;
  cursor: pointer;
}
.nc-tab.is-on {
  background: #12243c;
  border-color: #12243c;
  color: #fff;
}

.nc-note {
  margin: 0;
  padding: 0.75rem 0.9rem;
  border-radius: 12px;
  background: var(--color-info-bg, #eef4ff);
  color: var(--color-text-primary);
}
.nc-note--ok { background: var(--color-success-bg, #eaf7ee); }
.nc-note--bad { background: var(--color-danger-bg, #fdecec); }

.nc-panel { display: flex; flex-direction: column; gap: 0.85rem; min-width: 0; }

.nc-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 14rem), 1fr));
  gap: 0.85rem;
  max-width: 42rem;
}
.nc-kpis :deep(.kpi-card__label) {
  text-transform: capitalize;
}

.nc-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: flex-start;
  gap: 0.75rem 1rem;
  padding: 0.9rem 1rem;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -22px rgba(15, 23, 42, 0.2);
}
.nc-bar__actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }

.nc-list {
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 20rem), 1fr));
  gap: 0.85rem;
  margin: 0;
  padding: 0;
  list-style: none;
}
.nc-item {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.9rem 1rem;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -20px rgba(15, 23, 42, 0.18);
}
.nc-item.is-new { box-shadow: inset 3px 0 0 #e39b2b, 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -20px rgba(15, 23, 42, 0.18); }
.nc-item__open {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  min-width: 0;
  flex: 1;
  padding: 0;
  border: 0;
  background: transparent;
  text-align: left;
  cursor: pointer;
  color: inherit;
  font: inherit;
}
.nc-item__icon {
  display: grid;
  place-items: center;
  flex: none;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: #12243c;
  color: #fff;
.nc-item > .ui-btn { align-self: flex-end; }
.nc-item__copy { display: grid; gap: 0.15rem; min-width: 0; overflow-wrap: anywhere; }
.nc-item__copy { display: grid; gap: 0.15rem; min-width: 0; }
.nc-item__event {
  color: #9a6412;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.nc-item__copy strong {
  color: var(--color-text-primary);
  font-size: 0.98rem;
  font-weight: 650;
}
.nc-item__copy span,
.nc-item__copy time {
  color: var(--color-text-muted);
  font-size: 0.85rem;
}
.nc-pager { display: flex; gap: 0.45rem; }

.nc-table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -20px rgba(15, 23, 42, 0.18);
}
.nc-rule { display: inline-flex; align-items: center; gap: 0.4rem; font-weight: 650; }
.nc-check { text-align: center; }
.nc-check input { width: 1.05rem; height: 1.05rem; accent-color: #12243c; }
.nc-error { display: block; margin-top: 0.25rem; color: var(--color-danger, #b42318); font-size: 0.78rem; }

.nc-channels {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 22rem), 1fr));
  gap: 0.85rem;
}
.nc-channel {
  display: grid;
  gap: 0.7rem;
  padding: 1rem;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -20px rgba(15, 23, 42, 0.18);
}
.nc-channel header {
  display: flex;
  align-items: center;
  gap: 0.7rem;
}
.nc-channel h3 { margin: 0; flex: 1; font-size: 1.02rem; font-weight: 650; }
.nc-channel .field { width: 100%; }
.nc-muted { margin: 0; color: var(--color-text-muted); font-size: 0.85rem; }
.nc-switch { display: flex; align-items: center; gap: 0.45rem; font-size: 0.9rem; font-weight: 600; }
.nc-token { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.nc-token .field { flex: 1; min-width: 10rem; }
.nc-test { display: grid; gap: 0.35rem; max-width: 22rem; }
}
</style>
