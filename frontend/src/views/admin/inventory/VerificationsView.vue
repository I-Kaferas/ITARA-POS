<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import WarehouseOptions from '../../../components/inventory/WarehouseOptions.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Warehouse } from '../../../types'
import { formatDateTime } from '../../../utils/format'

type Dashboard = {
  due_today: number
  overdue: number
  open_anomalies: number
  critical_products: number
  reliability: number
  at_risk: Array<{ product_id: string; name?: string | null; score: number; grade: string }>
}

type Finding = {
  id: string
  title: string
  severity: string
  status: string
  expected_value?: string | null
  actual_value?: string | null
  product?: { id: string; name: string; sku?: string | null } | null
}

type Run = {
  id: string
  reference: string
  status: string
  created_at?: string
  analyzed_at?: string | null
  findings_count?: number
  findings?: Finding[]
  performed_by?: { id: string; name: string } | null
  performedBy?: { id: string; name: string } | null
}

const { t } = useI18n()
const store = useBackofficeStore()
const warehouses = ref<Warehouse[]>([])
const warehouseId = ref('')
const loading = ref(false)
const running = ref(false)
const error = ref('')
const dashboard = ref<Dashboard | null>(null)
const runs = ref<Run[]>([])
const selected = ref<Run | null>(null)

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  warehouseId.value = warehouses.value[0]?.id ?? ''
})

watch(warehouseId, (id) => {
  if (id) void refresh()
})

async function refresh() {
  if (!warehouseId.value) return
  loading.value = true
  error.value = ''
  try {
    const query = `warehouse_id=${encodeURIComponent(warehouseId.value)}`
    const [board, history] = await Promise.all([
      api.get<{ data: Dashboard }>(`/inventory-verifications/dashboard?${query}`),
      api.get<{ data: Run[] }>(`/inventory-verifications/runs?${query}`),
    ])
    dashboard.value = board.data
    runs.value = history.data
    error.value = ''
    if (selected.value && !selected.value.findings) {
      const still = history.data.find((row) => row.id === selected.value?.id)
      selected.value = still ?? null
    }
  } catch (cause) {
    error.value = extractApiErrorMessage(cause, t('inventory.verification.loadError'))
  } finally {
    loading.value = false
  }
}

async function startRun() {
  if (!warehouseId.value || running.value) return
  running.value = true
  error.value = ''
  try {
    const created = await api.post<{ data: Run }>('/inventory-verifications/run', {
      warehouse_id: warehouseId.value,
    })
    selected.value = created.data
    await refresh()
  } catch (cause) {
    error.value = extractApiErrorMessage(cause, t('inventory.verification.loadError'))
  } finally {
    running.value = false
  }
}

async function openRun(run: Run) {
  const detail = await api.get<{ data: Run }>(`/inventory-verifications/runs/${run.id}`)
  selected.value = detail.data
  error.value = ''
}

async function resolveFinding(finding: Finding, status: 'justified' | 'corrected') {
  await api.post(`/inventory-verifications/findings/${finding.id}/resolve`, { status })
  if (selected.value) await openRun(selected.value)
  await refresh()
}

async function validateSelected() {
  if (!selected.value) return
  await api.post(`/inventory-verifications/runs/${selected.value.id}/validate`, {})
  await openRun(selected.value)
  await refresh()
}
</script>

<template>
  <InventoryLayout>
    <div class="verify">
      <div class="verify__bar">
        <p class="verify__lead">{{ t('inventory.verification.subtitle') }}</p>
        <div class="verify__actions">
          <WarehouseOptions v-model="warehouseId" :warehouses="warehouses" />
          <button type="button" class="ui-btn ui-btn--primary" :disabled="!warehouseId || running" @click="startRun">
            {{ running ? t('inventory.verification.running') : t('inventory.verification.run') }}
          </button>
        </div>
      </div>

      <p v-if="!warehouses.length" class="verify__empty">{{ t('inventory.verification.noWarehouse') }}</p>
      <p v-if="error" class="verify__error">{{ error }}</p>
      <LoadingBlock v-if="loading && !dashboard" />

      <template v-if="dashboard">
        <div class="verify__kpis">
          <KpiCard :label="t('inventory.verification.dueToday')" :value="dashboard.due_today" tone="amber" icon="calendar" />
          <KpiCard :label="t('inventory.verification.overdue')" :value="dashboard.overdue" tone="coral" icon="alert" />
          <KpiCard :label="t('inventory.verification.openAnomalies')" :value="dashboard.open_anomalies" tone="navy" icon="check" />
          <KpiCard :label="t('inventory.verification.critical')" :value="dashboard.critical_products" tone="pink" icon="package" />
          <KpiCard :label="t('inventory.verification.reliability')" :value="`${dashboard.reliability}`" tone="green" icon="dashboard" />
        </div>

        <section v-if="dashboard.at_risk.length" class="verify__panel">
          <h2>{{ t('inventory.verification.atRisk') }}</h2>
          <ul>
            <li v-for="row in dashboard.at_risk" :key="row.product_id">
              <span>{{ row.name || row.product_id }}</span>
              <strong>{{ row.score }}</strong>
            </li>
          </ul>
        </section>

        <section class="verify__panel">
          <h2>{{ t('inventory.verification.runs') }}</h2>
          <p v-if="!runs.length" class="verify__empty">{{ t('inventory.verification.emptyRuns') }}</p>
          <table v-else class="verify__table">
            <thead>
              <tr>
                <th>{{ t('inventory.verification.reference') }}</th>
                <th>{{ t('inventory.verification.status') }}</th>
                <th>{{ t('inventory.verification.findings') }}</th>
                <th>{{ t('inventory.verification.when') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="run in runs"
                :key="run.id"
                :class="{ 'is-selected': selected?.id === run.id }"
                @click="openRun(run)"
              >
                <td>{{ run.reference }}</td>
                <td>{{ run.status }}</td>
                <td>{{ run.findings_count ?? run.findings?.length ?? 0 }}</td>
                <td>{{ formatDateTime(run.analyzed_at || run.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </section>

        <section v-if="selected" class="verify__panel">
          <div class="verify__bar">
            <h2>{{ selected.reference }}</h2>
            <button
              v-if="selected.status !== 'validated'"
              type="button"
              class="ui-btn ui-btn--ghost"
              @click="validateSelected"
            >
              {{ t('inventory.verification.validate') }}
            </button>
          </div>
          <p v-if="!selected.findings?.length" class="verify__empty">{{ t('inventory.verification.emptyFindings') }}</p>
          <ul v-else class="verify__findings">
            <li v-for="finding in selected.findings" :key="finding.id">
              <div>
                <strong>{{ finding.product?.name || finding.title }}</strong>
                <p>{{ finding.title }}</p>
                <p class="verify__meta">
                  {{ t('inventory.verification.expected') }} {{ finding.expected_value || '—' }}
                  · {{ t('inventory.verification.actual') }} {{ finding.actual_value || '—' }}
                  · {{ finding.severity }} · {{ finding.status }}
                </p>
              </div>
              <div v-if="finding.status === 'open'" class="verify__actions">
                <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" @click="resolveFinding(finding, 'justified')">
                  {{ t('inventory.verification.justify') }}
                </button>
                <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" @click="resolveFinding(finding, 'corrected')">
                  {{ t('inventory.verification.correct') }}
                </button>
              </div>
            </li>
          </ul>
        </section>
      </template>
    </div>
  </InventoryLayout>
</template>

<style scoped>
.verify {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.verify__bar,
.verify__actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem;
  justify-content: space-between;
}

.verify__lead,
.verify__empty,
.verify__meta {
  margin: 0;
  color: var(--color-text-muted, #5c6b7a);
}

.verify__error {
  margin: 0;
  color: var(--color-danger, #9b2c2c);
}

.verify__kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 0.75rem;
}

.verify__panel {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  border: 1px solid var(--color-border, #e4e8ec);
  background: var(--color-surface, #fff);
}

.verify__panel h2 {
  margin: 0;
  font-size: 1rem;
}

.verify__panel ul {
  margin: 0;
  padding: 0;
  list-style: none;
}

.verify__panel li,
.verify__findings li {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.65rem 0;
  border-bottom: 1px solid var(--color-border, #e4e8ec);
}

.verify__table {
  width: 100%;
  border-collapse: collapse;
}

.verify__table th,
.verify__table td {
  padding: 0.55rem 0.4rem;
  text-align: left;
  border-bottom: 1px solid var(--color-border, #e4e8ec);
}

.verify__table tbody tr {
  cursor: pointer;
}

.verify__table tr.is-selected td {
  background: var(--color-surface-muted, #f4f6f8);
}
</style>
