<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { DailyReport, DailyReportDay, DailyReportDetail } from '../../../types'
import { getAppCurrency } from '../../../utils/currency'
import { formatMoney } from '../../../utils/format'
import { intlLocale } from '../../../i18n/locales'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<DailyReport | null>(null)
const detail = ref<DailyReportDetail | null>(null)
const month = ref('')
const storeId = ref(context.currentStoreId ?? '')
const loading = ref(false)
const detailLoading = ref(false)
const modalOpen = ref(false)
const selectedDay = ref<DailyReportDay | null>(null)

function localMonth(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}

function initMonth() {
  month.value = localMonth(new Date())
}

const summary = computed(() => report.value?.summary)
const daysByKey = computed(() => {
  const map = new Map<string, DailyReportDay>()
  for (const day of report.value?.days ?? []) map.set(day.day, day)
  return map
})

const monthLabel = computed(() => {
  if (!month.value) return '—'
  const [y, m] = month.value.split('-').map(Number)
  const date = new Date(y, (m || 1) - 1, 1)
  return new Intl.DateTimeFormat(intlLocale(), { month: 'long', year: 'numeric' }).format(date)
})

const weekdayLabels = computed(() =>
  [1, 2, 3, 4, 5, 6, 7].map((d) => t(`reports.salesAnalytics.weekdays.${d}`)),
)

const calendarCells = computed(() => {
  if (!month.value) return []
  const [y, m] = month.value.split('-').map(Number)
  const first = new Date(y, (m || 1) - 1, 1)
  const daysInMonth = new Date(y, m || 1, 0).getDate()
  // Monday-first: Sun=0 → 6, Mon=1 → 0, …
  const startPad = (first.getDay() + 6) % 7
  const cells: Array<{ key: string; dayNum: number | null; data: DailyReportDay | null }> = []

  for (let i = 0; i < startPad; i++) {
    cells.push({ key: `pad-${i}`, dayNum: null, data: null })
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const key = `${month.value}-${String(d).padStart(2, '0')}`
    cells.push({ key, dayNum: d, data: daysByKey.value.get(key) ?? null })
  }
  while (cells.length % 7 !== 0) {
    cells.push({ key: `trail-${cells.length}`, dayNum: null, data: null })
  }
  return cells
})

function compactMoney(amount: number): string {
  const value = (Number(amount) || 0) / 100
  const code = getAppCurrency()
  const abs = Math.abs(value)
  let compact: string
  if (abs >= 1_000_000) compact = `${(value / 1_000_000).toFixed(1)}M`
  else if (abs >= 1_000) compact = `${(value / 1_000).toFixed(1)}K`
  else compact = value.toFixed(value % 1 === 0 ? 0 : 1)
  return `${compact} ${code}`
}

function methodLabel(row: { payment_method: string; label: string }) {
  if (row.payment_method === 'house_offer') return t('reports.dailyAnalytics.houseOffer')
  const mapped: Record<string, string> = {
    cash: 'sales.methodCash',
    card: 'sales.methodCard',
    credit: 'sales.methodCredit',
    mobile_money: 'sales.methodMobileMoney',
    bank_transfer: 'sales.methodBankTransfer',
    wallet: 'sales.methodWallet',
  }
  const key = mapped[row.payment_method]
  if (key) {
    const translated = t(key)
    if (translated !== key) return translated
  }
  return row.label || row.payment_method
}

function paymentStatusLabel(status: string) {
  if (status === 'on_credit' || status === 'credit') return t('sales.methodCredit')
  const mapped: Record<string, string> = {
    paid: 'pointOfSale.orders.payment.paid',
    partial: 'pointOfSale.orders.payment.partial',
    unpaid: 'pointOfSale.orders.payment.unpaid',
  }
  const key = mapped[status]
  if (key) {
    const translated = t(key)
    if (translated !== key) return translated
  }
  return status
}

function shiftMonth(delta: number) {
  const [y, m] = month.value.split('-').map(Number)
  const next = new Date(y, (m || 1) - 1 + delta, 1)
  month.value = localMonth(next)
  void load()
}

async function load() {
  loading.value = true
  try {
    const res = await store.loadDailyReport({
      store_id: storeId.value || undefined,
      month: month.value || undefined,
    })
    report.value = res.data
    if (res.meta.month) month.value = res.meta.month
  } finally {
    loading.value = false
  }
}

async function openDay(cell: { dayNum: number | null; data: DailyReportDay | null; key: string }) {
  if (!cell.dayNum) return
  selectedDay.value = cell.data
  modalOpen.value = true
  detail.value = null
  detailLoading.value = true
  try {
    const res = await store.loadDailyReportDetail({
      store_id: storeId.value || undefined,
      date: cell.key,
    })
    detail.value = res.data
  } finally {
    detailLoading.value = false
  }
}

function closeModal() {
  modalOpen.value = false
  detail.value = null
  selectedDay.value = null
}

function exportDayExcel() {
  if (!detail.value) return
  const rows: string[][] = []
  const d = detail.value
  rows.push([t('reports.dailyAnalytics.dayTitle'), d.date])
  rows.push([t('reports.dailyAnalytics.ca'), String((d.summary.revenue || 0) / 100)])
  rows.push([t('reports.dailyAnalytics.netRevenue'), String((d.summary.net_revenue || 0) / 100)])
  rows.push([t('reports.dailyAnalytics.collected'), String((d.summary.collected || 0) / 100)])
  rows.push([t('reports.dailyAnalytics.credit'), String((d.summary.credit || 0) / 100)])
  rows.push([])
  rows.push([t('reports.dailyAnalytics.invoicesTitle')])
  rows.push([
    t('reports.dailyAnalytics.colInvoice'),
    t('reports.dailyAnalytics.colCustomer'),
    t('reports.dailyAnalytics.colStatus'),
    t('reports.dailyAnalytics.colPayment'),
    t('reports.dailyAnalytics.colTotal'),
    t('reports.dailyAnalytics.colPaid'),
    t('reports.dailyAnalytics.colUnpaid'),
    t('reports.dailyAnalytics.houseOffer'),
  ])
  for (const inv of d.invoices) {
    rows.push([
      inv.invoice_number,
      inv.customer_name,
      inv.status,
      inv.payment_status,
      String((inv.total || 0) / 100),
      String((inv.paid_amount || 0) / 100),
      String((inv.outstanding_amount || 0) / 100),
      String((inv.house_offer || 0) / 100),
    ])
  }
  rows.push([])
  rows.push([t('reports.dailyAnalytics.productsTitle')])
  rows.push([
    t('reports.dailyAnalytics.colProduct'),
    t('reports.dailyAnalytics.colQty'),
    t('reports.dailyAnalytics.colAvgPrice'),
    t('reports.dailyAnalytics.colTotal'),
    t('reports.dailyAnalytics.colGrossProfit'),
    t('reports.dailyAnalytics.colMargin'),
  ])
  for (const p of d.products) {
    rows.push([
      `${p.label}${p.sku ? ` (${p.sku})` : ''}`,
      String(p.quantity),
      String((p.unit_price || 0) / 100),
      String((p.revenue || 0) / 100),
      String((p.gross_profit || 0) / 100),
      String(p.margin_pct),
    ])
  }
  rows.push([])
  rows.push([t('reports.dailyAnalytics.paymentsTitle')])
  rows.push([
    t('reports.dailyAnalytics.colPaymentNum'),
    t('reports.dailyAnalytics.colInvoice'),
    t('reports.dailyAnalytics.colMethod'),
    t('reports.dailyAnalytics.colReference'),
    t('reports.dailyAnalytics.colAmount'),
  ])
  for (const pay of d.payments) {
    rows.push([
      pay.payment_number || '—',
      pay.invoice_number || '—',
      methodLabel(pay),
      pay.reference || '—',
      String((pay.amount || 0) / 100),
    ])
  }

  const csv = rows
    .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(','))
    .join('\n')
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `daily-report-${d.date}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const detailTitle = computed(() => {
  if (!detail.value?.date && !selectedDay.value?.day) return t('reports.dailyAnalytics.dayTitle')
  const raw = detail.value?.date || selectedDay.value?.day || ''
  try {
    return new Intl.DateTimeFormat(intlLocale(), { dateStyle: 'full' }).format(new Date(raw + 'T12:00:00'))
  } catch {
    return raw
  }
})

onMounted(() => {
  initMonth()
  void load()
})
</script>

<template>
  <ReportsLayout>
    <div class="daily">
      <div class="daily__chrome">
        <button type="button" class="btn-secondary" :disabled="loading" @click="load">
          <AppIcon name="import" :size="15" />
          <span>{{ t('common.refresh') }}</span>
        </button>
      </div>

      <div class="daily__kpis">
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.dailyAnalytics.ca') }}</p>
          <p class="kpi__value kpi__value--ca">{{ formatMoney(summary?.revenue ?? 0) }}</p>
          <p class="kpi__hint">{{ t('reports.dailyAnalytics.caHint') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.dailyAnalytics.netRevenue') }}</p>
          <p class="kpi__value kpi__value--net">{{ formatMoney(summary?.net_revenue ?? 0) }}</p>
          <p class="kpi__hint">{{ t('reports.dailyAnalytics.netHint') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.dailyAnalytics.collected') }}</p>
          <p class="kpi__value">{{ formatMoney(summary?.collected ?? 0) }}</p>
          <p class="kpi__hint">{{ t('reports.dailyAnalytics.collectedHint') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.dailyAnalytics.credit') }}</p>
          <p class="kpi__value kpi__value--credit">{{ formatMoney(summary?.credit ?? 0) }}</p>
          <p class="kpi__hint">{{ t('reports.dailyAnalytics.creditHint') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.dailyAnalytics.invoices') }}</p>
          <p class="kpi__value">{{ summary?.invoices_count ?? 0 }}</p>
          <p class="kpi__hint">{{ t('reports.dailyAnalytics.invoicesHint') }}</p>
        </article>
      </div>

      <section class="cal">
        <header class="cal__header">
          <button type="button" class="cal__nav" :aria-label="t('reports.dailyAnalytics.prevMonth')" @click="shiftMonth(-1)">‹</button>
          <h3 class="cal__title">{{ monthLabel }}</h3>
          <button type="button" class="cal__nav" :aria-label="t('reports.dailyAnalytics.nextMonth')" @click="shiftMonth(1)">›</button>
        </header>

        <div class="cal__weekdays">
          <span v-for="label in weekdayLabels" :key="label">{{ label }}</span>
        </div>

        <div class="cal__grid" :class="{ 'cal__grid--loading': loading }">
          <button
            v-for="cell in calendarCells"
            :key="cell.key"
            type="button"
            class="day"
            :class="{
              'day--empty': !cell.dayNum,
              'day--has': cell.data && cell.data.invoices_count > 0,
            }"
            :disabled="!cell.dayNum"
            @click="openDay(cell)"
          >
            <template v-if="cell.dayNum">
              <div class="day__top">
                <span class="day__num">{{ cell.dayNum }}</span>
                <span v-if="cell.data && cell.data.invoices_count > 0" class="day__badge">
                  {{ cell.data.invoices_count }}
                </span>
              </div>
              <template v-if="cell.data && cell.data.invoices_count > 0">
                <div class="day__row">
                  <span class="day__lbl">{{ t('reports.dailyAnalytics.shortCa') }}</span>
                  <span class="day__val day__val--ca">{{ compactMoney(cell.data.revenue) }}</span>
                </div>
                <div class="day__row">
                  <span class="day__lbl">{{ t('reports.dailyAnalytics.shortNet') }}</span>
                  <span class="day__val day__val--net">{{ compactMoney(cell.data.net_revenue) }}</span>
                </div>
                <div class="day__row">
                  <span class="day__lbl">{{ t('reports.dailyAnalytics.shortCredit') }}</span>
                  <span class="day__val day__val--credit">{{ compactMoney(cell.data.credit) }}</span>
                </div>
              </template>
              <p v-else class="day__empty-mark">—</p>
            </template>
          </button>
        </div>
      </section>
    </div>

    <AppModal
      :open="modalOpen"
      :title="detailTitle"
      size="xl"
      icon="calendar"
      tone="accent"
      @close="closeModal"
    >
      <div v-if="detailLoading" class="detail-loading">{{ t('common.loading') }}…</div>
      <div v-else-if="detail" class="detail">
        <div class="detail__actions">
          <button type="button" class="btn-secondary" @click="exportDayExcel">
            <AppIcon name="import" :size="15" />
            <span>{{ t('reports.dailyAnalytics.exportExcel') }}</span>
          </button>
        </div>

        <div class="detail__kpis">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.ca') }}</p>
            <p class="kpi__value kpi__value--ca">{{ formatMoney(detail.summary.revenue) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.netRevenue') }}</p>
            <p class="kpi__value kpi__value--net">{{ formatMoney(detail.summary.net_revenue) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.collected') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.collected) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.credit') }}</p>
            <p class="kpi__value kpi__value--credit">{{ formatMoney(detail.summary.credit) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.totalTax') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.tax_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.totalDiscount') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.discount_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.grossProfit') }}</p>
            <p class="kpi__value kpi__value--net">{{ formatMoney(detail.summary.gross_profit) }}</p>
            <p class="kpi__hint">{{ detail.summary.margin_pct }}% {{ t('reports.revenueReport.margin') }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.dailyAnalytics.houseOffer') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.house_offer) }}</p>
          </article>
        </div>

        <section class="panel">
          <header class="panel__header">
            <h4 class="panel__title">{{ t('reports.dailyAnalytics.paymentTxTitle') }}</h4>
          </header>
          <div class="methods">
            <article
              v-for="row in detail.by_payment_method"
              :key="row.payment_method"
              class="method"
              :class="{
                'method--cash': row.payment_method === 'cash',
                'method--credit': row.payment_method === 'credit',
                'method--house': row.payment_method === 'house_offer',
              }"
            >
              <p class="method__count">{{ row.count }}</p>
              <p class="method__label">{{ methodLabel(row) }}</p>
              <p class="method__amount">{{ formatMoney(row.amount) }}</p>
            </article>
            <p v-if="!detail.by_payment_method.length" class="panel__empty">
              {{ t('reports.dailyAnalytics.noPayments') }}
            </p>
          </div>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h4 class="panel__title">
              {{ t('reports.dailyAnalytics.invoicesTitle') }}
              <span class="panel__count">({{ detail.invoices.length }})</span>
            </h4>
          </header>
          <div class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('reports.dailyAnalytics.colInvoice') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colCustomer') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colStatus') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colPayment') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colTotal') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colPaid') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colUnpaid') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.houseOffer') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="inv in detail.invoices" :key="inv.id">
                  <td class="mono">{{ inv.invoice_number }}</td>
                  <td>{{ inv.customer_name }}</td>
                  <td>{{ inv.status }}</td>
                  <td>{{ paymentStatusLabel(inv.payment_status) }}</td>
                  <td class="num">{{ formatMoney(inv.total) }}</td>
                  <td class="num">{{ formatMoney(inv.paid_amount) }}</td>
                  <td class="num unpaid">{{ formatMoney(inv.outstanding_amount) }}</td>
                  <td class="num">{{ formatMoney(inv.house_offer) }}</td>
                </tr>
                <tr v-if="!detail.invoices.length">
                  <td colspan="8" class="panel__empty">{{ t('reports.dailyAnalytics.noInvoices') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h4 class="panel__title">
              {{ t('reports.dailyAnalytics.productsTitle') }}
              <span class="panel__count">({{ detail.products.length }})</span>
            </h4>
          </header>
          <div class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('reports.dailyAnalytics.colProduct') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colQty') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colAvgPrice') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colTotal') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colGrossProfit') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colMargin') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(p, idx) in detail.products" :key="`${p.label}-${idx}`">
                  <td>
                    <div class="product">
                      <span class="product__name">{{ p.label }}</span>
                      <span v-if="p.sku" class="product__sku">{{ p.sku }}</span>
                    </div>
                  </td>
                  <td class="num">{{ p.quantity }}</td>
                  <td class="num">{{ formatMoney(p.unit_price) }}</td>
                  <td class="num">{{ formatMoney(p.revenue) }}</td>
                  <td class="num">{{ formatMoney(p.gross_profit) }}</td>
                  <td class="num">{{ p.margin_pct }}%</td>
                </tr>
                <tr v-if="!detail.products.length">
                  <td colspan="6" class="panel__empty">{{ t('reports.dailyAnalytics.noProducts') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h4 class="panel__title">
              {{ t('reports.dailyAnalytics.paymentsTitle') }}
              <span class="panel__count">({{ detail.payments.length }})</span>
            </h4>
          </header>
          <div class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('reports.dailyAnalytics.colPaymentNum') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colInvoice') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colMethod') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colReference') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colAmount') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="pay in detail.payments" :key="pay.id">
                  <td class="mono">{{ pay.payment_number || '—' }}</td>
                  <td class="mono">{{ pay.invoice_number || '—' }}</td>
                  <td>
                    <span
                      class="pill"
                      :class="{
                        'pill--cash': pay.payment_method === 'cash',
                        'pill--credit': pay.payment_method === 'credit',
                        'pill--house': pay.payment_method === 'house_offer',
                      }"
                    >
                      {{ methodLabel(pay) }}
                    </span>
                  </td>
                  <td>{{ pay.reference || '—' }}</td>
                  <td class="num">{{ formatMoney(pay.amount) }}</td>
                </tr>
                <tr v-if="!detail.payments.length">
                  <td colspan="5" class="panel__empty">{{ t('reports.dailyAnalytics.noPayments') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </AppModal>
  </ReportsLayout>
</template>

<style scoped>
.daily { display: grid; gap: 1.25rem; }
.daily__chrome {
  display: flex; flex-wrap: wrap; align-items: center; justify-content: flex-end; gap: 0.75rem;
}
.btn-secondary {
  display: inline-flex; align-items: center; gap: 0.4rem;
  border-radius: 0.5rem; border: 1px solid #cbd5e1; background: #fff;
  padding: 0.45rem 0.85rem; font-size: 0.875rem; cursor: pointer;
}
.btn-secondary:disabled { opacity: 0.6; cursor: not-allowed; }

.daily__kpis, .detail__kpis {
  display: grid; gap: 0.85rem;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
}
.kpi {
  border-radius: 0.85rem; background: #fff; padding: 0.95rem 1rem;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.05); border: 1px solid #e2e8f0;
}
.kpi__label { margin: 0; font-size: 0.75rem; color: #64748b; font-weight: 600; text-transform: uppercase; letter-spacing: 0.02em; }
.kpi__value { margin: 0.35rem 0 0; font-size: 1.2rem; font-weight: 700; color: #0f172a; }
.kpi__value--ca { color: #1d4ed8; }
.kpi__value--net { color: #059669; }
.kpi__value--credit { color: #dc2626; }
.kpi__hint { margin: 0.25rem 0 0; font-size: 0.75rem; color: #94a3b8; }

.cal {
  border-radius: 1rem; background: #fff; border: 1px solid #e2e8f0;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.04); padding: 1rem;
}
.cal__header {
  display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; margin-bottom: 0.85rem;
}
.cal__title { margin: 0; font-size: 1.05rem; font-weight: 700; color: #0f172a; text-transform: capitalize; }
.cal__nav {
  width: 2rem; height: 2rem; border-radius: 0.5rem; border: 1px solid #cbd5e1;
  background: #fff; font-size: 1.25rem; line-height: 1; cursor: pointer; color: #334155;
}
.cal__weekdays {
  display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 0.5rem; margin-bottom: 0.5rem;
}
.cal__weekdays span {
  text-align: center; font-size: 0.75rem; font-weight: 600; color: #64748b; text-transform: uppercase;
}
.cal__grid {
  display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 0.5rem;
}
.cal__grid--loading { opacity: 0.55; pointer-events: none; }

.day {
  min-height: 7.5rem; border-radius: 0.75rem; border: 1px solid #e2e8f0; background: #fff;
  padding: 0.55rem 0.6rem; text-align: left; cursor: pointer; transition: border-color 0.15s, box-shadow 0.15s;
  display: flex; flex-direction: column; gap: 0.2rem;
}
.day:hover:not(:disabled) { border-color: #93c5fd; box-shadow: 0 0 0 2px rgb(59 130 246 / 0.12); }
.day--empty { background: transparent; border-color: transparent; cursor: default; min-height: 0; }
.day--has { background: #fff; }
.day:disabled { cursor: default; }
.day__top { display: flex; align-items: center; justify-content: space-between; gap: 0.35rem; margin-bottom: 0.15rem; }
.day__num { font-size: 1.05rem; font-weight: 700; color: #334155; }
.day__badge {
  min-width: 1.35rem; height: 1.35rem; border-radius: 999px; background: #dbeafe; color: #1d4ed8;
  font-size: 0.7rem; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; padding: 0 0.3rem;
}
.day__row { display: flex; justify-content: space-between; gap: 0.35rem; font-size: 0.68rem; line-height: 1.25; }
.day__lbl { color: #94a3b8; }
.day__val { font-weight: 700; white-space: nowrap; }
.day__val--ca { color: #1d4ed8; }
.day__val--net { color: #059669; }
.day__val--credit { color: #dc2626; }
.day__empty-mark { margin: auto 0 0; color: #cbd5e1; font-size: 0.9rem; }

.detail { display: grid; gap: 1.1rem; }
.detail-loading { padding: 2rem; text-align: center; color: #64748b; }
.detail__actions { display: flex; justify-content: flex-end; }

.panel {
  border: 1px solid #e2e8f0; border-radius: 0.85rem; background: #fff; overflow: hidden;
}
.panel__header { padding: 0.85rem 1rem; border-bottom: 1px solid #e2e8f0; }
.panel__title { margin: 0; font-size: 0.95rem; font-weight: 700; color: #0f172a; }
.panel__count { color: #64748b; font-weight: 600; }
.panel__empty { text-align: center; color: #94a3b8; padding: 1rem; margin: 0; }

.methods {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 0.75rem; padding: 0.85rem;
}
.method {
  border-radius: 0.75rem; border: 1px solid #e2e8f0; padding: 0.85rem; background: #f8fafc;
}
.method--cash { background: #ecfdf5; border-color: #a7f3d0; }
.method--credit { background: #fef2f2; border-color: #fecaca; }
.method--house { background: #eff6ff; border-color: #bfdbfe; }
.method__count { margin: 0; font-size: 1.35rem; font-weight: 800; color: #0f172a; }
.method__label { margin: 0.15rem 0 0; font-size: 0.8rem; color: #64748b; font-weight: 600; }
.method__amount { margin: 0.35rem 0 0; font-weight: 700; color: #0f172a; }

.table-wrap { overflow: auto; }
.table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
.table th, .table td { padding: 0.65rem 0.85rem; border-bottom: 1px solid #f1f5f9; text-align: left; }
.table th { background: #f8fafc; color: #64748b; font-weight: 600; white-space: nowrap; }
.table .num { text-align: right; font-variant-numeric: tabular-nums; }
.table .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 0.78rem; }
.table .unpaid { color: #dc2626; font-weight: 600; }
.product { display: flex; flex-direction: column; gap: 0.1rem; }
.product__name { font-weight: 600; color: #0f172a; }
.product__sku { font-size: 0.72rem; color: #94a3b8; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }

.pill {
  display: inline-flex; align-items: center; border-radius: 0.4rem; padding: 0.15rem 0.45rem;
  font-size: 0.75rem; font-weight: 600; background: #f1f5f9; color: #334155;
}
.pill--cash { background: #d1fae5; color: #047857; }
.pill--credit { background: #fee2e2; color: #b91c1c; }
.pill--house { background: #dbeafe; color: #1d4ed8; }

@media (max-width: 900px) {
  .cal__grid, .cal__weekdays { gap: 0.35rem; }
  .day { min-height: 5.5rem; padding: 0.4rem; }
  .day__row { font-size: 0.6rem; }
  .day__num { font-size: 0.9rem; }
}
</style>
