<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type {
  UserPerformanceDetail,
  UserPerformanceReport,
  UserPerformanceSession,
  UserPerformanceSessionDetail,
  UserPerformanceUser,
} from '../../../types'
import { getAppCurrency } from '../../../utils/currency'
import { formatDateTime, formatMoney, toDateTimeLocal } from '../../../utils/format'

type MainTab = 'users' | 'sessions'
type DetailTab = 'invoices' | 'orders' | 'pos' | 'products' | 'customers'
type SessionDetailTab = 'orders' | 'products'
type ModalMode = 'user' | 'session'

type Slice = {
  key: string
  label: string
  amount: number
  share: number
  color: string
  startAngle: number
  endAngle: number
}

const { t, locale } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<UserPerformanceReport | null>(null)
const detail = ref<UserPerformanceDetail | null>(null)
const sessionDetail = ref<UserPerformanceSessionDetail | null>(null)
const sessionPreview = ref<UserPerformanceSession | null>(null)
const from = ref('')
const to = ref('')
const storeId = ref(context.currentStoreId ?? '')
const search = ref('')
const loading = ref(false)
const detailLoading = ref(false)
const modalOpen = ref(false)
const modalMode = ref<ModalMode>('user')
const mainTab = ref<MainTab>('users')
const detailTab = ref<DetailTab>('invoices')
const sessionDetailTab = ref<SessionDetailTab>('orders')

const donutColors = ['#0e7490', '#059669', '#2563eb', '#d97706', '#0f766e', '#dc2626', '#be185d', '#64748b', '#b45309', '#0284c7']

const sessionHeader = computed(() => sessionDetail.value?.session ?? sessionPreview.value)

const summary = computed(() => report.value?.summary)
const users = computed(() => report.value?.users ?? [])
const sessions = computed(() => report.value?.sessions ?? [])

const filteredUsers = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return users.value
  return users.value.filter((u) =>
    u.name.toLowerCase().includes(q)
    || u.email.toLowerCase().includes(q)
    || u.handle.toLowerCase().includes(q)
    || (u.role || '').toLowerCase().includes(q),
  )
})

const filteredSessions = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return sessions.value
  return sessions.value.filter((s) =>
    (s.session_number || '').toLowerCase().includes(q)
    || (s.cashier_name || '').toLowerCase().includes(q)
    || (s.cashier_email || '').toLowerCase().includes(q)
    || (s.register_name || '').toLowerCase().includes(q)
    || (s.register_code || '').toLowerCase().includes(q),
  )
})

const contributors = computed(() => users.value.filter((u) => u.invoiced_total > 0))
const topPerformers = computed(() => contributors.value.slice(0, 8))
const topMax = computed(() => Math.max(
  1,
  ...topPerformers.value.flatMap((u) => [u.invoiced_total, u.collected_total, u.credit_total]),
))

const contributionSlices = computed((): Slice[] => {
  const rows = contributors.value
  const total = rows.reduce((sum, row) => sum + row.invoiced_total, 0) || 1
  let cursor = 0
  return rows.map((row, index) => {
    const share = Math.round((row.invoiced_total / total) * 1000) / 10
    const start = (cursor / total) * 360
    cursor += row.invoiced_total
    const end = (cursor / total) * 360
    return {
      key: row.user_id,
      label: row.name,
      amount: row.invoiced_total,
      share,
      color: donutColors[index % donutColors.length],
      startAngle: start,
      endAngle: end,
    }
  })
})

const axisTicks = computed(() => {
  const max = topMax.value
  return [0, 0.25, 0.5, 0.75, 1].map((ratio) => axisLabel(Math.round(max * ratio)))
})

const detailDaily = computed(() => detail.value?.by_day ?? [])
const detailDailyMax = computed(() => Math.max(
  1,
  ...detailDaily.value.flatMap((d) => [d.invoiced_total, d.collected_total]),
))
const detailDailyTicks = computed(() => {
  const max = detailDailyMax.value
  return [0, 0.25, 0.5, 0.75, 1].map((ratio) => axisLabel(Math.round(max * ratio)))
})

function initDates() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0)
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 0)
  from.value = toDateTimeLocal(start).slice(0, 16)
  to.value = toDateTimeLocal(end).slice(0, 16)
}

async function load() {
  loading.value = true
  try {
    const res = await store.loadUserPerformanceReport({
      store_id: storeId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
    report.value = res.data
    if (res.meta.from) from.value = res.meta.from.replace(' ', 'T').slice(0, 16)
    if (res.meta.to) to.value = res.meta.to.replace(' ', 'T').slice(0, 16)
  } finally {
    loading.value = false
  }
}

function polar(cx: number, cy: number, r: number, angleDeg: number) {
  const rad = ((angleDeg - 90) * Math.PI) / 180
  return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) }
}

function donutPath(startAngle: number, endAngle: number, outer = 42, inner = 26) {
  const cx = 50
  const cy = 50
  const sweep = endAngle - startAngle
  if (sweep <= 0.01) return ''

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
  const o1 = polar(cx, cy, outer, startAngle)
  const o2 = polar(cx, cy, outer, endAngle)
  const i2 = polar(cx, cy, inner, endAngle)
  const i1 = polar(cx, cy, inner, startAngle)
  return [
    `M ${o1.x} ${o1.y}`,
    `A ${outer} ${outer} 0 ${large} 1 ${o2.x} ${o2.y}`,
    `L ${i2.x} ${i2.y}`,
    `A ${inner} ${inner} 0 ${large} 0 ${i1.x} ${i1.y}`,
    'Z',
  ].join(' ')
}

function labelPoint(slice: Slice) {
  const mid = (slice.startAngle + slice.endAngle) / 2
  return polar(50, 50, 34, mid)
}

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

function axisLabel(value: number) {
  const major = value / 100
  if (major >= 1_000_000) return `${Math.round(major / 100_000) / 10}M`
  if (major >= 1000) return `${Math.round(major / 100) / 10}K`
  return String(Math.round(major))
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase()
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
}

async function openDetail(user: UserPerformanceUser) {
  modalMode.value = 'user'
  detail.value = null
  sessionDetail.value = null
  sessionPreview.value = null
  detailTab.value = 'invoices'
  modalOpen.value = true
  detailLoading.value = true
  try {
    const res = await store.loadUserPerformanceDetail({
      user_id: user.user_id,
      store_id: storeId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
    detail.value = res.data
  } finally {
    detailLoading.value = false
  }
}

async function openSessionDetail(session: UserPerformanceSession) {
  modalMode.value = 'session'
  detail.value = null
  sessionDetail.value = null
  sessionPreview.value = session
  sessionDetailTab.value = 'orders'
  modalOpen.value = true
  detailLoading.value = true
  try {
    const res = await store.loadUserPerformanceSessionDetail(session.id)
    sessionDetail.value = res.data
  } finally {
    detailLoading.value = false
  }
}

function closeModal() {
  modalOpen.value = false
  detail.value = null
  sessionDetail.value = null
  sessionPreview.value = null
}

function formatDuration(seconds: number): string {
  const total = Math.max(0, Math.floor(Number(seconds) || 0))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  if (h <= 0) return `${m}m`
  return `${h}h ${m}m`
}

function sessionPaymentLabel(label: string) {
  if (label === 'house_offer') return t('reports.userPerformanceAnalytics.houseOffer')
  return label
}

function shortDay(day: string) {
  const parts = day.split('-')
  if (parts.length >= 3) return `${parts[1]}-${parts[2]}`
  return day
}

function exportDetailExcel() {
  if (!detail.value) return
  const d = detail.value
  const rows: string[][] = []
  rows.push([d.user.name, d.user.handle, d.user.role])
  rows.push([t('reports.userPerformanceAnalytics.from'), d.from])
  rows.push([t('reports.userPerformanceAnalytics.to'), d.to])
  rows.push([])
  rows.push([t('reports.userPerformanceAnalytics.colInvoices'), String(d.summary.invoices_count)])
  rows.push([t('reports.userPerformanceAnalytics.colInvoiced'), String((d.summary.invoiced_total || 0) / 100)])
  rows.push([t('reports.userPerformanceAnalytics.colCollected'), String((d.summary.collected_total || 0) / 100)])
  rows.push([t('reports.userPerformanceAnalytics.colCredit'), String((d.summary.credit_total || 0) / 100)])
  rows.push([t('reports.userPerformanceAnalytics.totalTax'), String((d.summary.tax_total || 0) / 100)])
  rows.push([t('reports.userPerformanceAnalytics.totalDiscount'), String((d.summary.discount_total || 0) / 100)])
  rows.push([t('reports.userPerformanceAnalytics.houseOffer'), String((d.summary.house_offer || 0) / 100)])
  rows.push([])
  rows.push([
    t('reports.dailyAnalytics.colInvoice'),
    t('reports.userPerformanceAnalytics.colDate'),
    t('reports.dailyAnalytics.colCustomer'),
    t('reports.dailyAnalytics.colStatus'),
    t('reports.dailyAnalytics.colPayment'),
    t('reports.userPerformanceAnalytics.colCashier'),
    t('reports.dailyAnalytics.colTotal'),
    t('reports.dailyAnalytics.colPaid'),
    t('reports.dailyAnalytics.colUnpaid'),
    t('reports.userPerformanceAnalytics.houseOffer'),
  ])
  for (const inv of d.invoices) {
    rows.push([
      inv.invoice_number,
      inv.completed_at || '',
      inv.customer_name,
      inv.status,
      inv.payment_status,
      inv.cashier_name || '',
      String((inv.total || 0) / 100),
      String((inv.paid_amount || 0) / 100),
      String((inv.outstanding_amount || 0) / 100),
      String((inv.house_offer || 0) / 100),
    ])
  }
  downloadCsv(rows, `performance-${d.user.name.replace(/\s+/g, '-').toLowerCase()}.csv`)
}

function exportSessionOrders() {
  if (!sessionDetail.value) return
  const d = sessionDetail.value
  const rows: string[][] = []
  rows.push([d.session.session_number, d.session.cashier_name || ''])
  rows.push([t('reports.userPerformanceAnalytics.colOpened'), d.session.opened_at || ''])
  rows.push([t('reports.userPerformanceAnalytics.colClosed'), d.session.closed_at || ''])
  rows.push([])
  rows.push([
    t('reports.userPerformanceAnalytics.colOrderNo'),
    t('reports.userPerformanceAnalytics.colDate'),
    t('reports.dailyAnalytics.colCustomer'),
    t('reports.userPerformanceAnalytics.colTakenBy'),
    t('reports.userPerformanceAnalytics.colPaidBy'),
    t('reports.dailyAnalytics.colStatus'),
    t('reports.dailyAnalytics.colPayment'),
    t('reports.dailyAnalytics.colTotal'),
    t('reports.dailyAnalytics.colPaid'),
  ])
  for (const order of d.orders) {
    rows.push([
      order.order_number,
      order.completed_at || '',
      order.customer_name || '',
      order.taken_by || '',
      order.paid_by || '',
      order.status,
      sessionPaymentLabel(order.payment_label),
      String((order.total || 0) / 100),
      String((order.paid_amount || 0) / 100),
    ])
  }
  downloadCsv(rows, `${d.session.session_number}-commandes.csv`)
}

function downloadCsv(rows: string[][], filename: string) {
  const csv = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

function paymentStatusLabel(status: string) {
  const mapped: Record<string, string> = {
    paid: 'pointOfSale.orders.payment.paid',
    partial: 'pointOfSale.orders.payment.partial',
    unpaid: 'pointOfSale.orders.payment.unpaid',
    on_credit: 'pointOfSale.orders.payment.on_credit',
    credit: 'sales.methodCredit',
  }
  const key = mapped[status]
  if (key) {
    const translated = t(key)
    if (translated !== key) return translated
  }
  return status
}

function formatPeriod(value?: string | null) {
  if (!value) return '—'
  const normalized = value.includes('T') ? value : value.replace(' ', 'T')
  try {
    return new Date(normalized).toLocaleString(locale.value, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    })
  } catch {
    return value
  }
}

onMounted(() => {
  initDates()
  void load()
})
</script>

<template>
  <ReportsLayout>
    <div class="up">
      <div class="up__toolbar">
        <button type="button" class="btn-secondary" :disabled="loading" @click="load">
          <AppIcon name="import" :size="15" />
          {{ t('common.refresh') }}
        </button>
        <div class="up__filters">
          <div>
            <FieldLabel icon="calendar">{{ t('reports.userPerformanceAnalytics.from') }}</FieldLabel>
            <input v-model="from" type="datetime-local" class="field" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('reports.userPerformanceAnalytics.to') }}</FieldLabel>
            <input v-model="to" type="datetime-local" class="field" />
          </div>
          <div>
            <FieldLabel icon="stores">{{ t('nav.stores') }}</FieldLabel>
            <select v-model="storeId" class="field">
              <option value="">{{ t('org.allStores') }}</option>
              <option v-for="s in context.activeStores" :key="s.id" :value="s.id">{{ s.name }}</option>
            </select>
          </div>
          <button type="button" class="btn-primary" :disabled="loading" @click="load">
            {{ t('reports.userPerformanceAnalytics.apply') }}
          </button>
        </div>
        <div class="up__search">
          <AppIcon name="search" :size="15" />
          <input
            v-model="search"
            type="search"
            class="field up__search-input"
            :placeholder="mainTab === 'sessions'
              ? t('reports.userPerformanceAnalytics.searchSessions')
              : t('reports.userPerformanceAnalytics.searchUsers')"
          >
        </div>
      </div>

      <div class="up__tabs" role="tablist">
        <button
          type="button"
          class="up__tab"
          :class="{ 'up__tab--active': mainTab === 'users' }"
          @click="mainTab = 'users'"
        >
          {{ t('reports.userPerformanceAnalytics.tabUsers') }}
        </button>
        <button
          type="button"
          class="up__tab"
          :class="{ 'up__tab--active': mainTab === 'sessions' }"
          @click="mainTab = 'sessions'"
        >
          {{ t('reports.userPerformanceAnalytics.tabSessions') }}
        </button>
      </div>

      <div v-if="report && mainTab === 'users'" class="up__kpis">
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.activeUsers') }}</p>
          <p class="kpi__value">{{ summary?.active_users ?? 0 }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalInvoices') }}</p>
          <p class="kpi__value">{{ summary?.invoices_count ?? 0 }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalInvoiced') }}</p>
          <p class="kpi__value">{{ compactMoney(summary?.invoiced_total ?? 0) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalCollected') }}</p>
          <p class="kpi__value">{{ compactMoney(summary?.collected_total ?? 0) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalCredit') }}</p>
          <p class="kpi__value">{{ compactMoney(summary?.credit_total ?? 0) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalOrders') }}</p>
          <p class="kpi__value">{{ summary?.orders_count ?? 0 }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.purchaseOrders') }}</p>
          <p class="kpi__value">{{ summary?.purchase_orders_count ?? 0 }}</p>
        </article>
      </div>

      <div v-if="report && mainTab === 'users'" class="up__charts">
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.userPerformanceAnalytics.revenueContribution') }}</h3>
          </header>
          <div v-if="contributionSlices.length" class="chart">
            <div class="donut">
              <svg viewBox="0 0 100 100" class="chart__svg" role="img">
                <circle cx="50" cy="50" r="42" fill="var(--up-soft)" />
                <path
                  v-for="slice in contributionSlices"
                  :key="slice.key"
                  :d="donutPath(slice.startAngle, slice.endAngle)"
                  :fill="slice.color"
                >
                  <title>{{ slice.label }} — {{ formatMoney(slice.amount) }} ({{ slice.share }}%)</title>
                </path>
                <template v-for="slice in contributionSlices" :key="`lbl-${slice.key}`">
                  <text
                    v-if="slice.share >= 6"
                    :x="labelPoint(slice).x"
                    :y="labelPoint(slice).y"
                    class="chart__pct"
                  >{{ slice.label.split(' ')[0] }}</text>
                </template>
              </svg>
            </div>
            <ul class="legend">
              <li v-for="slice in contributionSlices.slice(0, 12)" :key="slice.key" class="legend__row">
                <span class="legend__swatch" :style="{ background: slice.color }" />
                <span class="legend__label">{{ slice.label }}</span>
                <strong>{{ slice.share }}%</strong>
              </li>
            </ul>
          </div>
          <p v-else class="panel__empty">{{ t('reports.userPerformanceAnalytics.noActivity') }}</p>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.userPerformanceAnalytics.topPerformers') }}</h3>
            <div class="hbar__keys">
              <span><i class="dot dot--invoiced" /> {{ t('reports.userPerformanceAnalytics.invoiced') }}</span>
              <span><i class="dot dot--credit" /> {{ t('reports.userPerformanceAnalytics.totalCredit') }}</span>
              <span><i class="dot dot--collected" /> {{ t('reports.userPerformanceAnalytics.totalCollected') }}</span>
            </div>
          </header>
          <div v-if="topPerformers.length" class="hbar">
            <div class="hbar__axis">
              <span v-for="tick in axisTicks" :key="tick">{{ tick }}</span>
            </div>
            <div class="hbar__rows">
              <div v-for="user in topPerformers" :key="user.user_id" class="hbar__row">
                <span class="hbar__name" :title="user.name">{{ user.name }}</span>
                <div class="hbar__tracks">
                  <div class="hbar__bar hbar__bar--invoiced" :style="{ width: `${(user.invoiced_total / topMax) * 100}%` }" />
                  <div class="hbar__bar hbar__bar--credit" :style="{ width: `${(user.credit_total / topMax) * 100}%` }" />
                  <div class="hbar__bar hbar__bar--collected" :style="{ width: `${(user.collected_total / topMax) * 100}%` }" />
                </div>
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('reports.userPerformanceAnalytics.noActivity') }}</p>
        </section>
      </div>

      <section v-if="report && mainTab === 'users'" class="panel panel--table">
        <header class="panel__header panel__header--stack">
          <h3 class="panel__title">
            {{ t('reports.userPerformanceAnalytics.allUsers', { count: filteredUsers.length }) }}
          </h3>
          <p class="panel__hint">{{ t('reports.userPerformanceAnalytics.attributionNote') }}</p>
        </header>
        <div class="table-wrap">
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.userPerformanceAnalytics.colUser') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colRole') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colInvoices') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colInvoiced') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colCollected') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colCredit') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colOrders') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colPOs') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="user in filteredUsers" :key="user.user_id">
                <td>
                  <div class="user-cell">
                    <span class="avatar">{{ initials(user.name) }}</span>
                    <div>
                      <strong>{{ user.name }}</strong>
                      <span class="muted">{{ user.handle }}</span>
                    </div>
                  </div>
                </td>
                <td><span class="role-pill">{{ user.role }}</span></td>
                <td class="num">{{ user.invoices_count }}</td>
                <td class="num">{{ formatMoney(user.invoiced_total) }}</td>
                <td class="num">{{ formatMoney(user.collected_total) }}</td>
                <td class="num">{{ formatMoney(user.credit_total) }}</td>
                <td class="num">{{ user.orders_count }}</td>
                <td class="num">{{ user.purchase_orders_count }}</td>
                <td class="num">
                  <button type="button" class="link-btn" @click="openDetail(user)">
                    {{ t('reports.userPerformanceAnalytics.viewDetail') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!filteredUsers.length" class="panel__empty">{{ t('reports.userPerformanceAnalytics.noUsers') }}</p>
        </div>
      </section>

      <section v-if="report && mainTab === 'sessions'" class="panel panel--table">
        <header class="panel__header panel__header--row">
          <div>
            <h3 class="panel__title">
              {{ t('reports.userPerformanceAnalytics.sessionsTitle', { count: filteredSessions.length }) }}
            </h3>
            <p class="panel__hint">{{ t('reports.userPerformanceAnalytics.sessionsHint') }}</p>
          </div>
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="import" :size="15" />
            {{ t('common.refresh') }}
          </button>
        </header>
        <div class="table-wrap">
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.userPerformanceAnalytics.colSessionNo') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colCashier') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colStart') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colEnd') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colDuration') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colStatus') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colOrders') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colSales') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="session in filteredSessions"
                :key="session.id"
                class="row-click"
                @click="openSessionDetail(session)"
              >
                <td>
                  <strong class="mono">{{ session.session_number }}</strong>
                </td>
                <td>
                  <div class="user-cell">
                    <span class="avatar">{{ initials(session.cashier_name || '?') }}</span>
                    <strong>{{ session.cashier_name || '—' }}</strong>
                  </div>
                </td>
                <td>{{ formatPeriod(session.opened_at) }}</td>
                <td>{{ session.closed_at ? formatPeriod(session.closed_at) : '—' }}</td>
                <td>{{ formatDuration(session.duration_seconds) }}</td>
                <td>
                  <span class="role-pill" :class="session.status === 'open' ? 'role-pill--ok' : ''">
                    {{ session.status === 'open'
                      ? t('pointOfSale.shifts.open')
                      : t('pointOfSale.shifts.closed') }}
                  </span>
                </td>
                <td class="num">{{ session.orders_count }}</td>
                <td class="num">{{ formatMoney(session.sales_total) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!filteredSessions.length" class="panel__empty">{{ t('reports.userPerformanceAnalytics.noSessions') }}</p>
        </div>
      </section>

      <LoadingBlock v-if="loading && !report" variant="table" :label="t('common.loading')" />
    </div>

    <AppModal
      :open="modalOpen"
      :title="modalMode === 'session'
        ? (sessionHeader?.session_number || t('reports.userPerformanceAnalytics.sessionDetailTitle'))
        : t('reports.userPerformanceAnalytics.detailTitle')"
      size="xl"
      icon="account"
      @close="closeModal"
    >
      <LoadingBlock v-if="detailLoading && modalMode === 'user'" variant="detail" :rows="4" :label="t('common.loading')" />

      <div v-else-if="modalMode === 'session'" class="detail">
        <header class="detail__hero">
          <div class="detail__identity">
            <span class="avatar avatar--lg">{{ initials(sessionHeader?.cashier_name || '?') }}</span>
            <div>
              <h3 class="detail__name mono">{{ sessionHeader?.session_number || '—' }}</h3>
              <p class="detail__handle">
                {{ sessionHeader?.cashier_name || '—' }}
                <span>·</span>
                <span>{{ formatPeriod(sessionHeader?.opened_at) }}</span>
                <span>→</span>
                <span>{{ sessionHeader?.closed_at ? formatPeriod(sessionHeader.closed_at) : '—' }}</span>
              </p>
            </div>
          </div>
          <button type="button" class="btn-secondary" :disabled="!sessionDetail" @click="exportSessionOrders">
            <AppIcon name="import" :size="15" />
            {{ t('reports.userPerformanceAnalytics.exportOrders') }}
          </button>
        </header>

        <LoadingBlock v-if="detailLoading || !sessionDetail" variant="detail" :rows="4" :label="t('common.loading')" />
        <template v-else>
          <div class="up__kpis up__kpis--compact">
            <article class="kpi">
              <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colOrders') }}</p>
              <p class="kpi__value">{{ sessionDetail.summary.orders_count }}</p>
            </article>
            <article class="kpi">
              <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colInvoiced') }}</p>
              <p class="kpi__value">{{ formatMoney(sessionDetail.summary.invoiced_total) }}</p>
            </article>
            <article class="kpi">
              <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colCollected') }}</p>
              <p class="kpi__value">{{ formatMoney(sessionDetail.summary.collected_total) }}</p>
            </article>
            <article class="kpi">
              <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colCredit') }}</p>
              <p class="kpi__value">{{ formatMoney(sessionDetail.summary.credit_total) }}</p>
            </article>
          </div>

          <div class="detail__stats">
            <button
              type="button"
              class="stat-tab"
              :class="{ 'stat-tab--active': sessionDetailTab === 'orders' }"
              @click="sessionDetailTab = 'orders'"
            >
              <span>{{ t('reports.userPerformanceAnalytics.colOrders') }}</span>
              <strong>{{ sessionDetail.summary.orders_count }}</strong>
            </button>
            <button
              type="button"
              class="stat-tab"
              :class="{ 'stat-tab--active': sessionDetailTab === 'products' }"
              @click="sessionDetailTab = 'products'"
            >
              <span>{{ t('reports.userPerformanceAnalytics.productsTab') }}</span>
              <strong>{{ sessionDetail.summary.products_count }}</strong>
            </button>
          </div>

          <div v-if="sessionDetailTab === 'orders'" class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('reports.userPerformanceAnalytics.colOrderNo') }}</th>
                  <th>{{ t('reports.userPerformanceAnalytics.colDate') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colCustomer') }}</th>
                  <th>{{ t('reports.userPerformanceAnalytics.colTakenBy') }}</th>
                  <th>{{ t('reports.userPerformanceAnalytics.colPaidBy') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colStatus') }}</th>
                  <th>{{ t('reports.dailyAnalytics.colPayment') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colTotal') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colPaid') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="order in sessionDetail.orders" :key="order.id">
                  <td class="mono">{{ order.order_number }}</td>
                  <td>{{ formatDateTime(order.completed_at) }}</td>
                  <td>{{ order.customer_name || '—' }}</td>
                  <td>{{ order.taken_by || '—' }}</td>
                  <td>{{ order.paid_by || '—' }}</td>
                  <td>{{ order.status }}</td>
                  <td>{{ sessionPaymentLabel(order.payment_label) }}</td>
                  <td class="num">{{ formatMoney(order.total) }}</td>
                  <td class="num">{{ formatMoney(order.paid_amount) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!sessionDetail.orders.length" class="panel__empty">{{ t('reports.userPerformanceAnalytics.noSessionOrders') }}</p>
          </div>

          <div v-else class="table-wrap">
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('reports.dailyAnalytics.colProduct') }}</th>
                  <th class="num">{{ t('reports.userPerformanceAnalytics.colQtySold') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colAvgPrice') }}</th>
                  <th class="num">{{ t('reports.userPerformanceAnalytics.colRevenue') }}</th>
                  <th class="num">{{ t('reports.userPerformanceAnalytics.colCost') }}</th>
                  <th class="num">{{ t('reports.userPerformanceAnalytics.colProfit') }}</th>
                  <th class="num">{{ t('reports.dailyAnalytics.colMargin') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(product, idx) in sessionDetail.products" :key="`${product.label}-${product.sku || ''}-${idx}`">
                  <td>
                    <div class="product-cell">
                      <strong>{{ product.label }}</strong>
                      <span v-if="product.sku" class="muted mono">{{ product.sku }}</span>
                      <div v-if="product.is_house_offer || (product.credit_quantity ?? 0) > 0" class="product-flags">
                        <span v-if="product.is_house_offer" class="flag flag--offer">
                          {{ t('reports.userPerformanceAnalytics.houseOffer') }}
                        </span>
                        <span v-if="product.is_house_offer" class="flag flag--offer-soft">
                          {{ t('reports.userPerformanceAnalytics.offeredCount', { count: product.house_offer_quantity || product.quantity }) }}
                        </span>
                        <span v-else-if="(product.credit_quantity ?? 0) > 0" class="flag flag--credit">
                          {{ t('reports.userPerformanceAnalytics.creditCount', { count: product.credit_quantity }) }}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td class="num">
                    <div class="qty-cell">
                      <strong>{{ product.quantity }}</strong>
                      <span v-if="product.is_house_offer" class="qty-hint">
                        ({{ product.house_offer_quantity || product.quantity }} {{ t('reports.userPerformanceAnalytics.offAbbrev') }})
                      </span>
                      <span v-else-if="(product.credit_quantity ?? 0) > 0" class="qty-hint">
                        ({{ product.credit_quantity }} {{ t('reports.userPerformanceAnalytics.creditAbbrev') }})
                      </span>
                    </div>
                  </td>
                  <td class="num">{{ formatMoney(product.unit_price) }}</td>
                  <td class="num">{{ formatMoney(product.revenue) }}</td>
                  <td class="num">{{ formatMoney(product.cost) }}</td>
                  <td class="num">{{ formatMoney(product.gross_profit) }}</td>
                  <td class="num">{{ product.margin_pct.toFixed(1) }}%</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!sessionDetail.products.length" class="panel__empty">{{ t('reports.dailyAnalytics.noProducts') }}</p>
          </div>
        </template>
      </div>

      <div v-else-if="detail" class="detail">
        <header class="detail__hero">
          <div class="detail__identity">
            <span class="avatar avatar--lg">{{ initials(detail.user.name) }}</span>
            <div>
              <h3 class="detail__name">{{ detail.user.name }}</h3>
              <p class="detail__handle">
                {{ detail.user.handle }}
                <span>·</span>
                <span class="role-pill">{{ detail.user.role }}</span>
              </p>
            </div>
          </div>
          <button type="button" class="btn-secondary" @click="exportDetailExcel">
            <AppIcon name="import" :size="15" />
            {{ t('reports.userPerformanceAnalytics.exportExcel') }}
          </button>
        </header>

        <div class="up__kpis up__kpis--compact">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colInvoices') }}</p>
            <p class="kpi__value">{{ detail.summary.invoices_count }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colInvoiced') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.invoiced_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colCollected') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.collected_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.colCredit') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.credit_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalTax') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.tax_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.totalDiscount') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.discount_total) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.userPerformanceAnalytics.houseOffer') }}</p>
            <p class="kpi__value">{{ formatMoney(detail.summary.house_offer) }}</p>
          </article>
        </div>

        <section class="panel">
          <header class="panel__header panel__header--row">
            <h3 class="panel__title">{{ t('reports.userPerformanceAnalytics.dailyActivity') }}</h3>
            <div class="hbar__keys">
              <span><i class="dot dot--collected" /> {{ t('reports.userPerformanceAnalytics.totalCollected') }}</span>
              <span><i class="dot dot--invoiced" /> {{ t('reports.userPerformanceAnalytics.totalInvoiced') }}</span>
            </div>
          </header>
          <div v-if="detailDaily.some((d) => d.invoices_count > 0)" class="daily">
            <div class="daily__axis">
              <span v-for="tick in [...detailDailyTicks].reverse()" :key="tick">{{ tick }}</span>
            </div>
            <div class="daily__plot">
              <div v-for="day in detailDaily" :key="day.day" class="daily__col">
                <div class="daily__bars">
                  <div
                    class="daily__bar daily__bar--collected"
                    :style="{ height: `${Math.max(day.collected_total ? 4 : 0, (day.collected_total / detailDailyMax) * 100)}%` }"
                    :title="`${formatMoney(day.collected_total)}`"
                  />
                  <div
                    class="daily__bar daily__bar--invoiced"
                    :style="{ height: `${Math.max(day.invoiced_total ? 4 : 0, (day.invoiced_total / detailDailyMax) * 100)}%` }"
                    :title="`${formatMoney(day.invoiced_total)}`"
                  />
                </div>
                <span class="daily__label">{{ shortDay(day.day) }}</span>
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('reports.userPerformanceAnalytics.noActivity') }}</p>
        </section>

        <div class="detail__stats">
          <button type="button" class="stat-tab" :class="{ 'stat-tab--active': detailTab === 'invoices' }" @click="detailTab = 'invoices'">
            <span>{{ t('reports.userPerformanceAnalytics.colInvoices') }}</span>
            <strong>{{ detail.summary.invoices_count }}</strong>
          </button>
          <button type="button" class="stat-tab" :class="{ 'stat-tab--active': detailTab === 'orders' }" @click="detailTab = 'orders'">
            <span>{{ t('reports.userPerformanceAnalytics.totalOrders') }}</span>
            <strong>{{ detail.summary.orders_count }}</strong>
          </button>
          <button type="button" class="stat-tab" :class="{ 'stat-tab--active': detailTab === 'pos' }" @click="detailTab = 'pos'">
            <span>{{ t('reports.userPerformanceAnalytics.purchaseOrders') }}</span>
            <strong>{{ detail.summary.purchase_orders_count }}</strong>
          </button>
          <button type="button" class="stat-tab" :class="{ 'stat-tab--active': detailTab === 'products' }" @click="detailTab = 'products'">
            <span>{{ t('reports.userPerformanceAnalytics.topProducts') }}</span>
            <strong>{{ detail.summary.products_count }}</strong>
          </button>
          <button type="button" class="stat-tab" :class="{ 'stat-tab--active': detailTab === 'customers' }" @click="detailTab = 'customers'">
            <span>{{ t('reports.userPerformanceAnalytics.topCustomers') }}</span>
            <strong>{{ detail.summary.customers_count }}</strong>
          </button>
        </div>

        <div v-if="detailTab === 'invoices'" class="table-wrap">
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.dailyAnalytics.colInvoice') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colDate') }}</th>
                <th>{{ t('reports.dailyAnalytics.colCustomer') }}</th>
                <th>{{ t('reports.dailyAnalytics.colStatus') }}</th>
                <th>{{ t('reports.dailyAnalytics.colPayment') }}</th>
                <th>{{ t('reports.userPerformanceAnalytics.colCashier') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colTotal') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colPaid') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colUnpaid') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.houseOffer') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="inv in detail.invoices" :key="inv.id">
                <td>{{ inv.invoice_number }}</td>
                <td>{{ formatDateTime(inv.completed_at) }}</td>
                <td>{{ inv.customer_name }}</td>
                <td>{{ inv.status }}</td>
                <td>{{ paymentStatusLabel(inv.payment_status) }}</td>
                <td>{{ inv.cashier_name || '—' }}</td>
                <td class="num">{{ formatMoney(inv.total) }}</td>
                <td class="num">{{ formatMoney(inv.paid_amount) }}</td>
                <td class="num">{{ formatMoney(inv.outstanding_amount) }}</td>
                <td class="num">{{ formatMoney(inv.house_offer) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!detail.invoices.length" class="panel__empty">{{ t('reports.dailyAnalytics.noInvoices') }}</p>
        </div>

        <div v-else-if="detailTab === 'products'" class="table-wrap">
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.dailyAnalytics.colProduct') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colQty') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colAvgPrice') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colTotal') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colGrossProfit') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(product, idx) in detail.products" :key="`${product.label}-${idx}`">
                <td>{{ product.label }}</td>
                <td class="num">{{ product.quantity }}</td>
                <td class="num">{{ formatMoney(product.unit_price) }}</td>
                <td class="num">{{ formatMoney(product.revenue) }}</td>
                <td class="num">{{ formatMoney(product.gross_profit) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!detail.products.length" class="panel__empty">{{ t('reports.dailyAnalytics.noProducts') }}</p>
        </div>

        <div v-else-if="detailTab === 'customers'" class="table-wrap">
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.dailyAnalytics.colCustomer') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colInvoices') }}</th>
                <th class="num">{{ t('reports.userPerformanceAnalytics.colInvoiced') }}</th>
                <th class="num">{{ t('reports.dailyAnalytics.colUnpaid') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(customer, idx) in detail.customers" :key="`${customer.label}-${idx}`">
                <td>{{ customer.label }}</td>
                <td class="num">{{ customer.invoices }}</td>
                <td class="num">{{ formatMoney(customer.revenue) }}</td>
                <td class="num">{{ formatMoney(customer.unpaid) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!detail.customers.length" class="panel__empty">{{ t('reports.userPerformanceAnalytics.noCustomers') }}</p>
        </div>

        <div v-else class="panel__empty">
          {{ detailTab === 'orders'
            ? t('reports.userPerformanceAnalytics.ordersEmpty', { count: detail.summary.orders_count })
            : t('reports.userPerformanceAnalytics.posEmpty', { count: detail.summary.purchase_orders_count }) }}
        </div>
      </div>
    </AppModal>
  </ReportsLayout>
</template>

<style scoped>
.up {
  --up-border: #e2e8f0;
  --up-border-soft: #f1f5f9;
  --up-surface: #fff;
  --up-soft: #f1f5f9;
  --up-muted: #64748b;
  --up-faint: #94a3b8;
  --up-text: #0f172a;
  --up-text-soft: #334155;
  --up-accent: #0e7490;
  --up-accent-soft: #ecfeff;
  --up-collected: #059669;
  --up-credit: #d97706;
  --up-ok-bg: #ecfdf5;
  --up-ok-text: #047857;
  --up-shadow: none;
  display: grid;
  gap: 1rem;
}

.up__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: end;
  gap: 0.75rem;
}

.up__filters {
  display: flex;
  flex-wrap: wrap;
  align-items: end;
  gap: 0.75rem;
  flex: 1;
}

.up__search {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  max-width: 28rem;
  min-width: min(100%, 16rem);
  padding: 0 0.75rem;
  border: 1px solid var(--up-border);
  border-radius: 0.65rem;
  background: var(--up-surface);
  color: var(--up-muted);
}

.up__search-input {
  border: 0 !important;
  box-shadow: none !important;
  background: transparent !important;
  flex: 1;
}

.up__tabs {
  display: inline-flex;
  gap: 0.25rem;
  padding: 0.25rem;
  border-radius: 0.65rem;
  background: var(--up-soft);
  width: fit-content;
}

.up__tab {
  border: 0;
  background: transparent;
  color: var(--up-muted);
  font-weight: 600;
  font-size: 0.875rem;
  padding: 0.45rem 0.9rem;
  border-radius: 0.45rem;
  cursor: pointer;
}

.up__tab--active {
  background: var(--up-surface);
  color: var(--up-text);
  box-shadow: var(--up-shadow);
}

.up__kpis {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
}

.up__kpis--compact {
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
}

.kpi {
  border-radius: 0.75rem;
  background: var(--up-surface);
  padding: 1rem 1.1rem;
  box-shadow: var(--up-shadow);
  border: 1px solid var(--up-border);
}

.kpi__label {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: var(--up-muted);
}

.kpi__value {
  margin: 0.35rem 0 0;
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--up-text);
  font-variant-numeric: tabular-nums;
}

.up__charts {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
}

.panel {
  border-radius: 0.75rem;
  background: var(--up-surface);
  border: 1px solid var(--up-border);
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.04);
  overflow: hidden;
}

.panel__header {
  padding: 1rem 1.1rem 0.5rem;
}

.panel__header--row {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem 1rem;
}

.panel__header--stack {
  display: grid;
  gap: 0.35rem;
}

.panel__title {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
  color: var(--up-text);
}

.panel__hint {
  margin: 0;
  font-size: 0.8rem;
  color: var(--up-faint);
}

.panel__empty {
  margin: 0;
  padding: 1.5rem 1.1rem;
  color: var(--up-faint);
  text-align: center;
}

.chart {
  display: grid;
  gap: 1rem;
  padding: 0 1.1rem 1.1rem;
  grid-template-columns: minmax(160px, 200px) 1fr;
  align-items: center;
}

.donut {
  aspect-ratio: 1;
}

.chart__svg {
  width: 100%;
  height: auto;
}

.chart__pct {
  fill: var(--up-text);
  font-size: 3.2px;
  font-weight: 700;
  text-anchor: middle;
  dominant-baseline: middle;
}

.legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.4rem;
}

.legend__row {
  display: grid;
  grid-template-columns: 0.7rem 1fr auto;
  gap: 0.5rem;
  align-items: center;
  font-size: 0.82rem;
}

.legend__swatch {
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 0.2rem;
}

.legend__label {
  color: var(--up-text-soft);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hbar__keys {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: var(--up-muted);
}

.hbar__keys span {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.dot {
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 0.15rem;
  display: inline-block;
}

.dot--invoiced { background: var(--up-accent); }
.dot--credit { background: var(--up-credit); }
.dot--collected { background: var(--up-collected); }

.hbar {
  padding: 0 1.1rem 1.1rem;
  display: grid;
  gap: 0.75rem;
}

.hbar__axis {
  display: flex;
  justify-content: space-between;
  margin-left: 6.5rem;
  font-size: 0.7rem;
  color: var(--up-faint);
}

.hbar__rows {
  display: grid;
  gap: 0.65rem;
}

.hbar__row {
  display: grid;
  grid-template-columns: 6.5rem 1fr;
  gap: 0.5rem;
  align-items: center;
}

.hbar__name {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--up-text-soft);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hbar__tracks {
  display: grid;
  gap: 0.2rem;
}

.hbar__bar {
  height: 0.35rem;
  border-radius: 0.2rem;
  min-width: 2px;
}

.hbar__bar--invoiced { background: var(--up-accent); }
.hbar__bar--credit { background: var(--up-credit); }
.hbar__bar--collected { background: var(--up-collected); }

.table-wrap {
  overflow-x: auto;
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.table th,
.table td {
  padding: 0.75rem 1rem;
  border-top: 1px solid var(--up-border-soft);
  text-align: left;
  vertical-align: middle;
}

.table th {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--up-muted);
  font-weight: 700;
  background: #f8fafc;
  border-top: 0;
}

.table .num {
  text-align: right;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 0.65rem;
}

.user-cell strong {
  display: block;
  color: var(--up-text);
}

.muted {
  display: block;
  font-size: 0.75rem;
  color: var(--up-faint);
}

.avatar {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  display: inline-grid;
  place-items: center;
  background: var(--up-accent-soft);
  color: var(--up-accent);
  font-size: 0.75rem;
  font-weight: 700;
  flex-shrink: 0;
}

.role-pill {
  display: inline-flex;
  padding: 0.15rem 0.5rem;
  border-radius: 0.35rem;
  background: var(--up-soft);
  color: #475569;
  font-size: 0.75rem;
  font-weight: 600;
}

.role-pill--ok {
  background: var(--up-ok-bg);
  color: var(--up-ok-text);
}

.link-btn {
  border: 0;
  background: transparent;
  color: var(--up-accent);
  font-weight: 600;
  cursor: pointer;
  padding: 0;
}

.link-btn:hover {
  text-decoration: underline;
}

.row-click {
  cursor: pointer;
}

.row-click:hover {
  background: #f8fafc;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.82rem;
  letter-spacing: 0.01em;
}

.product-cell {
  display: grid;
  gap: 0.15rem;
}

.product-flags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.2rem;
}

.flag {
  display: inline-flex;
  align-items: center;
  padding: 0.1rem 0.45rem;
  border-radius: 0.3rem;
  font-size: 0.7rem;
  font-weight: 600;
}

.flag--offer {
  background: var(--up-accent-soft);
  color: var(--up-accent);
}

.flag--offer-soft {
  background: #f0fdfa;
  color: #0f766e;
}

.flag--credit {
  background: #fffbeb;
  color: #b45309;
}

.qty-cell {
  display: grid;
  gap: 0.1rem;
  justify-items: end;
}

.qty-hint {
  font-size: 0.7rem;
  color: var(--up-faint);
}

.detail {
  display: grid;
  gap: 1rem;
}

.detail__hero {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.detail__identity {
  display: flex;
  align-items: center;
  gap: 0.85rem;
}

.detail__name {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--up-text);
}

.detail__handle {
  margin: 0.2rem 0 0;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
  color: var(--up-muted);
  font-size: 0.875rem;
}

.avatar--lg {
  width: 2.75rem;
  height: 2.75rem;
  font-size: 0.95rem;
}

.detail__stats {
  display: grid;
  gap: 0.5rem;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
}

.stat-tab {
  border: 1px solid var(--up-border);
  background: var(--up-surface);
  border-radius: 0.65rem;
  padding: 0.75rem 0.9rem;
  text-align: left;
  cursor: pointer;
  display: grid;
  gap: 0.25rem;
}

.stat-tab span {
  font-size: 0.72rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.02em;
  color: var(--up-muted);
}

.stat-tab strong {
  font-size: 1.15rem;
  color: var(--up-text);
  font-variant-numeric: tabular-nums;
}

.stat-tab--active {
  border-color: var(--up-accent);
  background: var(--up-accent-soft);
}

.daily {
  display: grid;
  grid-template-columns: 3rem 1fr;
  gap: 0.5rem;
  padding: 0 1.1rem 1.1rem;
  min-height: 180px;
}

.daily__axis {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  font-size: 0.68rem;
  color: var(--up-faint);
  padding-bottom: 1.4rem;
}

.daily__plot {
  display: flex;
  align-items: stretch;
  gap: 0.2rem;
  overflow-x: auto;
  min-height: 160px;
}

.daily__col {
  flex: 1 0 1.6rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  min-width: 1.6rem;
}

.daily__bars {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 2px;
  border-bottom: 1px solid var(--up-border);
  min-height: 120px;
}

.daily__bar {
  width: 0.35rem;
  border-radius: 0.2rem 0.2rem 0 0;
  min-height: 0;
}

.daily__bar--collected { background: var(--up-collected); }
.daily__bar--invoiced { background: var(--up-accent); }

.daily__label {
  font-size: 0.62rem;
  color: var(--up-faint);
  white-space: nowrap;
}

@media (max-width: 720px) {
  .up__toolbar {
    flex-direction: column;
    align-items: stretch;
  }

  .up__search {
    max-width: none;
  }

  .chart {
    grid-template-columns: 1fr;
  }

  .hbar__axis {
    margin-left: 0;
  }

  .hbar__row {
    grid-template-columns: 1fr;
  }
}
</style>
