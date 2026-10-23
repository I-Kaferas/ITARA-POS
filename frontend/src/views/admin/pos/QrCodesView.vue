<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage, getStoreId, getTenantId, getToken } from '../../../api/client'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import { useContextStore } from '../../../stores/context'

type Row = {
  table_id: string
  name: string
  code?: string
  status: string
  zone?: string | null
  token_id?: string | null
  active: boolean
  order_url?: string | null
}

type Filter = 'all' | 'active' | 'off' | 'missing'

const { t } = useI18n()
const context = useContextStore()
const storeId = computed(() => context.currentStoreId)
const rows = ref<Row[]>([])
const mode = ref<'manual' | 'automatic'>('manual')
const error = ref('')
const notice = ref('')
const loading = ref(false)
const query = ref('')
const filter = ref<Filter>('all')
const busyId = ref('')
const preview = ref<{ name: string; zone: string; svg: string; url: string } | null>(null)

const readyCount = computed(() => rows.value.filter(row => row.active).length)
const missingCount = computed(() => rows.value.filter(row => !row.token_id).length)
const offCount = computed(() => rows.value.filter(row => row.token_id && !row.active).length)

const visible = computed(() => {
  const q = query.value.trim().toLowerCase()
  return rows.value.filter(row => {
    if (filter.value === 'active' && !row.active) return false
    if (filter.value === 'off' && !(row.token_id && !row.active)) return false
    if (filter.value === 'missing' && row.token_id) return false
    if (!q) return true
    return [row.name, row.code, row.zone].some(value => (value || '').toLowerCase().includes(q))
  })
})

const groups = computed(() => {
  const map = new Map<string, Row[]>()
  for (const row of visible.value) {
    const zone = row.zone || t('qr.noZone')
    map.set(zone, [...(map.get(zone) ?? []), row])
  }
  return [...map.entries()].map(([zone, tables]) => ({ zone, tables }))
})

function stateOf(row: Row): 'on' | 'off' | 'none' {
  if (!row.token_id) return 'none'
  return row.active ? 'on' : 'off'
}

async function load() {
  if (!storeId.value) return
  loading.value = rows.value.length === 0
  error.value = ''
  try {
    const res = await api.get<{ data: { approval_mode: string; tables: Row[] } }>(`/stores/${storeId.value}/qr-tokens`)
    rows.value = res.data.tables
    mode.value = res.data.approval_mode === 'automatic' ? 'automatic' : 'manual'
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function run(id: string, action: () => Promise<void>) {
  if (busyId.value) return
  busyId.value = id
  error.value = ''
  notice.value = ''
  try {
    await action()
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busyId.value = ''
  }
}

function issue(row: Row, rotate = false) {
  if (!storeId.value) return
  return run(row.table_id, () => api.post(`/stores/${storeId.value}/pos-tables/${row.table_id}/qr-token${rotate ? '/rotate' : ''}`, {}))
}

function toggle(row: Row) {
  if (!row.token_id) return
  return run(row.table_id, () => api.patch(`/qr-tokens/${row.token_id}`, { active: !row.active }))
}

async function openPrint(row: Row) {
  if (!row.token_id || !row.order_url) return
  busyId.value = row.table_id
  error.value = ''
  try {
    const headers = new Headers({ Accept: 'image/svg+xml' })
    const token = getToken()
    const tenant = getTenantId()
    const store = getStoreId()
    if (token) headers.set('Authorization', `Bearer ${token}`)
    if (tenant) headers.set('X-Tenant-ID', tenant)
    if (store) headers.set('X-Store-ID', store)
    const response = await fetch(`${import.meta.env.VITE_API_BASE_URL ?? '/api/v1'}/qr-tokens/${row.token_id}/svg`, { headers })
    if (!response.ok) throw new Error(t('qr.view'))
    preview.value = {
      name: row.name,
      zone: row.zone || t('qr.noZone'),
      svg: await response.text(),
      url: row.order_url,
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busyId.value = ''
  }
}

function printSheet() {
  if (!preview.value) return
  const popup = window.open('', '_blank', 'noopener,width=720,height=900')
  if (!popup) return
  const name = preview.value.name.replace(/[<>&]/g, '')
  popup.document.write(`<!doctype html><meta charset="utf-8"><title>${name}</title><style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #fff; color: #12243c; font-family: "IBM Plex Sans", sans-serif; }
    article { width: 320px; text-align: center; border: 1px solid #e3e7eb; border-radius: 12px; padding: 28px 24px 32px; }
    p { margin: 0; letter-spacing: 0.08em; text-transform: uppercase; font-size: 12px; color: #465467; }
    h1 { margin: 8px 0 4px; font-family: "Plus Jakarta Sans", sans-serif; font-size: 32px; }
    small { color: #465467; }
    .rule { height: 3px; width: 48px; margin: 16px auto; background: #e39b2b; }
    svg { width: 240px; height: 240px; }
  </style><article><p>${preview.value.zone}</p><h1>${name}</h1><div class="rule"></div>${preview.value.svg}<small>${t('qr.scanHint')}</small></article>`)
  popup.document.close()
  popup.focus()
  popup.print()
}

function downloadSvg() {
  if (!preview.value) return
  const blob = new Blob([preview.value.svg], { type: 'image/svg+xml' })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = `${preview.value.name}.svg`
  link.click()
  URL.revokeObjectURL(link.href)
}

async function copyLink() {
  if (!preview.value) return
  await navigator.clipboard.writeText(preview.value.url)
  notice.value = t('qr.copied')
}

async function saveMode(next: 'manual' | 'automatic') {
  if (!storeId.value || mode.value === next) return
  const previous = mode.value
  mode.value = next
  try {
    await api.patch(`/stores/${storeId.value}/qr-settings`, { mode: next })
  } catch (err) {
    mode.value = previous
    error.value = extractApiErrorMessage(err)
  }
}

onMounted(load)
watch(storeId, load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posQrCodes') }}</template>
    <template #subtitle>{{ t('qr.codesHint') }}</template>

    <p v-if="error" class="qr-note qr-note--bad">{{ error }}</p>
    <p v-else-if="notice" class="qr-note qr-note--ok">{{ notice }}</p>

    <section class="qr-stats" aria-label="QR">
      <article class="stat-card">
        <p class="stat-card__label">{{ t('qr.tablesCount') }}</p>
        <p class="stat-card__value">{{ rows.length }}</p>
      </article>
      <article class="stat-card">
        <p class="stat-card__label">{{ t('qr.activeCount') }}</p>
        <p class="stat-card__value">{{ readyCount }}</p>
      </article>
      <article class="stat-card">
        <p class="stat-card__label">{{ t('qr.missingCount') }}</p>
        <p class="stat-card__value">{{ missingCount }}</p>
      </article>
      <article class="stat-card">
        <p class="stat-card__label">{{ t('qr.inactive') }}</p>
        <p class="stat-card__value">{{ offCount }}</p>
      </article>
    </section>

    <section class="qr-toolbar ui-card">
      <label class="qr-search">
        <AppIcon name="search" :size="16" />
        <input v-model="query" type="search" class="ui-input" :placeholder="t('qr.search')">
      </label>
      <div class="qr-chips" role="tablist">
        <button type="button" class="qr-chip" :class="{ 'qr-chip--on': filter === 'all' }" @click="filter = 'all'">{{ t('qr.filterAll') }}</button>
        <button type="button" class="qr-chip" :class="{ 'qr-chip--on': filter === 'active' }" @click="filter = 'active'">{{ t('qr.filterActive') }}</button>
        <button type="button" class="qr-chip" :class="{ 'qr-chip--on': filter === 'off' }" @click="filter = 'off'">{{ t('qr.filterOff') }}</button>
        <button type="button" class="qr-chip" :class="{ 'qr-chip--on': filter === 'missing' }" @click="filter = 'missing'">{{ t('qr.filterMissing') }}</button>
      </div>
      <div class="qr-mode">
        <span>{{ t('qr.approval') }}</span>
        <div class="qr-chips">
          <button type="button" class="qr-chip" :class="{ 'qr-chip--on': mode === 'manual' }" @click="saveMode('manual')">{{ t('qr.manual') }}</button>
          <button type="button" class="qr-chip" :class="{ 'qr-chip--on': mode === 'automatic' }" @click="saveMode('automatic')">{{ t('qr.automatic') }}</button>
        </div>
        <p>{{ t('qr.approvalHint') }}</p>
      </div>
    </section>

    <p v-if="loading" class="qr-note">{{ t('common.loading') }}</p>
    <EmptyState v-else-if="!rows.length" icon="tables" :title="t('qr.noTables')" :description="t('qr.noTablesHint')" />
    <EmptyState v-else-if="!groups.length" icon="search" :title="t('qr.noMatch')" />

    <section v-for="group in groups" :key="group.zone" class="qr-zone">
      <header>
        <h2>{{ group.zone }}</h2>
        <span>{{ group.tables.length }}</span>
      </header>
      <div class="qr-grid">
        <article v-for="row in group.tables" :key="row.table_id" class="qr-tile" :class="`qr-tile--${stateOf(row)}`">
          <header>
            <div>
              <h3>{{ row.name }}</h3>
              <p>{{ row.code || row.status }}</p>
            </div>
            <Badge :variant="stateOf(row) === 'on' ? 'success' : stateOf(row) === 'off' ? 'warning' : 'neutral'" dot>
              {{ stateOf(row) === 'on' ? t('qr.active') : stateOf(row) === 'off' ? t('qr.inactive') : t('qr.filterMissing') }}
            </Badge>
          </header>
          <div class="qr-tile__actions">
            <button
              v-if="row.active && row.token_id"
              type="button"
              class="ui-btn ui-btn--primary"
              :disabled="busyId === row.table_id"
              @click="openPrint(row)"
            >
              {{ t('qr.view') }}
            </button>
            <button
              v-else
              type="button"
              class="ui-btn ui-btn--primary"
              :disabled="busyId === row.table_id"
              @click="row.token_id ? toggle(row) : issue(row)"
            >
              {{ row.token_id ? t('qr.enable') : t('qr.generate') }}
            </button>
            <button
              v-if="row.token_id"
              type="button"
              class="ui-btn ui-btn--secondary"
              :disabled="busyId === row.table_id"
              @click="issue(row, true)"
            >
              {{ t('qr.rotate') }}
            </button>
            <button
              v-if="row.active"
              type="button"
              class="ui-btn ui-btn--ghost"
              :disabled="busyId === row.table_id"
              @click="toggle(row)"
            >
              {{ t('qr.disable') }}
            </button>
          </div>
        </article>
      </div>
    </section>

    <AppModal
      :open="preview !== null"
      :title="preview?.name || ''"
      :subtitle="preview?.zone"
      icon="tables"
      size="sm"
      presentation="dialog"
      @close="preview = null"
    >
      <div v-if="preview" class="qr-sheet">
        <div class="qr-sheet__mark" v-html="preview.svg" />
        <p>{{ t('qr.scanHint') }}</p>
      </div>
      <template #footer>
        <button type="button" class="ui-btn ui-btn--secondary" @click="copyLink">{{ t('qr.copy') }}</button>
        <button type="button" class="ui-btn ui-btn--secondary" @click="downloadSvg">{{ t('qr.download') }}</button>
        <button type="button" class="ui-btn ui-btn--primary" @click="printSheet">{{ t('qr.print') }}</button>
      </template>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.qr-note {
  margin: 0 0 var(--space-4);
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-md);
  background: var(--color-info-bg);
  color: var(--color-text-primary);
}
.qr-note--bad { background: var(--color-danger-bg); }
.qr-note--ok { background: var(--color-success-bg); }

.qr-stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-3);
  margin-bottom: var(--space-4);
}
.qr-stats .stat-card__label { margin: 0 0 var(--space-2); }
.qr-stats .stat-card__value { margin: 0; }

.qr-toolbar {
  display: grid;
  gap: var(--space-4);
  padding: var(--space-4);
  margin-bottom: var(--space-6);
}
.qr-search {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  color: var(--color-text-muted, #5c6b78);
}
.qr-search .ui-input { flex: 1; }
.qr-chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
.qr-chip {
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-primary);
  border-radius: 999px;
  padding: 6px 12px;
  font: inherit;
  font-size: var(--text-sm);
}
.qr-chip--on {
  background: var(--color-brand-600);
  border-color: var(--color-brand-600);
  color: #fff;
}
.qr-mode {
  display: grid;
  gap: var(--space-2);
}
.qr-mode span { font-weight: 600; }
.qr-mode p { margin: 0; color: var(--color-text-secondary, #465467); font-size: var(--text-sm); }

.qr-zone { margin-top: var(--space-6); }
.qr-zone header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: var(--space-3);
}
.qr-zone h2 { margin: 0; font-size: var(--text-lg); }
.qr-zone header span { color: var(--color-text-secondary, #465467); font-variant-numeric: tabular-nums; }

.qr-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(16.5rem, 1fr));
  gap: var(--space-3);
}
.qr-tile {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  padding: var(--space-4);
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-top: 3px solid var(--color-brand-300);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
}
.qr-tile--on { border-top-color: var(--color-success); }
.qr-tile--off { border-top-color: var(--color-warning); }
.qr-tile header { display: flex; justify-content: space-between; gap: var(--space-3); align-items: flex-start; }
.qr-tile h3 { margin: 0; font-size: var(--text-xl); }
.qr-tile p { margin: var(--space-1) 0 0; color: var(--color-text-secondary, #465467); font-size: var(--text-sm); }
.qr-tile__actions { display: flex; flex-wrap: wrap; gap: var(--space-2); margin-top: auto; }

.qr-sheet { display: grid; justify-items: center; gap: var(--space-3); text-align: center; }
.qr-sheet p { margin: 0; color: var(--color-text-secondary, #465467); }
.qr-sheet__mark {
  background: #fff;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
}
.qr-sheet__mark :deep(svg) { display: block; width: 240px; height: 240px; }

@media (max-width: 800px) {
  .qr-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
</style>
