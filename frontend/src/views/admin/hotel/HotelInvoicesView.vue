<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath } from '../../../api/hospitality'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'
import { useContextStore } from '../../../stores/context'
import { formatDate } from '../../../utils/format'
import { findHotelSettings } from '../../../utils/hotelSettings'
import { formatMoney } from '../../../utils/money'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type Line = {
  id?: string
  kind?: string
  description?: string
  amount?: number
  created_at?: string
}
type InvoiceRow = {
  id: string
  reference: string
  guest: string
  room: string
  arrive: string
  depart: string
  status: string
  currency: string
  charges: number
  paid: number
  balance: number
  lines: Line[]
}

const { t } = useI18n()
const ctx = useContextStore()
const docs = ref<Doc[]>([])
const loading = ref(false)
const error = ref('')
const query = ref('')
const statusFilter = ref<'all' | 'open' | 'closed'>('all')
const selected = ref<InvoiceRow | null>(null)

const settings = computed(() => findHotelSettings(docs.value))
const reservations = computed(() => docs.value.filter((doc) => doc.kind === 'reservation'))

const invoices = computed<InvoiceRow[]>(() => {
  return docs.value
    .filter((doc) => doc.kind === 'folio')
    .map((folio) => {
      const stay = reservations.value.find((row) => row.id === folio.reservation_id || row.folio_id === folio.id) ?? null
      const lines = Array.isArray(folio.lines) ? folio.lines as Line[] : []
      const charges = lines
        .filter((line) => Number(line.amount || 0) > 0 && String(line.kind || '') !== 'deposit')
        .reduce((sum, line) => sum + Number(line.amount || 0), 0)
      const paid = lines
        .filter((line) => Number(line.amount || 0) < 0)
        .reduce((sum, line) => sum + Math.abs(Number(line.amount || 0)), 0)
      const status = String(folio.status || 'open')
      const id = String(folio.id)
      return {
        id,
        reference: String(folio.reference || `FOL-${id.slice(-6).toUpperCase()}`),
        guest: String(folio.guest_name || stay?.guest_name || '—'),
        room: String(folio.room_number || stay?.room_number || '—'),
        arrive: String(stay?.arrive_on || ''),
        depart: String(stay?.depart_on || ''),
        status,
        currency: String(stay?.type_currency || settings.value.currency_code || ''),
        charges,
        paid,
        balance: Math.max(0, charges - paid),
        lines: lines.slice().sort((a, b) => String(a.created_at || '').localeCompare(String(b.created_at || ''))),
      }
    })
    .sort((a, b) => b.reference.localeCompare(a.reference))
})

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  return invoices.value.filter((row) => {
    if (statusFilter.value !== 'all' && row.status !== statusFilter.value) return false
    if (!q) return true
    return [row.reference, row.guest, row.room].join(' ').toLowerCase().includes(q)
  })
})

const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)
const openBalance = computed(() => invoices.value.filter((row) => row.status === 'open').reduce((sum, row) => sum + row.balance, 0))
const closedCount = computed(() => invoices.value.filter((row) => row.status === 'closed').length)
const balanceCurrency = computed(() => invoices.value.find((row) => row.currency)?.currency || settings.value.currency_code || '')

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(
      hospitalitySnapshotPath(['folio', 'reservation', 'hotel_settings']),
    )).data.docs
    if (selected.value) {
      selected.value = invoices.value.find((row) => row.id === selected.value?.id) ?? null
    }
  } catch (cause) {
    error.value = extractApiErrorMessage(cause, t('hotel.invoicesPage.loadError'))
  } finally {
    loading.value = false
  }
}

function kindLabel(kind?: string) {
  const key = `hotel.invoicesPage.kinds.${kind || ''}`
  const label = t(key)
  return label === key ? (kind || '—') : label
}

function printInvoice(row: InvoiceRow) {
  const body = row.lines.map((line) => `<tr><td>${escapeHtml(kindLabel(line.kind))}</td><td>${escapeHtml(line.description || '—')}</td><td>${escapeHtml(formatMoney(Number(line.amount || 0), row.currency))}</td></tr>`).join('')
  const html = `<!doctype html><html><head><title>${escapeHtml(row.reference)}</title><style>body{font-family:sans-serif;padding:24px}table{width:100%;border-collapse:collapse}td,th{border-bottom:1px solid #ddd;padding:6px;text-align:left}</style></head><body><h1>${escapeHtml(row.reference)}</h1><p>${escapeHtml(row.guest)} · ${escapeHtml(row.room)}</p><table><thead><tr><th></th><th></th><th></th></tr></thead><tbody>${body}</tbody></table><p><strong>${escapeHtml(t('hotel.invoicesPage.balance'))}: ${escapeHtml(formatMoney(row.balance, row.currency))}</strong></p></body></html>`
  const popup = window.open('', '_blank', 'noopener,noreferrer')
  if (!popup) return
  popup.document.write(html)
  popup.document.close()
  popup.focus()
  popup.print()
}

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char] || char))
}

watch(() => ctx.currentStoreId, () => { void load() })
onMounted(load)
useRealtimeSync(realtimeTopics.hotel, () => { void load() })
</script>

<template>
  <HotelChrome scroll-body>
    <div class="hi">
      <header class="hi__head">
        <div>
          <h2>{{ t('hotel.invoicesPage.title') }}</h2>
          <p>{{ t('hotel.invoicesPage.subtitle') }}</p>
        </div>
        <button type="button" class="btn btn--ghost" :disabled="loading" @click="load">
          <AppIcon name="recycle" :size="15" />
          {{ t('common.refresh') }}
        </button>
      </header>

      <p v-if="error" class="hi__error">{{ error }}</p>

      <section class="hi__stats">
        <article>
          <span>{{ t('hotel.invoicesPage.count') }}</span>
          <strong>{{ invoices.length }}</strong>
        </article>
        <article>
          <span>{{ t('hotel.invoicesPage.openBalance') }}</span>
          <strong>{{ formatMoney(openBalance, balanceCurrency) }}</strong>
        </article>
        <article>
          <span>{{ t('hotel.invoicesPage.closedCount') }}</span>
          <strong>{{ closedCount }}</strong>
        </article>
      </section>

      <div class="hi__toolbar">
        <div class="hi__chips">
          <button type="button" :class="{ 'is-on': statusFilter === 'all' }" @click="statusFilter = 'all'">{{ t('hotel.invoicesPage.all') }}</button>
          <button type="button" :class="{ 'is-on': statusFilter === 'open' }" @click="statusFilter = 'open'">{{ t('hotel.invoicesPage.open') }}</button>
          <button type="button" :class="{ 'is-on': statusFilter === 'closed' }" @click="statusFilter = 'closed'">{{ t('hotel.invoicesPage.closed') }}</button>
        </div>
        <input v-model="query" class="field hi__search" :placeholder="t('hotel.invoicesPage.search')">
      </div>

      <LoadingBlock v-if="loading && !invoices.length" />
      <p v-else-if="!filtered.length" class="hi__empty">{{ t('hotel.invoicesPage.empty') }}</p>
      <div v-else class="hi__table-wrap">
        <table class="hi__table">
          <thead>
            <tr>
              <th>{{ t('hotel.invoicesPage.reference') }}</th>
              <th>{{ t('hotel.invoicesPage.guest') }}</th>
              <th>{{ t('hotel.invoicesPage.room') }}</th>
              <th>{{ t('hotel.invoicesPage.stay') }}</th>
              <th>{{ t('hotel.invoicesPage.status') }}</th>
              <th>{{ t('hotel.invoicesPage.balance') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in paged" :key="row.id" @click="selected = row">
              <td>{{ row.reference }}</td>
              <td>{{ row.guest }}</td>
              <td>{{ row.room }}</td>
              <td>{{ row.arrive ? `${formatDate(row.arrive)} → ${formatDate(row.depart)}` : '—' }}</td>
              <td>{{ row.status === 'closed' ? t('hotel.invoicesPage.closed') : t('hotel.invoicesPage.open') }}</td>
              <td>{{ formatMoney(row.balance, row.currency) }}</td>
            </tr>
          </tbody>
        </table>
        <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
      </div>
    </div>

    <AppModal
      :open="selected !== null"
      :title="selected?.reference || t('hotel.invoicesPage.title')"
      icon="receipt"
      size="lg"
      @close="selected = null"
    >
      <template v-if="selected">
        <p class="hi__meta">{{ selected.guest }} · {{ t('hotel.invoicesPage.room') }} {{ selected.room }}</p>
        <p class="hi__meta">
          {{ t('hotel.invoicesPage.charges') }} {{ formatMoney(selected.charges, selected.currency) }}
          · {{ t('hotel.invoicesPage.paid') }} {{ formatMoney(selected.paid, selected.currency) }}
          · {{ t('hotel.invoicesPage.balance') }} {{ formatMoney(selected.balance, selected.currency) }}
        </p>
        <p v-if="!selected.lines.length" class="hi__empty">{{ t('hotel.invoicesPage.empty') }}</p>
        <table v-else class="hi__table">
          <thead>
            <tr>
              <th>{{ t('hotel.invoicesPage.lines') }}</th>
              <th></th>
              <th>{{ t('hotel.invoicesPage.balance') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(line, index) in selected.lines" :key="line.id || index">
              <td>{{ kindLabel(line.kind) }}</td>
              <td>{{ line.description || '—' }}</td>
              <td>{{ formatMoney(Number(line.amount || 0), selected.currency) }}</td>
            </tr>
          </tbody>
        </table>
        <div class="app-modal__actions">
          <RouterLink class="btn btn--ghost" to="/admin/hotel/stays">{{ t('hotel.invoicesPage.openStay') }}</RouterLink>
          <button type="button" class="btn btn--primary" @click="printInvoice(selected)">{{ t('hotel.invoicesPage.print') }}</button>
        </div>
      </template>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.hi {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-bottom: 1.5rem;
}

.hi__head,
.hi__toolbar,
.hi__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.hi__head h2 {
  margin: 0;
  font-size: 1.35rem;
}

.hi__head p,
.hi__meta,
.hi__empty,
.hi__error {
  margin: 0.25rem 0 0;
  color: var(--color-text-muted);
}

.hi__error {
  color: var(--color-danger, #9b2c2c);
}

.hi__stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 0.65rem;
}

.hi__stats article {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.85rem 1rem;
  border: 1px solid var(--color-border, #e4e8ec);
  background: var(--color-surface, #fff);
}

.hi__stats span {
  font-size: 0.78rem;
  color: var(--color-text-muted);
}

.hi__stats strong {
  font-size: 1.35rem;
}

.hi__search {
  flex: 1;
  min-width: 12rem;
}

.hi__chips button {
  border: 1px solid var(--color-border, #e4e8ec);
  background: var(--color-surface, #fff);
  padding: 0.4rem 0.7rem;
}

.hi__chips button.is-on {
  background: var(--color-text-primary, #102033);
  color: #fff;
}

.hi__table-wrap {
  overflow: auto;
  border: 1px solid var(--color-border, #e4e8ec);
  background: var(--color-surface, #fff);
}

.hi__table {
  width: 100%;
  border-collapse: collapse;
}

.hi__table th,
.hi__table td {
  padding: 0.6rem 0.7rem;
  text-align: left;
  border-bottom: 1px solid var(--color-border, #e4e8ec);
}

.hi__table tbody tr {
  cursor: pointer;
}
</style>
