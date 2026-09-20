<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { ForecastsReport } from '../../../types'
import { formatMoney } from '../../../utils/format'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<ForecastsReport | null>(null)
const storeId = ref(context.currentStoreId ?? '')
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    report.value = await store.loadForecastsReport({
      store_id: storeId.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

const nextMonth = computed(() => report.value?.next_month_forecast ?? 0)
const sixMonth = computed(() => report.value?.six_month_forecast ?? 0)
const avgGrowth = computed(() => report.value?.avg_monthly_growth ?? 0)
const confidence = computed(() => report.value?.confidence_level ?? 80)
const bandPct = computed(() => report.value?.confidence_band_pct ?? 20)

const series = computed(() => report.value?.series ?? [])
const chartMax = computed(() => {
  const values = series.value.flatMap((row) => [
    row.actual ?? 0,
    row.forecast ?? 0,
    row.upper ?? 0,
  ])
  return Math.max(1, ...values)
})

const monthlyGrowth = computed(() => report.value?.monthly_growth ?? [])
const growthAbsMax = computed(() => Math.max(1, ...monthlyGrowth.value.map(r => Math.abs(r.rate))))

const growingProducts = computed(() => report.value?.growing_products ?? [])
const hasGrowthData = computed(() => report.value?.has_growth_data ?? false)
const forecastTable = computed(() => report.value?.forecast_table ?? [])
const insights = computed(() => report.value?.insights ?? {
  trajectory: 'stable',
  demand_next_month: 0,
  cashflow: 'hard',
  six_month_forecast: 0,
})

function shortMonth(label: string) {
  const [year, month] = label.split('-')
  if (!year || !month) return label
  try {
    return new Date(Number(year), Number(month) - 1, 1).toLocaleDateString(locale.value, { month: 'short' })
  } catch {
    return label
  }
}

function barHeight(value: number | null | undefined) {
  return `${Math.max(2, ((value ?? 0) / chartMax.value) * 100)}%`
}

onMounted(() => {
  load()
})
</script>

<template>
  <ReportsLayout>
    <div class="forecast">
      <div class="forecast__toolbar">
        <div class="forecast__filters">
          <select v-model="storeId" class="field" @change="load">
            <option value="">{{ t('org.allStores') }}</option>
            <option v-for="s in context.activeStores" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <button type="button" class="btn-secondary" :disabled="loading" @click="load">
          <AppIcon name="import" :size="15" />
          {{ t('common.refresh') }}
        </button>
      </div>

      <div class="forecast__kpis">
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.forecastAnalytics.nextMonth') }}</p>
          <p class="kpi__value">{{ formatMoney(nextMonth) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.forecastAnalytics.sixMonth') }}</p>
          <p class="kpi__value">{{ formatMoney(sixMonth) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.forecastAnalytics.avgGrowth') }}</p>
          <p class="kpi__value" :class="{ 'is-up': avgGrowth > 0, 'is-down': avgGrowth < 0 }">
            {{ avgGrowth }}%
          </p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.forecastAnalytics.confidence') }}</p>
          <p class="kpi__value">{{ confidence }}%</p>
          <p class="kpi__meta">±{{ bandPct }}% {{ t('reports.forecastAnalytics.band') }}</p>
        </article>
      </div>

      <section class="panel">
        <header class="panel__header">
          <h3 class="panel__title">{{ t('reports.forecastAnalytics.revenueForecast') }}</h3>
          <div class="legend">
            <span class="legend__item"><i class="dot dot--actual" />{{ t('reports.forecastAnalytics.actual') }}</span>
            <span class="legend__item"><i class="dot dot--forecast" />{{ t('reports.forecastAnalytics.forecast') }}</span>
            <span class="legend__item"><i class="dot dot--band" />{{ t('reports.forecastAnalytics.confidenceBand') }}</span>
          </div>
        </header>
        <div class="legend legend--sub">
          <span>{{ t('reports.forecastAnalytics.lowerBound') }}</span>
          <span>{{ t('reports.forecastAnalytics.upperBound') }}</span>
          <span>{{ t('reports.forecastAnalytics.forecast') }}</span>
          <span>{{ t('reports.forecastAnalytics.actualRevenue') }}</span>
        </div>
        <div v-if="series.length" class="combo">
          <div
            v-for="row in series"
            :key="row.label"
            class="combo__col"
            :title="`${row.label}`"
          >
            <div class="combo__bars">
              <div
                v-if="row.upper != null"
                class="combo__band"
                :style="{ height: barHeight(row.upper) }"
              >
                <div
                  class="combo__band-inner"
                  :style="{ height: `${row.upper ? ((row.upper - (row.lower ?? 0)) / row.upper) * 100 : 0}%` }"
                />
              </div>
              <div
                v-if="row.actual != null"
                class="combo__bar combo__bar--actual"
                :style="{ height: barHeight(row.actual) }"
              />
              <div
                v-if="row.forecast != null"
                class="combo__bar combo__bar--forecast"
                :style="{ height: barHeight(row.forecast) }"
              />
            </div>
            <span class="combo__label">{{ shortMonth(row.label) }}</span>
          </div>
        </div>
        <p v-else class="panel__empty">{{ t('org.empty') }}</p>
      </section>

      <div class="forecast__grid">
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.forecastAnalytics.monthlyGrowthRate') }}</h3>
          </header>
          <div v-if="monthlyGrowth.length" class="growth">
            <div
              v-for="row in monthlyGrowth"
              :key="row.label"
              class="growth__col"
              :title="`${row.label}: ${row.rate}%`"
            >
              <div class="growth__track">
                <div
                  class="growth__bar"
                  :class="{ 'is-neg': row.rate < 0 }"
                  :style="{ height: `${Math.max(4, (Math.abs(row.rate) / growthAbsMax) * 100)}%` }"
                />
              </div>
              <span class="growth__label">{{ shortMonth(row.label) }}</span>
              <span class="growth__rate">{{ row.rate }}%</span>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.forecastAnalytics.topGrowingProducts') }}</h3>
          </header>
          <div v-if="hasGrowthData && growingProducts.length" class="bar-list">
            <div v-for="row in growingProducts" :key="row.label" class="bar-list__row">
              <div class="bar-list__meta">
                <span>{{ row.label }}</span>
                <strong :class="{ 'is-up': row.growth > 0, 'is-down': row.growth < 0 }">
                  {{ row.growth }}%
                </strong>
              </div>
              <p class="bar-list__sub">
                {{ formatMoney(row.previous) }} → {{ formatMoney(row.current) }}
              </p>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('reports.forecastAnalytics.needTwoMonths') }}</p>
        </section>
      </div>

      <section class="panel">
        <header class="panel__header">
          <h3 class="panel__title">
            <AppIcon name="sparkles" :size="16" />
            {{ t('reports.forecastAnalytics.aiInsights') }}
          </h3>
        </header>
        <div class="insights">
          <article class="insight">
            <h4>{{ t('reports.forecastAnalytics.trajectoryTitle') }}</h4>
            <p>{{ t(`reports.forecastAnalytics.trajectory.${insights.trajectory}`) }}</p>
          </article>
          <article class="insight">
            <h4>{{ t('reports.forecastAnalytics.demandTitle') }}</h4>
            <p>
              {{ t('reports.forecastAnalytics.demandBody', { amount: formatMoney(insights.demand_next_month) }) }}
            </p>
          </article>
          <article class="insight">
            <h4>{{ t('reports.forecastAnalytics.cashflowTitle') }}</h4>
            <p>
              {{ t(`reports.forecastAnalytics.cashflow.${insights.cashflow}`, {
                amount: formatMoney(insights.six_month_forecast),
              }) }}
            </p>
          </article>
        </div>
      </section>

      <section class="panel panel--table">
        <header class="panel__header">
          <h3 class="panel__title">{{ t('reports.forecastAnalytics.sixMonthTable') }}</h3>
        </header>
        <table v-if="forecastTable.length" class="table">
          <thead>
            <tr>
              <th>{{ t('reports.forecastAnalytics.month') }}</th>
              <th class="text-right">{{ t('reports.forecastAnalytics.forecastRevenue') }}</th>
              <th class="text-right">{{ t('reports.forecastAnalytics.lower80') }}</th>
              <th class="text-right">{{ t('reports.forecastAnalytics.upper120') }}</th>
              <th class="text-right">{{ t('reports.forecastAnalytics.range') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in forecastTable" :key="row.label">
              <td>{{ shortMonth(row.label) }}</td>
              <td class="text-right">{{ formatMoney(row.forecast) }}</td>
              <td class="text-right">{{ formatMoney(row.lower) }}</td>
              <td class="text-right">{{ formatMoney(row.upper) }}</td>
              <td class="text-right">{{ formatMoney(row.range) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="panel__empty">{{ t('org.empty') }}</p>
      </section>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.forecast {
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
}

.forecast__toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.forecast__filters {
  display: flex;
  gap: 0.65rem;
}

.field {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
  min-width: 10rem;
  background: white;
}

.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 0.55rem;
  padding: 0.5rem 0.9rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid #cbd5e1;
  background: white;
  color: #334155;
}

.btn-secondary:disabled {
  opacity: 0.6;
  cursor: wait;
}

.forecast__kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.85rem;
}

@media (max-width: 1100px) {
  .forecast__kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .forecast__kpis {
    grid-template-columns: 1fr;
  }
}

.kpi {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.05rem;
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
  margin: 0.45rem 0 0;
  font-size: 1.35rem;
  font-weight: 700;
  color: #0f172a;
}

.kpi__value.is-up { color: #059669; }
.kpi__value.is-down { color: #dc2626; }

.kpi__meta {
  margin: 0.3rem 0 0;
  font-size: 0.8rem;
  color: #94a3b8;
}

.forecast__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

@media (max-width: 900px) {
  .forecast__grid {
    grid-template-columns: 1fr;
  }
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.1rem 1.15rem;
  min-height: 180px;
}

.panel--table {
  overflow: auto;
}

.panel__header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.85rem;
}

.panel__title {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
}

.panel__empty {
  margin: 2rem 0 0;
  text-align: center;
  color: #94a3b8;
  font-size: 0.9rem;
}

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  font-size: 0.78rem;
  color: #64748b;
}

.legend--sub {
  margin: -0.35rem 0 0.85rem;
  gap: 1rem;
  color: #94a3b8;
}

.legend__item {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.dot {
  display: inline-block;
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 999px;
}

.dot--actual { background: #2563eb; }
.dot--forecast { background: #7c3aed; }
.dot--band { background: #c4b5fd; }

.combo {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(2.2rem, 1fr));
  gap: 0.4rem;
  align-items: end;
  min-height: 200px;
}

.combo__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.4rem;
  min-width: 0;
}

.combo__bars {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 0.15rem;
  height: 160px;
  width: 100%;
}

.combo__band {
  position: absolute;
  bottom: 0;
  width: 70%;
  max-width: 1.6rem;
  display: flex;
  align-items: flex-end;
  pointer-events: none;
}

.combo__band-inner {
  width: 100%;
  border-radius: 0.35rem;
  background: rgba(167, 139, 250, 0.28);
}

.combo__bar {
  width: 0.5rem;
  border-radius: 0.35rem 0.35rem 0.15rem 0.15rem;
  min-height: 2px;
  position: relative;
  z-index: 1;
}

.combo__bar--actual { background: #2563eb; }
.combo__bar--forecast { background: #7c3aed; }

.combo__label {
  font-size: 0.68rem;
  color: #94a3b8;
  text-transform: capitalize;
}

.growth {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(2.4rem, 1fr));
  gap: 0.4rem;
  align-items: end;
  min-height: 160px;
}

.growth__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.growth__track {
  height: 110px;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.growth__bar {
  width: 0.7rem;
  border-radius: 0.35rem 0.35rem 0.15rem 0.15rem;
  background: #059669;
  min-height: 4px;
}

.growth__bar.is-neg {
  background: #dc2626;
}

.growth__label {
  font-size: 0.68rem;
  color: #94a3b8;
  text-transform: capitalize;
}

.growth__rate {
  font-size: 0.68rem;
  color: #64748b;
  font-weight: 600;
}

.bar-list {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.bar-list__row {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.bar-list__meta {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.85rem;
  color: #334155;
}

.bar-list__sub {
  margin: 0;
  font-size: 0.75rem;
  color: #94a3b8;
}

.is-up { color: #059669; }
.is-down { color: #dc2626; }

.insights {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.85rem;
}

@media (max-width: 900px) {
  .insights {
    grid-template-columns: 1fr;
  }
}

.insight {
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #ffffff;
  padding: 0.9rem 1rem;
}

.insight h4 {
  margin: 0 0 0.45rem;
  font-size: 0.88rem;
  color: #5b21b6;
}

.insight p {
  margin: 0;
  font-size: 0.88rem;
  line-height: 1.45;
  color: #475569;
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.table th,
.table td {
  padding: 0.7rem 0.55rem;
  border-bottom: 1px solid #e2e8f0;
  text-align: left;
}

.table th {
  color: #64748b;
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.text-right {
  text-align: right;
}
</style>
