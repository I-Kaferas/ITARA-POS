<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { formatDateTime } from '../../../utils/format'

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

    <div class="mb-4 flex flex-wrap gap-2">
      <button
        v-for="name in tabs"
        :key="name"
        type="button"
        :class="tab === name ? 'btn-primary' : 'btn-secondary'"
        @click="show(name)"
      >
        {{ t(`notifications.${name}`) }}
      </button>
    </div>

    <p v-if="message" class="mb-3 text-sm text-emerald-700">{{ message }}</p>
    <p v-if="error" class="mb-3 text-sm text-red-700">{{ error }}</p>

    <section v-if="tab === 'inbox'">
      <div class="mb-4 flex flex-wrap items-end gap-3">
        <div>
          <FieldLabel icon="filter">{{ t('notifications.filterEvent') }}</FieldLabel>
          <select v-model="eventFilter" class="field">
            <option value="">{{ t('notifications.all') }}</option>
            <option v-for="event in events" :key="event" :value="event">{{ labelEvent(event) }}</option>
          </select>
        </div>
        <button type="button" class="btn-secondary" @click="refreshInbox">{{ t('notifications.refresh') }}</button>
        <button type="button" class="btn-secondary" :disabled="!unread" @click="markAll">
          {{ t('notifications.markAll') }}
        </button>
        <p class="pb-2 text-sm text-slate-500">{{ t('notifications.unread', { count: unread }) }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <ul class="divide-y">
          <li v-for="item in items" :key="item.id" class="flex items-start gap-3 px-4 py-3" :class="{ 'bg-slate-50': !item.read_at }">
            <button type="button" class="min-w-0 flex-1 text-left" @click="openItem(item)">
              <span class="text-xs font-semibold uppercase tracking-wide text-slate-500">{{ labelEvent(item.event) }}</span>
              <span class="mt-1 block font-medium text-slate-900">{{ item.title }}</span>
              <span class="mt-1 block text-sm text-slate-600">{{ item.body }}</span>
              <span class="mt-1 block text-xs text-slate-400">{{ formatDateTime(item.created_at) }}</span>
            </button>
            <button type="button" class="btn-secondary" @click="removeItem(item)">{{ t('common.delete') }}</button>
          </li>
        </ul>
        <p v-if="!items.length && !loading" class="px-4 py-8 text-center text-slate-500">{{ t('notifications.empty') }}</p>
      </div>

      <div v-if="lastPage > 1" class="mt-3 flex gap-2">
        <button type="button" class="btn-secondary" :disabled="page <= 1" @click="page -= 1; loadInbox()">{{ page }} / {{ lastPage }}</button>
        <button type="button" class="btn-secondary" :disabled="page >= lastPage" @click="page += 1; loadInbox()">→</button>
      </div>
    </section>

    <section v-else-if="tab === 'rules'">
      <div class="mb-4 flex flex-wrap items-end gap-3">
        <div v-if="canManage">
          <FieldLabel icon="filter">{{ t('notifications.scopeMine') }}</FieldLabel>
          <select v-model="scope" class="field">
            <option value="user">{{ t('notifications.scopeMine') }}</option>
            <option value="tenant">{{ t('notifications.scopeTenant') }}</option>
          </select>
        </div>
        <button type="button" class="btn-primary" @click="saveRules">{{ t('notifications.save') }}</button>
        <button v-if="scope === 'user'" type="button" class="btn-secondary" @click="resetRules">{{ t('notifications.reset') }}</button>
      </div>

      <div class="overflow-x-auto rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('notifications.filterEvent') }}</th>
              <th v-for="channel in channelOrder" :key="channel" class="px-3 py-3 text-center font-medium">{{ labelChannel(channel) }}</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-for="rule in rules" :key="rule.event">
              <td class="px-4 py-3">
                {{ labelEvent(rule.event) }}
                <span v-if="rule.customized" class="ml-2 text-xs text-slate-400">{{ t('notifications.customized') }}</span>
              </td>
              <td v-for="channel in channelOrder" :key="channel" class="px-3 py-3 text-center">
                <input
                  type="checkbox"
                  :checked="rule.channels.includes(channel)"
                  @change="onToggle(rule, channel, $event)"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section v-else-if="tab === 'channels'" class="grid gap-4 lg:grid-cols-2">
      <article v-for="row in channels" :key="row.channel" class="rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200">
        <div class="mb-2 flex items-center justify-between gap-3">
          <h3 class="text-base font-semibold">{{ labelChannel(row.channel) }}</h3>
          <span class="text-xs" :class="row.configured ? 'text-emerald-700' : 'text-amber-700'">
            {{ row.configured ? t('notifications.configured') : t('notifications.notConfigured') }}
          </span>
        </div>
        <p v-if="row.locked" class="text-sm text-slate-500">{{ t('notifications.locked') }}</p>
        <template v-else-if="drafts[row.channel]">
          <p class="mb-3 text-sm text-slate-500">{{ hint(row.channel) }}</p>
          <label class="mb-3 flex items-center gap-2 text-sm">
            <input v-model="drafts[row.channel].enabled" type="checkbox" />
            <span>{{ t('notifications.enabled') }}</span>
          </label>
          <div v-for="field in fieldMap[row.channel] ?? []" :key="field.key" class="mb-3">
            <FieldLabel icon="tag">{{ t(`notifications.fields.${field.label}`) }}</FieldLabel>
            <input
              v-model="drafts[row.channel].config[field.key]"
              :type="field.secret ? 'password' : (field.type ?? 'text')"
              class="field w-full"
              :placeholder="field.secret && drafts[row.channel].secrets[field.key] ? t('notifications.fields.secretKept') : ''"
              autocomplete="off"
            />
          </div>
          <div v-if="row.channel === 'push'" class="mb-3">
            <FieldLabel icon="key">{{ t('notifications.pushToken') }}</FieldLabel>
            <div class="flex gap-2">
              <input v-model="pushToken" class="field min-w-0 flex-1" autocomplete="off" />
              <button type="button" class="btn-secondary" @click="registerToken">{{ t('notifications.registerToken') }}</button>
            </div>
          </div>
          <div class="flex flex-wrap gap-2">
            <button type="button" class="btn-primary" @click="saveChannel(row.channel)">{{ t('notifications.save') }}</button>
            <button type="button" class="btn-secondary" @click="sendTest(row.channel)">{{ t('notifications.test') }}</button>
          </div>
        </template>
      </article>
      <div class="lg:col-span-2">
        <FieldLabel icon="bell">{{ t('notifications.testEvent') }}</FieldLabel>
        <select v-model="testEvent" class="field">
          <option v-for="event in events" :key="event" :value="event">{{ labelEvent(event) }}</option>
        </select>
      </div>
    </section>

    <section v-else>
      <div class="mb-4 flex flex-wrap items-end gap-3">
        <div>
          <FieldLabel icon="filter">{{ t('notifications.filterEvent') }}</FieldLabel>
          <select v-model="eventFilter" class="field">
            <option value="">{{ t('notifications.all') }}</option>
            <option v-for="event in events" :key="event" :value="event">{{ labelEvent(event) }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="filter">{{ t('notifications.filterChannel') }}</FieldLabel>
          <select v-model="deliveryChannel" class="field" @change="journalPage = 1; loadJournal()">
            <option value="">{{ t('notifications.all') }}</option>
            <option v-for="channel in channelOrder" :key="channel" :value="channel">{{ labelChannel(channel) }}</option>
          </select>
        </div>
      </div>
      <div class="overflow-x-auto rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('notifications.when') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('notifications.filterEvent') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('notifications.filterChannel') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('notifications.recipient') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('notifications.status') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-for="row in deliveries" :key="row.id">
              <td class="px-4 py-3 text-slate-500">{{ formatDateTime(row.created_at) }}</td>
              <td class="px-4 py-3">{{ labelEvent(row.event) }}</td>
              <td class="px-4 py-3">{{ labelChannel(row.channel) }}</td>
              <td class="px-4 py-3">{{ row.user?.name || row.recipient || '—' }}</td>
              <td class="px-4 py-3">
                {{ t(`notifications.delivery.${row.status}`) }}
                <span v-if="row.error" class="mt-1 block text-xs text-red-700">{{ row.error }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!deliveries.length && !loading" class="px-4 py-8 text-center text-slate-500">{{ t('notifications.empty') }}</p>
      </div>
    </section>
  </PageFrame>
</template>
