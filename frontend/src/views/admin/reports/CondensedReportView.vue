<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { CondensedReport } from '../../../types'
import { formatMoney } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()

const report = ref<CondensedReport | null>(null)
const appliedFrom = ref('')
const appliedTo = ref('')
const from = ref('')
const to = ref('')
const loading = ref(false)

const methodColors = ['#0e7490', '#059669', '#2563eb', '#d97706', '#7c3aed', '#dc2626', '#64748b']
const statusColors: Record<string, string> = {
  paid: '#059669',
  partial: '#d97706',
  on_credit: '#7c3aed',
  unpaid: '#dc2626',
}

type ChartSlice = {
  key: string
  label: string
  amount: number
  count: number
  share: number
  color: string
  startAngle: number
  endAngle: number
}

function localDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function initDates() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth(), 1)
  from.value = localDate(start)
  to.value = localDate(now)
}

async function load() {
  loading.value = true
  try {
    const res = await store.loadCondensedReport({
      from: from.value || undefined,
      to: to.value || undefined,
    })
    report.value = res.data
    appliedFrom.value = res.meta.from || from.value
    appliedTo.value = res.meta.to || to.value
  } finally {
    loading.value = false
  }
}

function methodLabel(row: { payment_method: string; label: string }) {
  if (row.label?.trim()) return row.label.trim()
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
  return row.payment_method
}

function statusLabel(status: string) {
  const mapped: Record<string, string> = {
    paid: 'pointOfSale.orders.payment.paid',
    partial: 'pointOfSale.orders.payment.partial',
    on_credit: 'pointOfSale.orders.payment.on_credit',
    unpaid: 'pointOfSale.orders.payment.unpaid',
  }
  const key = mapped[status] ?? `reports.condensedAnalytics.status.${status}`
  const translated = t(key)
  return translated === key ? status : translated
}

function formatShare(share: number) {
  const value = Number.isFinite(share) ? share : 0
  return `${value.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 1 })}%`
}

function buildSlices(
  rows: Array<{ key: string; label: string; amount: number; count: number; share: number; color: string }>,
): ChartSlice[] {
  const total = rows.reduce((sum, row) => sum + row.amount, 0)
  if (total <= 0) return []

  let cursor = -90
  return rows.map((row) => {
    const sweep = (row.amount / total) * 360
    const startAngle = cursor
    const endAngle = cursor + sweep
    cursor = endAngle
    return { ...row, startAngle, endAngle }
  })
}

function polar(cx: number, cy: number, r: number, angleDeg: number) {
  const rad = (angleDeg * Math.PI) / 180
  return {
    x: cx + r * Math.cos(rad),
    y: cy + r * Math.sin(rad),
  }
}

function donutPath(startAngle: number, endAngle: number, outer = 42, inner = 26) {
  const cx = 50
  const cy = 50
  const sweep = endAngle - startAngle
  if (sweep <= 0.01) return ''

  // Full circle: split into two 180° arcs (SVG cannot draw a 360° arc in one path).
  if (sweep >= 359.9) {
    const mid = startAngle + 180
    const o1 = polar(cx, cy, outer, startAngle)
    const o2 = polar(cx, cy, outer, mid)
    const i1 = polar(cx, cy, inner, startAngle)
    const i2 = polar(cx, cy, inner, mid)
    return [
      `M ${o1.x} ${o1.y}`,
      `A ${outer} ${outer} 0 1 1 ${o2.x} ${o2.y}`,
      `A ${outer} ${outer} 0 1 1 ${o1.x} ${o1.y}`,
      `L ${i1.x} ${i1.y}`,
      `A ${inner} ${inner} 0 1 0 ${i2.x} ${i2.y}`,
      `A ${inner} ${inner} 0 1 0 ${i1.x} ${i1.y}`,
      'Z',
    ].join(' ')
  }

  const large = sweep > 180 ? 1 : 0
  const outerStart = polar(cx, cy, outer, startAngle)
  const outerEnd = polar(cx, cy, outer, endAngle)
  const innerEnd = polar(cx, cy, inner, endAngle)
  const innerStart = polar(cx, cy, inner, startAngle)

  return [
    `M ${outerStart.x} ${outerStart.y}`,
    `A ${outer} ${outer} 0 ${large} 1 ${outerEnd.x} ${outerEnd.y}`,
    `L ${innerEnd.x} ${innerEnd.y}`,
    `A ${inner} ${inner} 0 ${large} 0 ${innerStart.x} ${innerStart.y}`,
    'Z',
  ].join(' ')
}

function labelPoint(slice: ChartSlice) {
  const mid = (slice.startAngle + slice.endAngle) / 2
  return polar(50, 50, 34, mid)
}

const paymentMethods = computed(() => report.value?.by_payment_method ?? [])
const paymentStatuses = computed(() => report.value?.by_payment_status ?? [])

const methodsTotal = computed(() => paymentMethods.value.reduce((sum, row) => sum + row.amount, 0))
const statusTotal = computed(() => paymentStatuses.value.reduce((sum, row) => sum + row.amount, 0))

const methodSlices = computed(() => buildSlices(
  paymentMethods.value.map((row, i) => ({
    key: row.payment_method,
    label: methodLabel(row),
    amount: row.amount,
    count: row.count,
    share: row.share,
    color: methodColors[i % methodColors.length],
  })),
))

const statusSlices = computed(() => buildSlices(
  paymentStatuses.value.map((row) => ({
    key: row.payment_status,
    label: statusLabel(row.payment_status),
    amount: row.amount,
    count: row.count,
    share: row.share,
    color: statusColors[row.payment_status] ?? '#64748b',
  })),
))

const periodLabel = computed(() => {
  if (!appliedFrom.value && !appliedTo.value) return '—'
  const fromPart = appliedFrom.value || '…'
  const toPart = appliedTo.value || '…'
  return t('reports.condensedAnalytics.periodValue', { from: fromPart, to: toPart })
})

onMounted(() => {
  initDates()
  void load()
})
</script>

<template>
  <ReportsLayout>
    <div class="condensed">
      <div class="condensed__chrome">
        <button type="button" class="btn-secondary" :disabled="loading" @click="load">
          <AppIcon name="import" :size="15" />
          <span>{{ t('common.refresh') }}</span>
        </button>
      </div>

      <div class="condensed__filters">
        <div>
          <FieldLabel icon="calendar">{{ t('reports.condensedAnalytics.from') }}</FieldLabel>
          <input v-model="from" type="date" class="field" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.condensedAnalytics.to') }}</FieldLabel>
          <input v-model="to" type="date" class="field" />
        </div>
        <button type="button" class="btn-primary" :disabled="loading" @click="load">
          {{ t('reports.condensedAnalytics.generate') }}
        </button>
      </div>

      <p class="condensed__period">
        {{ t('reports.condensedAnalytics.period') }}: {{ periodLabel }}
      </p>

      <div class="condensed__kpis">
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.condensedAnalytics.totalBilled') }}</p>
          <p class="kpi__value">{{ formatMoney(report?.total_billed ?? 0) }}</p>
          <p class="kpi__hint">{{ t('reports.condensedAnalytics.invoicesCount', { count: report?.invoice_count ?? 0 }) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.condensedAnalytics.totalCollected') }}</p>
          <p class="kpi__value">{{ formatMoney(report?.total_collected ?? 0) }}</p>
          <p class="kpi__hint">—</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.condensedAnalytics.totalCredit') }}</p>
          <p class="kpi__value kpi__value--warn">{{ formatMoney(report?.total_credit ?? 0) }}</p>
          <p class="kpi__hint">{{ t('reports.condensedAnalytics.unpaidAmounts') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.condensedAnalytics.taxCollected') }}</p>
          <p class="kpi__value">{{ formatMoney(report?.tax_collected ?? 0) }}</p>
          <p class="kpi__hint">
            {{ t('reports.condensedAnalytics.totalDiscounts') }}: {{ formatMoney(report?.discount_total ?? 0) }}
          </p>
        </article>
      </div>

      <div class="condensed__grid">
        <section class="panel">
          <header class="panel__header">
            <div>
              <h3 class="panel__title">{{ t('reports.condensedAnalytics.byPaymentMethod') }}</h3>
              <p class="panel__hint">{{ t('reports.condensedAnalytics.paymentMethodDetails') }}</p>
            </div>
          </header>

          <div v-if="methodSlices.length" class="chart chart--solo">
            <div class="chart__visual">
              <div class="donut">
                <svg viewBox="0 0 100 100" class="chart__svg" role="img" :aria-label="t('reports.condensedAnalytics.byPaymentMethod')">
                  <circle cx="50" cy="50" r="42" fill="#f1f5f9" />
                  <path
                    v-for="slice in methodSlices"
                    :key="slice.key"
                    :d="donutPath(slice.startAngle, slice.endAngle)"
                    :fill="slice.color"
                  >
                    <title>{{ slice.label }} — {{ formatMoney(slice.amount) }} ({{ formatShare(slice.share) }})</title>
                  </path>
                  <template v-for="slice in methodSlices" :key="`lbl-${slice.key}`">
                    <text
                      v-if="slice.share >= 8"
                      :x="labelPoint(slice).x"
                      :y="labelPoint(slice).y"
                      class="chart__pct"
                    >{{ formatShare(slice.share) }}</text>
                  </template>
                </svg>
                <div class="donut__center">
                  <span>{{ t('reports.condensedAnalytics.chartTotal') }}</span>
                  <strong>{{ formatMoney(methodsTotal) }}</strong>
                </div>
              </div>
            </div>
          </div>

          <div v-if="methodSlices.length" class="details">
            <h4 class="details__title">{{ t('reports.condensedAnalytics.paymentMethodDetails') }}</h4>
            <ul class="details__list">
              <li v-for="slice in methodSlices" :key="`detail-${slice.key}`" class="details__row">
                <span class="details__swatch" :style="{ background: slice.color }" />
                <div class="details__body">
                  <p class="details__name">{{ slice.label }}</p>
                  <p class="details__count">{{ t('reports.condensedAnalytics.transactions', { count: slice.count }) }}</p>
                </div>
                <div class="details__figures">
                  <strong class="details__amount">{{ formatMoney(slice.amount) }}</strong>
                  <span class="details__share">{{ formatShare(slice.share) }}</span>
                </div>
                <div class="details__bar" aria-hidden="true">
                  <i :style="{ width: `${Math.min(100, slice.share)}%`, background: slice.color }" />
                </div>
              </li>
            </ul>
          </div>
          <p v-else class="panel__empty">{{ t('reports.condensedAnalytics.noPayments') }}</p>
        </section>

        <section class="panel">
          <header class="panel__header">
            <div>
              <h3 class="panel__title">{{ t('reports.condensedAnalytics.byPaymentStatus') }}</h3>
              <p class="panel__hint">{{ t('reports.condensedAnalytics.totalBilled') }}</p>
            </div>
          </header>

          <div v-if="statusSlices.length" class="chart chart--solo">
            <div class="chart__visual">
              <div class="donut">
                <svg viewBox="0 0 100 100" class="chart__svg" role="img" :aria-label="t('reports.condensedAnalytics.byPaymentStatus')">
                  <circle cx="50" cy="50" r="42" fill="#f1f5f9" />
                  <path
                    v-for="slice in statusSlices"
                    :key="slice.key"
                    :d="donutPath(slice.startAngle, slice.endAngle)"
                    :fill="slice.color"
                  >
                    <title>{{ slice.label }} — {{ formatMoney(slice.amount) }} ({{ formatShare(slice.share) }})</title>
                  </path>
                  <template v-for="slice in statusSlices" :key="`lbl-${slice.key}`">
                    <text
                      v-if="slice.share >= 8"
                      :x="labelPoint(slice).x"
                      :y="labelPoint(slice).y"
                      class="chart__pct"
                    >{{ formatShare(slice.share) }}</text>
                  </template>
                </svg>
                <div class="donut__center">
                  <span>{{ t('reports.condensedAnalytics.chartTotal') }}</span>
                  <strong>{{ formatMoney(statusTotal) }}</strong>
                </div>
              </div>
            </div>
          </div>

          <div v-if="statusSlices.length" class="details">
            <h4 class="details__title">{{ t('reports.condensedAnalytics.paymentStatusDetails') }}</h4>
            <ul class="details__list">
              <li v-for="slice in statusSlices" :key="`detail-${slice.key}`" class="details__row">
                <span class="details__swatch" :style="{ background: slice.color }" />
                <div class="details__body">
                  <p class="details__name">{{ slice.label }}</p>
                  <p class="details__count">{{ t('reports.condensedAnalytics.invoicesCount', { count: slice.count }) }}</p>
                </div>
                <div class="details__figures">
                  <strong class="details__amount">{{ formatMoney(slice.amount) }}</strong>
                  <span class="details__share">{{ formatShare(slice.share) }}</span>
                </div>
                <div class="details__bar" aria-hidden="true">
                  <i :style="{ width: `${Math.min(100, slice.share)}%`, background: slice.color }" />
                </div>
              </li>
            </ul>
          </div>
          <p v-else class="panel__empty">{{ t('reports.condensedAnalytics.noStatuses') }}</p>
        </section>
      </div>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.condensed {
  display: grid;
  gap: 1rem;
}

.condensed__chrome {
  display: flex;
  justify-content: flex-end;
}

.condensed__filters {
  display: flex;
  flex-wrap: wrap;
  align-items: end;
  gap: 0.75rem;
}

.condensed__period {
  margin: 0;
  font-size: 0.875rem;
  color: #64748b;
}

.condensed__kpis {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
}

.kpi {
  border-radius: 0.875rem;
  background: #fff;
  padding: 1rem 1.1rem;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.05);
  border: 1px solid #e2e8f0;
}

.kpi__label {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: #64748b;
}

.kpi__value {
  margin: 0.35rem 0 0;
  font-size: 1.35rem;
  font-weight: 700;
  color: #0f172a;
}

.kpi__value--warn {
  color: #b45309;
}

.kpi__hint {
  margin: 0.35rem 0 0;
  font-size: 0.8rem;
  color: #94a3b8;
}

.condensed__grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
}

.panel {
  border-radius: 0.875rem;
  background: #fff;
  border: 1px solid #e2e8f0;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.04);
  overflow: hidden;
}

.panel__header {
  padding: 1rem 1.1rem 0.35rem;
}

.panel__title {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
  color: #0f172a;
}

.panel__hint {
  margin: 0.2rem 0 0;
  font-size: 0.8rem;
  color: #94a3b8;
}

.panel__empty {
  margin: 0;
  padding: 1.5rem 1.1rem;
  font-size: 0.9rem;
  color: #94a3b8;
}

.chart {
  display: grid;
  gap: 1.25rem;
  padding: 0.75rem 1.1rem 0.5rem;
  align-items: center;
}

.chart--solo {
  justify-items: center;
}

.chart__visual {
  display: flex;
  justify-content: center;
}

.donut {
  position: relative;
  width: min(100%, 14rem);
  aspect-ratio: 1;
}

.chart__svg {
  width: 100%;
  height: 100%;
  display: block;
}

.donut__center {
  position: absolute;
  inset: 27%;
  border-radius: 999px;
  background: #fff;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.15rem;
  text-align: center;
  padding: 0.35rem;
  box-shadow: 0 0 0 1px #f1f5f9;
}

.donut__center span {
  font-size: 0.65rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #94a3b8;
}

.donut__center strong {
  font-size: clamp(0.7rem, 2.4vw, 0.95rem);
  font-weight: 700;
  color: #0f172a;
  line-height: 1.15;
  word-break: break-word;
}

.chart__pct {
  fill: #fff;
  font-size: 4.2px;
  font-weight: 700;
  text-anchor: middle;
  dominant-baseline: middle;
  pointer-events: none;
}

.details {
  padding: 0.35rem 1.1rem 1.15rem;
}

.details__title {
  margin: 0 0 0.65rem;
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: #64748b;
}

.details__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.65rem;
}

.details__row {
  display: grid;
  grid-template-columns: auto 1fr auto;
  grid-template-areas:
    "swatch body figures"
    "swatch bar bar";
  gap: 0.25rem 0.7rem;
  align-items: center;
  padding: 0.7rem 0.8rem;
  border-radius: 0.75rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
}

.details__swatch {
  grid-area: swatch;
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 999px;
  align-self: start;
  margin-top: 0.35rem;
}

.details__body {
  grid-area: body;
  min-width: 0;
}

.details__name {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
  word-break: break-word;
}

.details__count {
  margin: 0.15rem 0 0;
  font-size: 0.8rem;
  color: #64748b;
}

.details__figures {
  grid-area: figures;
  text-align: right;
  display: grid;
  gap: 0.1rem;
}

.details__amount {
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
  white-space: nowrap;
}

.details__share {
  font-size: 0.8rem;
  font-weight: 600;
  color: #0e7490;
}

.details__bar {
  grid-area: bar;
  height: 0.35rem;
  border-radius: 999px;
  background: #e2e8f0;
  overflow: hidden;
}

.details__bar i {
  display: block;
  height: 100%;
  border-radius: inherit;
  min-width: 0.2rem;
}

.field {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
  min-width: 10rem;
}

.btn-secondary,
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 0.5rem;
  padding: 0.55rem 1rem;
  font-size: 0.875rem;
  font-weight: 600;
}

.btn-secondary {
  border: 1px solid #cbd5e1;
  background: #fff;
  color: #334155;
}

.btn-secondary:disabled,
.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-primary {
  border: none;
  background: #0e7490;
  color: #fff;
}

@media (max-width: 720px) {
  .donut {
    width: 12.5rem;
  }
}
</style>
