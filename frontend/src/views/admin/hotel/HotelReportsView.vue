<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { formatMoney } from '../../../utils/money'
import {
  buildHotelReport,
  lastDaysRange,
  type HotelDoc,
  type HotelReport,
} from '../../../utils/hotelReport'
import { useContextStore } from '../../../stores/context'
import HotelChrome from './HotelChrome.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'

const { t, locale } = useI18n()
const ctx = useContextStore()

const docs = ref<HotelDoc[]>([])
const loading = ref(false)
const error = ref('')
const from = ref('')
const to = ref('')

const range = lastDaysRange(31)
from.value = range.from
to.value = range.to

const report = computed<HotelReport>(() => buildHotelReport(docs.value, from.value, to.value))

const pct = computed(() =>
  new Intl.NumberFormat(locale.value, { style: 'percent', maximumFractionDigits: 1 }).format(report.value.occupancyToday),
)

const avgStay = computed(() =>
  new Intl.NumberFormat(locale.value, { maximumFractionDigits: 1 }).format(report.value.avgStayNights || 0),
)

const maxDaily = computed(() => Math.max(0, ...report.value.daily.map(d => d.cents)))
const maxMonthly = computed(() => Math.max(0, ...report.value.monthly.map(d => d.cents)))
const maxHk = computed(() => Math.max(0, ...report.value.hk.map(d => d.count)))
const maxType = computed(() => Math.max(1, ...report.value.byType.map(d => d.cents)))
const hkRows = computed(() => {
  const rows = report.value.hk.filter(row => row.count > 0)
  return rows.length ? rows : report.value.hk
})
const dailyMaxNice = computed(() => niceCeiling(maxDaily.value))
const monthlyMaxNice = computed(() => niceCeiling(maxMonthly.value))
const hkMaxNice = computed(() => niceIntCeiling(maxHk.value))
const occMaxNice = computed(() => {
  const max = Math.max(0, ...report.value.monthly.map(d => d.occupancy))
  return niceCeiling(Math.max(max * 100, 16), 4) / 100
})

const donut = computed(() => {
  const total = Math.max(1, report.value.roomCount)
  const occ = report.value.occupiedToday
  const r = 42
  const c = 2 * Math.PI * r
  const occLen = (occ / total) * c
  return { r, c, occLen, availLen: c - occLen }
})

const dailyTicks = computed(() => {
  const rows = report.value.daily
  if (rows.length <= 6) return rows.map(d => d.date)
  const last = rows.length - 1
  return [...new Set([0, Math.round(last / 3), Math.round((2 * last) / 3), last])].map(i => rows[i].date)
})

const yTicks = computed(() => ticks(dailyMaxNice.value))
const monthlyTicks = computed(() => ticks(monthlyMaxNice.value))
const hkTicks = computed(() => ticks(hkMaxNice.value))
const occTicks = computed(() => ticks(occMaxNice.value))

function niceCeiling(value: number, steps = 4): number {
  if (value <= 0) return steps * 100
  const raw = value / steps
  const mag = 10 ** Math.floor(Math.log10(raw))
  const unit = [1, 2, 2.5, 5, 10].map(n => n * mag).find(n => n >= raw) ?? mag * 10
  return unit * steps
}

function niceIntCeiling(value: number, steps = 4): number {
  if (value <= 0) return steps
  const raw = Math.max(1, Math.ceil(value / steps))
  const step = raw <= 5 ? raw : Math.ceil(raw / 5) * 5
  return step * steps
}

function ticks(max: number, steps = 4): number[] {
  return Array.from({ length: steps + 1 }, (_, i) => (max / steps) * i)
}

function axisAmount(cents: number) {
  return new Intl.NumberFormat(locale.value, { maximumFractionDigits: 0 }).format(Math.round(cents / 100))
}

function axisPct(value: number) {
  return new Intl.NumberFormat(locale.value, { style: 'percent', maximumFractionDigits: 0 }).format(value)
}

const monthlyLine = computed(() => {
  const rows = report.value.monthly
  if (!rows.length) return ''
  const w = 100
  const h = 100
  const step = rows.length > 1 ? w / (rows.length - 1) : 0
  return rows
    .map((row, i) => {
      const x = i * step
      const y = h - (row.occupancy / occMaxNice.value) * h
      return `${i === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)}`
    })
    .join(' ')
})

onMounted(load)
watch(() => ctx.currentStoreId, () => { load() })

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: HotelDoc[] } }>('/hospitality')).data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function last30() {
  const next = lastDaysRange(31)
  from.value = next.from
  to.value = next.to
}

function money(cents: number) {
  return formatMoney(cents)
}

function dayLabel(iso: string) {
  return iso
}

function hkLabel(id: string) {
  return t(`hotel.housekeeping.conditions.${id}`)
}

function exportCsv() {
  const r = report.value
  const lines = [
    ['kpi', 'value'],
    ['from', r.from],
    ['to', r.to],
    ['occupancy_today', pct.value],
    ['occupied_rooms', String(r.occupiedToday)],
    ['available_rooms', String(r.availableToday)],
    ['rooms', String(r.roomCount)],
    ['revpar_cents', String(r.revparCents)],
    ['revenue_cents', String(r.revenueCents)],
    ['adr_cents', String(r.adrCents)],
    ['stays', String(r.stayCount)],
    ['room_nights', String(r.roomNights)],
    ['avg_stay_nights', avgStay.value],
    ['open_hk_tasks', String(r.openHkTasks)],
    ['reservations_total', String(r.reservations.total)],
    ['reservations_confirmed', String(r.reservations.confirmed)],
    ['reservations_pending', String(r.reservations.pending)],
    ['reservations_cancelled', String(r.reservations.cancelled)],
    [],
    ['date', 'revenue_cents'],
    ...r.daily.map(d => [d.date, String(d.cents)]),
    [],
    ['room_type', 'revenue_cents', 'stays'],
    ...r.byType.map(d => [d.name, String(d.cents), String(d.stays)]),
  ]
  const csv = lines.map(row => row.map(cell => `"${String(cell).replaceAll('"', '""')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `hotel-report-${r.from}-${r.to}.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<template>
  <HotelChrome scroll-body>
    <div class="rpt">
      <header class="rpt__head">
        <div>
          <h2>{{ t('hotel.reports.title') }}</h2>
          <p>{{ t('hotel.reports.subtitle') }}</p>
        </div>
        <div class="rpt__tools">
          <label>
            {{ t('hotel.reports.period') }}
            <span class="rpt__range">
              <input v-model="from" type="date" class="field">
              <span>→</span>
              <input v-model="to" type="date" class="field">
            </span>
          </label>
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">{{ t('common.refresh') }}</button>
          <button type="button" class="btn-secondary" @click="exportCsv">{{ t('hotel.reports.export') }}</button>
          <button type="button" class="btn-primary" @click="last30">{{ t('hotel.reports.last30') }}</button>
        </div>
      </header>

      <p v-if="error" class="rpt__error">{{ error }}</p>
      <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />

      <section class="rpt__kpis">
        <article class="kpi">
          <p class="kpi__label">{{ t('hotel.reports.occupancy') }}</p>
          <p class="kpi__value">{{ pct }}</p>
          <p class="kpi__hint">{{ t('hotel.reports.occupancyHint', { occupied: report.occupiedToday, total: report.roomCount }) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('hotel.reports.revpar') }}</p>
          <p class="kpi__value">{{ money(report.revparCents) }}</p>
          <p class="kpi__hint">{{ t('hotel.reports.revparHint') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('hotel.reports.revenue') }}</p>
          <p class="kpi__value">{{ money(report.revenueCents) }}</p>
          <p class="kpi__hint">{{ t('hotel.reports.revenueHint', { count: report.stayCount }) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('hotel.reports.adr') }}</p>
          <p class="kpi__value">{{ money(report.adrCents) }}</p>
          <p class="kpi__hint">{{ t('hotel.reports.adrHint') }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('hotel.reports.los') }}</p>
          <p class="kpi__value">{{ avgStay }} {{ t('hotel.reports.nightsUnit') }}</p>
          <p class="kpi__hint">{{ t('hotel.reports.losHint', { nights: report.roomNights }) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('hotel.reports.hkOpen') }}</p>
          <p class="kpi__value">{{ report.openHkTasks }}</p>
          <p class="kpi__hint">{{ t('hotel.reports.hkOpenHint') }}</p>
        </article>
      </section>

      <div class="rpt__grid">
        <section class="panel panel--wide">
          <header class="panel__head">
            <div>
              <h3>{{ t('hotel.reports.dailyTitle') }}</h3>
              <p>{{ t('hotel.reports.dailyHint') }}</p>
            </div>
          </header>
          <div class="bars">
            <div class="bars__y">
              <span v-for="tick in [...yTicks].reverse()" :key="tick">{{ axisAmount(tick) }}</span>
            </div>
            <div class="bars__plot">
              <div
                v-for="row in report.daily"
                :key="row.date"
                class="bars__col"
                :title="`${row.date} — ${money(row.cents)}`"
              >
                <div class="bars__track">
                  <div class="bars__fill" :style="{ height: `${Math.max(row.cents ? 4 : 0, (row.cents / dailyMaxNice) * 100)}%` }" />
                </div>
              </div>
            </div>
          </div>
          <div class="bars__x">
            <span v-for="tick in dailyTicks" :key="tick">{{ dayLabel(tick) }}</span>
          </div>
        </section>

        <section class="panel panel--third">
          <header class="panel__head">
            <div>
              <h3>{{ t('hotel.reports.availabilityTitle') }}</h3>
              <p>{{ t('hotel.reports.availabilityHint') }}</p>
            </div>
          </header>
          <div class="donut">
            <svg viewBox="0 0 120 120" aria-hidden="true">
              <circle cx="60" cy="60" :r="donut.r" fill="none" stroke="#e2e8f0" stroke-width="16" />
              <circle
                cx="60"
                cy="60"
                :r="donut.r"
                fill="none"
                stroke="#0f766e"
                stroke-width="16"
                stroke-linecap="butt"
                :stroke-dasharray="`${donut.occLen} ${donut.c}`"
                transform="rotate(-90 60 60)"
              />
            </svg>
            <ul>
              <li>
                <span class="swatch swatch--occ" />
                {{ t('hotel.reports.occupied') }}
                <strong>{{ report.occupiedToday }}</strong>
              </li>
              <li>
                <span class="swatch swatch--avail" />
                {{ t('hotel.reports.available') }}
                <strong>{{ report.availableToday }}</strong>
              </li>
            </ul>
          </div>
        </section>

        <section class="panel panel--third">
          <header class="panel__head">
            <div>
              <h3>{{ t('hotel.reports.hkTitle') }}</h3>
              <p>{{ t('hotel.reports.hkHint') }}</p>
            </div>
          </header>
          <div class="bars bars--hk">
            <div class="bars__y">
              <span v-for="tick in [...hkTicks].reverse()" :key="tick">{{ Math.round(tick) }}</span>
            </div>
            <div class="bars__plot">
              <div
                v-for="row in hkRows"
                :key="row.id"
                class="bars__col"
                :title="`${hkLabel(row.id)} — ${row.count}`"
              >
                <div class="bars__track">
                  <div
                    class="bars__fill"
                    :class="`bars__fill--${row.id}`"
                    :style="{ height: `${Math.max(row.count ? 6 : 0, (row.count / hkMaxNice) * 100)}%` }"
                  />
                </div>
              </div>
            </div>
          </div>
          <div class="bars__x bars__x--hk">
            <span v-for="row in hkRows" :key="row.id">{{ hkLabel(row.id) }}</span>
          </div>
        </section>

        <section class="panel panel--third">
          <header class="panel__head">
            <div>
              <h3>{{ t('hotel.reports.resTitle') }}</h3>
              <p>{{ t('hotel.reports.resHint') }}</p>
            </div>
          </header>
          <div class="res-grid">
            <div>
              <strong>{{ report.reservations.total }}</strong>
              <span>{{ t('hotel.reports.resTotal') }}</span>
            </div>
            <div>
              <strong>{{ report.reservations.confirmed }}</strong>
              <span>{{ t('hotel.reports.resConfirmed') }}</span>
            </div>
            <div>
              <strong>{{ report.reservations.pending }}</strong>
              <span>{{ t('hotel.reports.resPending') }}</span>
            </div>
            <div>
              <strong>{{ report.reservations.cancelled }}</strong>
              <span>{{ t('hotel.reports.resCancelled') }}</span>
            </div>
          </div>
        </section>

        <section class="panel panel--type">
          <header class="panel__head">
            <div>
              <h3>{{ t('hotel.reports.typeTitle') }}</h3>
              <p>{{ t('hotel.reports.typeHint') }}</p>
            </div>
          </header>
          <ul v-if="report.byType.length" class="types">
            <li v-for="row in report.byType" :key="row.id">
              <div class="types__row">
                <strong>{{ row.name }}</strong>
                <span>{{ money(row.cents) }}</span>
              </div>
              <div class="types__bar">
                <div :style="{ width: `${(row.cents / maxType) * 100}%` }" />
              </div>
              <small>{{ t('hotel.reports.typeStays', { count: row.stays }) }}</small>
            </li>
          </ul>
          <p v-else class="rpt__muted">{{ t('hotel.reports.noTypes') }}</p>
        </section>

        <section class="panel panel--trend">
          <header class="panel__head">
            <div>
              <h3>{{ t('hotel.reports.trendTitle') }}</h3>
              <p>{{ t('hotel.reports.trendHint') }}</p>
            </div>
          </header>
          <div class="trend">
            <div class="trend__frame">
              <div class="bars__y">
                <span v-for="tick in [...monthlyTicks].reverse()" :key="`r-${tick}`">{{ axisAmount(tick) }}</span>
              </div>
              <div class="trend__plot">
                <div
                  v-for="row in report.monthly"
                  :key="row.key"
                  class="trend__col"
                  :title="`${row.label} — ${money(row.cents)} / ${axisPct(row.occupancy)}`"
                >
                  <div class="trend__track">
                    <div class="trend__fill" :style="{ height: `${(row.cents / monthlyMaxNice) * 100}%` }" />
                  </div>
                </div>
                <svg class="trend__line" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
                  <path :d="monthlyLine" fill="none" stroke="#d97706" stroke-width="1.8" vector-effect="non-scaling-stroke" />
                </svg>
              </div>
              <div class="bars__y bars__y--right">
                <span v-for="tick in [...occTicks].reverse()" :key="`o-${tick}`">{{ axisPct(tick) }}</span>
              </div>
            </div>
            <div class="trend__x">
              <span v-for="row in report.monthly" :key="row.key">{{ row.label }}</span>
            </div>
            <div class="trend__legend">
              <span><i class="swatch swatch--rev" /> {{ t('hotel.reports.revenue') }}</span>
              <span><i class="swatch swatch--occ-line" /> {{ t('hotel.reports.occupancyPct') }}</span>
            </div>
          </div>
        </section>
      </div>

      <section class="rpt__foot">
        <div>
          <strong>{{ report.stayCount }}</strong>
          <span>{{ t('hotel.tabs.stays') }}</span>
        </div>
        <div>
          <strong>{{ report.roomNights }}</strong>
          <span>{{ t('hotel.reports.nights') }}</span>
        </div>
        <div>
          <strong>{{ report.roomCount }}</strong>
          <span>{{ t('hotel.tabs.rooms') }}</span>
        </div>
        <div>
          <strong>{{ report.reservations.total }}</strong>
          <span>{{ t('hotel.reports.resTotal') }}</span>
        </div>
      </section>
    </div>
  </HotelChrome>
</template>

<style scoped>
.rpt { display: flex; flex-direction: column; gap: 1rem; padding-bottom: 1.2rem; }
.rpt__head {
  display: flex; flex-wrap: wrap; justify-content: space-between; gap: 1rem;
  padding: 1.1rem 1.2rem; border: 1px solid #d7e2ea; border-radius: 0.9rem; background: #fff;
}
.rpt__head h2 { margin: 0; font-size: 1.15rem; color: #1c2830; }
.rpt__head p { margin: 0.3rem 0 0; color: #66727c; font-size: 0.875rem; }
.rpt__tools { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 0.5rem; }
.rpt__tools label { display: flex; flex-direction: column; gap: 0.25rem; font-size: 0.75rem; font-weight: 650; color: #64748b; }
.rpt__range { display: flex; align-items: center; gap: 0.35rem; }
.rpt__range .field { min-width: 9.5rem; }
.rpt__error { margin: 0; padding: 0.7rem 0.85rem; border-radius: 0.7rem; background: #fef2f2; color: #b91c1c; font-size: 0.85rem; }
.rpt__muted { margin: 0; color: #7b8d9a; font-size: 0.85rem; text-align: center; padding: 0.8rem; }

.rpt__kpis { display: grid; gap: 0.75rem; grid-template-columns: repeat(auto-fit, minmax(11.5rem, 1fr)); }
.kpi { padding: 0.95rem 1rem; border: 1px solid #d7e2ea; border-radius: 0.85rem; background: #fff; }
.kpi__label { margin: 0; font-size: 0.75rem; font-weight: 650; color: #64748b; }
.kpi__value { margin: 0.35rem 0 0; font-size: 1.35rem; font-weight: 750; color: #1c2830; letter-spacing: -0.02em; }
.kpi__hint { margin: 0.25rem 0 0; font-size: 0.75rem; color: #7b8d9a; }

.rpt__grid { display: grid; gap: 0.85rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rpt__grid { grid-template-columns: 1fr 1fr; }
  .panel--wide { grid-column: 1 / -1; }
}
@media (min-width: 1100px) {
  .rpt__grid { grid-template-columns: repeat(6, minmax(0, 1fr)); }
  .panel--wide { grid-column: 1 / -1; }
  .panel--third { grid-column: span 2; }
  .panel--type { grid-column: span 2; }
  .panel--trend { grid-column: span 4; }
}
.panel { padding: 1rem 1.1rem 1.15rem; border: 1px solid #d7e2ea; border-radius: 0.9rem; background: #fff; min-width: 0; }
.panel__head h3 { margin: 0; font-size: 0.95rem; color: #1c2830; }
.panel__head p { margin: 0.2rem 0 0.85rem; font-size: 0.78rem; color: #7b8d9a; }

.bars { display: grid; grid-template-columns: 4.4rem 1fr; gap: 0.4rem; min-height: 12rem; }
.bars--hk { min-height: 10.5rem; grid-template-columns: 2.2rem 1fr; }
.bars__y { display: flex; flex-direction: column; justify-content: space-between; font-size: 0.68rem; color: #94a3b8; text-align: right; padding-right: 0.25rem; }
.bars__y--right { text-align: left; padding-right: 0; padding-left: 0.25rem; }
.bars__plot { display: flex; align-items: stretch; gap: 0.12rem; border-bottom: 1px solid #e8eef3; padding-bottom: 0.2rem; }
.bars--hk .bars__plot { gap: 0.55rem; padding: 0 0.6rem; }
.bars__col { flex: 1; display: flex; }
.bars__track { flex: 1; display: flex; align-items: flex-end; background: #f8fafc; }
.bars__fill { width: 100%; background: var(--color-brand-600); border-radius: 0.2rem 0.2rem 0 0; min-height: 0; }
.bars__fill--clean { background: #059669; }
.bars__fill--inspected { background: #2563eb; }
.bars__fill--dirty { background: #d97706; }
.bars__fill--cleaning { background: #0e7490; }
.bars__fill--maintenance { background: #7c3aed; }
.bars__fill--out_of_service { background: #94a3b8; }
.bars__x { display: flex; justify-content: space-between; margin: 0.35rem 0 0 4.4rem; font-size: 0.7rem; color: #7b8d9a; }
.bars__x--hk { margin-left: 2.2rem; gap: 0.4rem; }
.bars__x--hk span { flex: 1; text-align: center; }

.donut { display: flex; align-items: center; gap: 1.1rem; }
.donut svg { width: 8.2rem; height: 8.2rem; flex-shrink: 0; }
.donut ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.55rem; }
.donut li { display: flex; align-items: center; gap: 0.45rem; font-size: 0.85rem; color: #475569; }
.donut strong { margin-left: auto; font-size: 1.05rem; color: #1c2830; }
.swatch { width: 0.7rem; height: 0.7rem; border-radius: 999px; display: inline-block; }
.swatch--occ { background: #0f766e; }
.swatch--avail { background: #cbd5e1; }
.swatch--rev { background: var(--color-brand-600); }
.swatch--occ-line { background: #d97706; }

.res-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.7rem; }
.res-grid div { padding: 0.7rem 0.8rem; border-radius: 0.7rem; background: #f8fafc; border: 1px solid #e8eef3; }
.res-grid strong { display: block; font-size: 1.25rem; color: #1c2830; }
.res-grid span { font-size: 0.75rem; color: #7b8d9a; }

.types { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.75rem; }
.types__row { display: flex; justify-content: space-between; gap: 0.6rem; font-size: 0.85rem; }
.types__bar { height: 0.45rem; background: #eef2f6; border-radius: 999px; overflow: hidden; margin: 0.3rem 0 0.15rem; }
.types__bar div { height: 100%; background: #0f766e; }
.types small { color: #7b8d9a; font-size: 0.72rem; }

.trend__frame { display: grid; grid-template-columns: 4.4rem 1fr 2.6rem; gap: 0.35rem; min-height: 11rem; }
.trend__plot { position: relative; display: flex; align-items: stretch; gap: 0.45rem; min-height: 11rem; border-bottom: 1px solid #e8eef3; }
.trend__col { flex: 1; display: flex; flex-direction: column; align-items: center; }
.trend__track { width: 100%; flex: 1; display: flex; align-items: flex-end; background: #f8fafc; border-radius: 0.3rem 0.3rem 0 0; }
.trend__fill { width: 70%; margin: 0 auto; background: var(--color-brand-600); border-radius: 0.25rem 0.25rem 0 0; min-height: 0; }
.trend__line { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; overflow: visible; }
.trend__x { display: flex; margin: 0.35rem 2.6rem 0 4.4rem; font-size: 0.7rem; color: #7b8d9a; }
.trend__x span { flex: 1; text-align: center; }
.trend__legend { display: flex; gap: 1rem; margin-top: 0.7rem; font-size: 0.75rem; color: #64748b; }
.trend__legend i { margin-right: 0.3rem; }

.rpt__foot {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.65rem;
}
@media (min-width: 720px) {
  .rpt__foot { grid-template-columns: repeat(4, 1fr); }
}
.rpt__foot div { padding: 0.85rem 1rem; border: 1px solid #d7e2ea; border-radius: 0.85rem; background: #fff; }
.rpt__foot strong { display: block; font-size: 1.35rem; color: #1c2830; }
.rpt__foot span { font-size: 0.78rem; color: #7b8d9a; }
</style>
