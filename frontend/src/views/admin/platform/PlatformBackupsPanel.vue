<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import Badge from '../../../components/ui/Badge.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import { formatDateTime } from '../../../utils/format'

type Backup = {
  id: string
  type: string
  trigger: string
  status: string
  size_bytes: number
  checksum?: string | null
  includes?: { database?: boolean; files?: boolean } | null
  error_message?: string | null
  finished_at?: string | null
  verified_at?: string | null
  created_at?: string | null
}

type Policy = {
  auto_enabled: boolean
  schedule_time: string
  default_type: string
  retention: { daily: number; weekly: number; monthly: number }
  rpo_hours: number
  rto_minutes: number
  offsite_configured: boolean
}

type ChecklistItem = { key: string; ok: boolean; detail: string }

type DisasterRecovery = {
  ready: boolean
  rpo_hours: number
  rto_minutes: number
  age_hours: number | null
  within_rpo: boolean
  checklist: ChecklistItem[]
  runbook: string[]
}

type BadgeVariant = 'success' | 'neutral' | 'brand' | 'warning' | 'danger' | 'info'

const { t } = useI18n()
const backups = ref<Backup[]>([])
const policy = ref<Policy | null>(null)
const dr = ref<DisasterRecovery | null>(null)
const error = ref('')
const notice = ref('')
const loading = ref(false)
const busy = ref(false)
const backupType = ref<'full' | 'database' | 'files'>('full')

const form = ref({
  auto_enabled: true,
  schedule_time: '02:30',
  default_type: 'full',
  keep_daily: 7,
  keep_weekly: 4,
  keep_monthly: 6,
  rpo_hours: 36,
  rto_minutes: 120,
})

const readyLabel = computed(() => (dr.value?.ready ? t('platform.backups.drReady') : t('platform.backups.drNotReady')))

function bytes(value: number) {
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`
  return `${(value / (1024 * 1024)).toFixed(1)} MB`
}

function statusVariant(status?: string | null): BadgeVariant {
  if (status === 'completed') return 'success'
  if (status === 'running' || status === 'pending') return 'info'
  if (status === 'failed') return 'danger'
  return 'neutral'
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const response = await api.get<{
      data: Backup[]
      policy: Policy
      disaster_recovery: DisasterRecovery
    }>('/platform/backups')
    backups.value = response.data
    policy.value = response.policy
    dr.value = response.disaster_recovery
    form.value = {
      auto_enabled: response.policy.auto_enabled,
      schedule_time: response.policy.schedule_time,
      default_type: response.policy.default_type,
      keep_daily: response.policy.retention.daily,
      keep_weekly: response.policy.retention.weekly,
      keep_monthly: response.policy.retention.monthly,
      rpo_hours: response.policy.rpo_hours,
      rto_minutes: response.policy.rto_minutes,
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function run(action: () => Promise<void>, okMessage?: string) {
  if (busy.value) return
  busy.value = true
  error.value = ''
  notice.value = ''
  try {
    await action()
    if (okMessage) notice.value = okMessage
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = false
  }
}

function createBackup() {
  return run(async () => {
    await api.post('/platform/backups', { type: backupType.value })
  }, t('platform.backups.created'))
}

function verifyBackup(id: string) {
  return run(async () => {
    await api.post(`/platform/backups/${id}/verify`)
  }, t('platform.backups.verified'))
}

function dryRun(id: string) {
  return run(async () => {
    await api.post(`/platform/backups/${id}/restore`, {
      mode: 'dry_run',
      database: true,
      files: true,
    })
  }, t('platform.backups.drillDone'))
}

function liveRestore(id: string) {
  const ok = window.confirm(t('platform.backups.restoreConfirm'))
  if (!ok) return
  return run(async () => {
    await api.post(`/platform/backups/${id}/restore`, {
      mode: 'live',
      database: true,
      files: true,
      confirm: 'RESTORE',
    })
  }, t('platform.backups.restored'))
}

function removeBackup(id: string) {
  return run(async () => {
    await api.delete(`/platform/backups/${id}`)
  }, t('platform.backups.deleted'))
}

function prune() {
  return run(async () => {
    await api.post('/platform/backups/prune')
  }, t('platform.backups.pruned'))
}

function savePolicy() {
  return run(async () => {
    await api.patch('/platform/backups/policy', { ...form.value })
  }, t('platform.backups.policySaved'))
}

onMounted(load)
</script>

<template>
  <section class="backups">
    <header class="backups__header">
      <div>
        <h2>{{ t('platform.backups.title') }}</h2>
        <p>{{ t('platform.backups.hint') }}</p>
      </div>
      <div class="backups__actions">
        <select v-model="backupType" class="field" :disabled="busy">
          <option value="full">{{ t('platform.backups.types.full') }}</option>
          <option value="database">{{ t('platform.backups.types.database') }}</option>
          <option value="files">{{ t('platform.backups.types.files') }}</option>
        </select>
        <button class="btn-primary" type="button" :disabled="busy" @click="createBackup">{{ t('platform.backups.runNow') }}</button>
        <button class="btn-secondary" type="button" :disabled="busy" @click="prune">{{ t('platform.backups.prune') }}</button>
      </div>
    </header>

    <p v-if="error" class="backups__error" role="alert">{{ error }}</p>
    <p v-else-if="notice" class="backups__note">{{ notice }}</p>

    <div v-if="dr" class="backups__dr" :class="{ 'backups__dr--ready': dr.ready }">
      <div class="backups__dr-head">
        <h3>{{ t('platform.backups.disasterRecovery') }}</h3>
        <Badge :variant="dr.ready ? 'success' : 'warning'" dot>{{ readyLabel }}</Badge>
      </div>
      <p class="backups__muted">
        {{ t('platform.backups.rpo', { hours: dr.rpo_hours }) }}
        ·
        {{ t('platform.backups.rto', { minutes: dr.rto_minutes }) }}
        <template v-if="dr.age_hours !== null"> · {{ t('platform.backups.age', { hours: dr.age_hours }) }}</template>
      </p>
      <ul class="backups__checklist">
        <li v-for="item in dr.checklist" :key="item.key" :class="{ 'is-ok': item.ok }">
          <strong>{{ t(`platform.backups.checklist.${item.key}`) }}</strong>
          <span>{{ item.detail }}</span>
        </li>
      </ul>
      <ol class="backups__runbook">
        <li v-for="(step, index) in dr.runbook" :key="index">{{ step }}</li>
      </ol>
    </div>

    <form class="backups__policy" @submit.prevent="savePolicy">
      <h3>{{ t('platform.backups.policy') }}</h3>
      <div class="backups__policy-grid">
        <label class="backups__check">
          <input v-model="form.auto_enabled" type="checkbox" :disabled="busy" />
          {{ t('platform.backups.autoEnabled') }}
        </label>
        <label>{{ t('platform.backups.scheduleTime') }}<input v-model="form.schedule_time" class="field" type="time" :disabled="busy" required /></label>
        <label>
          {{ t('platform.backups.defaultType') }}
          <select v-model="form.default_type" class="field" :disabled="busy">
            <option value="full">{{ t('platform.backups.types.full') }}</option>
            <option value="database">{{ t('platform.backups.types.database') }}</option>
            <option value="files">{{ t('platform.backups.types.files') }}</option>
          </select>
        </label>
        <label>{{ t('platform.backups.keepDaily') }}<input v-model.number="form.keep_daily" class="field" type="number" min="1" max="90" :disabled="busy" required /></label>
        <label>{{ t('platform.backups.keepWeekly') }}<input v-model.number="form.keep_weekly" class="field" type="number" min="0" max="52" :disabled="busy" required /></label>
        <label>{{ t('platform.backups.keepMonthly') }}<input v-model.number="form.keep_monthly" class="field" type="number" min="0" max="36" :disabled="busy" required /></label>
        <label>{{ t('platform.backups.rpoHours') }}<input v-model.number="form.rpo_hours" class="field" type="number" min="1" max="720" :disabled="busy" required /></label>
        <label>{{ t('platform.backups.rtoMinutes') }}<input v-model.number="form.rto_minutes" class="field" type="number" min="15" max="10080" :disabled="busy" required /></label>
      </div>
      <button class="btn-primary" type="submit" :disabled="busy">{{ t('platform.backups.savePolicy') }}</button>
    </form>

    <DataTableShell
      :title="t('platform.backups.history')"
      :loading="loading"
      :empty="!loading && !backups.length"
      :empty-title="t('platform.empty')"
      empty-icon="layers"
      :loading-label="t('platform.loading')"
    >
      <table class="ui-table min-w-full">
        <thead>
          <tr>
            <th>{{ t('platform.when') }}</th>
            <th>{{ t('platform.backups.type') }}</th>
            <th>{{ t('platform.status') }}</th>
            <th>{{ t('platform.backups.size') }}</th>
            <th>{{ t('platform.backups.trigger') }}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in backups" :key="row.id">
            <td>{{ row.finished_at || row.created_at ? formatDateTime(row.finished_at || row.created_at || '') : '—' }}</td>
            <td><Badge variant="neutral">{{ t(`platform.backups.types.${row.type}`) }}</Badge></td>
            <td>
              <Badge :variant="statusVariant(row.status)" dot>{{ row.status }}</Badge>
              <span v-if="row.verified_at" class="backups__verified">{{ t('platform.backups.verifiedAt') }}</span>
            </td>
            <td>{{ bytes(row.size_bytes || 0) }}</td>
            <td>{{ row.trigger }}</td>
            <td class="backups__row-actions">
              <button v-if="row.status === 'completed'" class="btn-secondary" type="button" :disabled="busy" @click="verifyBackup(row.id)">{{ t('platform.backups.verify') }}</button>
              <button v-if="row.status === 'completed'" class="btn-secondary" type="button" :disabled="busy" @click="dryRun(row.id)">{{ t('platform.backups.drill') }}</button>
              <button v-if="row.status === 'completed'" class="btn-secondary" type="button" :disabled="busy" @click="liveRestore(row.id)">{{ t('platform.backups.restore') }}</button>
              <button class="btn-secondary" type="button" :disabled="busy" @click="removeBackup(row.id)">{{ t('common.delete') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </DataTableShell>
  </section>
</template>

<style scoped>
.backups { display: flex; flex-direction: column; gap: 1rem; }
.backups__header { display: flex; flex-wrap: wrap; gap: 0.75rem; justify-content: space-between; align-items: flex-end; }
.backups__header h2, .backups__policy h3, .backups__dr-head h3 { margin: 0; font-size: 1.05rem; }
.backups__header p, .backups__muted, .backups__note { margin: 0.25rem 0 0; color: var(--color-text-muted); font-size: 0.8rem; }
.backups__actions { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; }
.backups__error { margin: 0; color: var(--color-danger, #b91c1c); font-size: 0.85rem; }
.backups__dr, .backups__policy {
  padding: 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 0.85rem;
  background: var(--color-surface);
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}
.backups__dr--ready { border-color: color-mix(in srgb, var(--color-success, #15803d) 35%, var(--color-border)); }
.backups__dr-head { display: flex; justify-content: space-between; gap: 0.75rem; align-items: center; }
.backups__checklist { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.4rem; }
.backups__checklist li { display: grid; gap: 0.1rem; font-size: 0.8rem; padding: 0.45rem 0.55rem; border-radius: 0.55rem; background: var(--color-surface-muted, #f8fafc); }
.backups__checklist li.is-ok { background: color-mix(in srgb, var(--color-success, #15803d) 10%, transparent); }
.backups__checklist strong { font-size: 0.78rem; }
.backups__checklist span { color: var(--color-text-muted); }
.backups__runbook { margin: 0; padding-left: 1.1rem; color: var(--color-text-muted); font-size: 0.78rem; display: grid; gap: 0.25rem; }
.backups__policy-grid { display: grid; gap: 0.55rem; grid-template-columns: repeat(auto-fit, minmax(10rem, 1fr)); }
.backups__policy-grid label { display: flex; flex-direction: column; gap: 0.2rem; font-size: 0.72rem; font-weight: 650; color: var(--color-text-muted); }
.backups__check { flex-direction: row !important; align-items: center; gap: 0.45rem !important; }
.backups__row-actions { display: flex; flex-wrap: wrap; gap: 0.35rem; justify-content: flex-end; }
.backups__verified { display: block; margin-top: 0.2rem; font-size: 0.7rem; color: var(--color-text-muted); }
</style>
