<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import PageFrame from '../../../components/layout/PageFrame.vue'
import OrderSectionTabs from '../../../components/pos/OrderSectionTabs.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import { publishQrPendingCount } from '../../../composables/useQrPendingCount'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { useContextStore } from '../../../stores/context'
import { formatMoney } from '../../../utils/format'

type Item = {
  id: string
  product_id: string
  variant_id?: string | null
  sale_unit_id?: string | null
  name: string
  quantity: number
  note?: string | null
  line_total: number
  options?: { sides?: { id: string; name: string }[]; extras?: { id: string; name: string; quantity: number }[] }
}
type Order = {
  id: string
  guest_status: string
  rejection_reason?: string | null
  total: number
  tax_total: number
  currency: string
  created_at?: string
  table?: { id: string; name: string; code?: string } | null
  items: Item[]
}

const { t } = useI18n()
const context = useContextStore()
const storeId = computed(() => context.currentStoreId)
const orders = ref<Order[]>([])
const pending = ref(0)
const mode = ref<'manual' | 'automatic'>('manual')
const error = ref('')
const loading = ref(false)
const busy = ref('')
const reasonFor = ref<string | null>(null)
const reason = ref('')
const editing = ref<string | null>(null)
const draftQty = ref<Record<string, number>>({})

const currency = computed(() => orders.value[0]?.currency || context.currencyCode || 'BIF')
const queueTotal = computed(() => orders.value.reduce((sum, order) => sum + (order.total || 0), 0))
const tableCount = computed(() => new Set(orders.value.map(order => order.table?.id || order.id)).size)

async function load() {
  if (!storeId.value) return
  loading.value = orders.value.length === 0
  error.value = ''
  try {
    const res = await api.get<{ data: { pending_count: number; approval_mode: string; orders: Order[] } }>(
      `/stores/${storeId.value}/qr-orders?status=submitted`,
    )
    pending.value = res.data.pending_count
    publishQrPendingCount(res.data.pending_count)
    mode.value = res.data.approval_mode === 'automatic' ? 'automatic' : 'manual'
    orders.value = res.data.orders
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function approve(order: Order) {
  if (busy.value) return
  busy.value = order.id
  error.value = ''
  try {
    await api.post(`/qr-orders/${order.id}/approve`, {})
    if (editing.value === order.id) editing.value = null
    if (reasonFor.value === order.id) {
      reasonFor.value = null
      reason.value = ''
    }
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = ''
  }
}

async function reject(order: Order) {
  if (!reason.value.trim() || busy.value) return
  busy.value = order.id
  error.value = ''
  try {
    await api.post(`/qr-orders/${order.id}/reject`, { reason: reason.value.trim() })
    reasonFor.value = null
    reason.value = ''
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = ''
  }
}

function startEdit(order: Order) {
  editing.value = order.id
  reasonFor.value = null
  draftQty.value = Object.fromEntries(order.items.map(item => [item.id, item.quantity]))
}

function stopEdit() {
  editing.value = null
}

async function saveEdit(order: Order) {
  if (busy.value) return
  busy.value = order.id
  error.value = ''
  try {
    await api.patch(`/qr-orders/${order.id}`, {
      items: order.items.map(item => ({
        product_id: item.product_id,
        quantity: Math.max(1, draftQty.value[item.id] || item.quantity),
        note: item.note,
        variant_id: item.variant_id,
        sale_unit_id: item.sale_unit_id,
        side_ids: (item.options?.sides || []).map(side => side.id),
        extras: (item.options?.extras || []).map(extra => ({ product_id: extra.id, quantity: extra.quantity })),
      })),
    })
    editing.value = null
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = ''
  }
}

async function approveAll() {
  if (!storeId.value || !pending.value || busy.value) return
  busy.value = 'all'
  error.value = ''
  try {
    await api.post(`/stores/${storeId.value}/qr-orders/approve-all`, {})
    editing.value = null
    reasonFor.value = null
    reason.value = ''
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    busy.value = ''
  }
}

async function saveMode(next: 'manual' | 'automatic') {
  if (!storeId.value || mode.value === next || busy.value) return
  const previous = mode.value
  mode.value = next
  try {
    await api.patch(`/stores/${storeId.value}/qr-settings`, { mode: next })
  } catch (err) {
    mode.value = previous
    error.value = extractApiErrorMessage(err)
  }
}

function when(value?: string) {
  if (!value) return ''
  return new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit' }).format(new Date(value))
}

function detail(item: Item) {
  const sides = (item.options?.sides || []).map(side => side.name)
  const extras = (item.options?.extras || []).map(extra => extra.quantity > 1 ? `${extra.name} ×${extra.quantity}` : extra.name)
  return [item.note, ...sides, ...extras].filter(Boolean).join(' · ')
}

onMounted(load)
watch(storeId, () => {
  void load()
})
useRealtimeSync(realtimeTopics.qrOrders, () => load())
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posOrders') }}</template>
    <template #subtitle>{{ t('qr.queueHint') }}</template>
    <OrderSectionTabs />

    <div class="qo">
      <p v-if="error" class="qo-note qo-note--bad">{{ error }}</p>

      <section class="qo-kpis" :aria-label="t('qr.pending')">
        <KpiCard
          :label="t('qr.pending')"
          :value="pending"
          :count-to="pending"
          icon="clock"
          tone="amber"
          :hint="t('qr.approval')"
        />
        <KpiCard
          :label="t('qr.tablesCount')"
          :value="tableCount"
          :count-to="tableCount"
          icon="tables"
          tone="navy"
        />
        <KpiCard
          :label="t('qr.total')"
          :value="formatMoney(queueTotal, currency)"
          icon="coins"
          tone="green"
        />
      </section>

      <section class="qo-bar">
        <div class="qo-mode">
          <span>{{ t('qr.approval') }}</span>
          <div class="qo-chips" role="group" :aria-label="t('qr.approval')">
            <button type="button" class="qo-chip" :class="{ 'is-on': mode === 'manual' }" @click="saveMode('manual')">
              {{ t('qr.manual') }}
            </button>
            <button type="button" class="qo-chip" :class="{ 'is-on': mode === 'automatic' }" @click="saveMode('automatic')">
              {{ t('qr.automatic') }}
            </button>
          </div>
          <p>{{ t('qr.approvalHint') }}</p>
        </div>
        <div class="qo-bar__actions">
          <button type="button" class="ui-btn ui-btn--secondary" :disabled="loading" @click="load">
            <AppIcon name="refresh" :size="15" />
            {{ t('common.refresh') }}
          </button>
          <button type="button" class="ui-btn ui-btn--primary" :disabled="!pending || busy === 'all'" @click="approveAll">
            {{ t('qr.approveAll') }}
          </button>
        </div>
      </section>

      <p v-if="loading" class="qo-note">{{ t('common.loading') }}</p>
      <EmptyState v-else-if="!orders.length" icon="tables" :title="t('qr.empty')" :description="t('qr.queueHint')" />

      <section v-else class="qo-grid">
        <article v-for="order in orders" :key="order.id" class="qo-card">
          <header class="qo-card__head">
            <span class="qo-card__icon" aria-hidden="true">
              <AppIcon name="tables" :size="18" />
            </span>
            <div class="qo-card__who">
              <h2>{{ order.table?.name || t('qr.table') }}</h2>
              <p v-if="order.table?.code">{{ order.table.code }}</p>
            </div>
            <div class="qo-card__meta">
              <Badge variant="warning" dot>{{ t('qr.pending') }}</Badge>
              <time v-if="order.created_at">{{ when(order.created_at) }}</time>
            </div>
          </header>

          <ul class="qo-lines">
            <li v-for="item in order.items" :key="item.id">
              <template v-if="editing !== order.id">
                <span class="qo-qty">{{ item.quantity }}</span>
                <span class="qo-line">
                  <strong>{{ item.name }}</strong>
                  <small v-if="detail(item)">{{ detail(item) }}</small>
                </span>
                <span class="qo-line-total">{{ formatMoney(item.line_total, order.currency) }}</span>
              </template>
              <label v-else class="qo-edit">
                <span>{{ item.name }}</span>
                <input v-model.number="draftQty[item.id]" type="number" min="1" max="20" :aria-label="item.name">
              </label>
            </li>
          </ul>

          <footer class="qo-card__foot">
            <p>
              <span>{{ t('qr.total') }}</span>
              <strong>{{ formatMoney(order.total, order.currency) }}</strong>
            </p>
            <div class="qo-actions">
              <button type="button" class="ui-btn ui-btn--primary" :disabled="busy === order.id" @click="approve(order)">
                <AppIcon name="check" :size="15" />
                {{ t('qr.approve') }}
              </button>
              <button v-if="editing !== order.id" type="button" class="ui-btn ui-btn--secondary" :disabled="busy === order.id" @click="startEdit(order)">
                <AppIcon name="edit" :size="15" />
                {{ t('qr.edit') }}
              </button>
              <template v-else>
                <button type="button" class="ui-btn ui-btn--secondary" :disabled="busy === order.id" @click="saveEdit(order)">
                  {{ t('common.save') }}
                </button>
                <button type="button" class="ui-btn ui-btn--ghost" :disabled="busy === order.id" @click="stopEdit">
                  {{ t('common.cancel') }}
                </button>
              </template>
              <button type="button" class="ui-btn ui-btn--ghost qo-reject" :disabled="busy === order.id" @click="reasonFor = reasonFor === order.id ? null : order.id">
                {{ t('qr.reject') }}
              </button>
            </div>
            <form v-if="reasonFor === order.id" class="qo-reason" @submit.prevent="reject(order)">
              <input v-model="reason" class="ui-input" :placeholder="t('qr.reason')" maxlength="500" required>
              <button type="submit" class="ui-btn ui-btn--danger" :disabled="busy === order.id || !reason.trim()">
                {{ t('qr.reject') }}
              </button>
            </form>
          </footer>
        </article>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.qo {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  min-width: 0;
  max-width: 100%;
}

.qo-note {
  margin: 0;
  padding: 0.75rem 0.9rem;
  border-radius: 12px;
  background: var(--color-info-bg, #eef4ff);
  color: var(--color-text-primary);
}
.qo-note--bad { background: var(--color-danger-bg, #fdecec); }

.qo-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 13.5rem), 1fr));
  gap: 0.85rem;
}

.qo-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 0.9rem 1.25rem;
  padding: 1rem 1.05rem;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -22px rgba(15, 23, 42, 0.2);
}
.qo-mode { display: grid; gap: 0.4rem; min-width: min(100%, 18rem); }
.qo-mode > span { font-weight: 650; color: var(--color-text-primary); }
.qo-mode p { margin: 0; color: var(--color-text-muted); font-size: 0.82rem; }
.qo-chips { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.qo-chip {
  border: 1px solid var(--color-border);
  background: var(--color-canvas, #f6f7f9);
  color: var(--color-text-primary);
  border-radius: 999px;
  padding: 0.35rem 0.8rem;
  font: inherit;
  font-size: 0.85rem;
  cursor: pointer;
}
.qo-chip.is-on {
  background: #12243c;
  border-color: #12243c;
  color: #fff;
}
.qo-bar__actions { display: flex; flex-wrap: wrap; gap: 0.5rem; }

.qo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 24rem), 1fr));
  gap: 0.85rem;
}

.qo-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  min-width: 0;
  padding: 1rem 1rem 1rem 1.15rem;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -18px rgba(15, 23, 42, 0.18);
}
.qo-card::before {
  content: '';
  position: absolute;
  left: 0.55rem;
  top: 1rem;
  bottom: 1rem;
  width: 3px;
  border-radius: 999px;
  background: #e39b2b;
}

.qo-card__head {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.7rem;
  align-items: center;
  padding-left: 0.45rem;
}
.qo-card__icon {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: #12243c;
  color: #fff;
}
.qo-card__who { min-width: 0; }
.qo-card__who h2 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}
.qo-card__who p { margin: 0.1rem 0 0; color: var(--color-text-muted); font-size: 0.8rem; }
.qo-card__meta {
  display: grid;
  justify-items: end;
  gap: 0.25rem;
}
.qo-card__meta time {
  color: var(--color-text-muted);
  font-size: 0.8rem;
  font-variant-numeric: tabular-nums;
}

.qo-lines {
  list-style: none;
  margin: 0;
  padding: 0 0 0 0.45rem;
  display: grid;
  gap: 0.55rem;
}
.qo-lines li {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.65rem;
  align-items: center;
}
.qo-qty {
  display: grid;
  place-items: center;
  min-width: 1.7rem;
  height: 1.7rem;
  padding: 0 0.35rem;
  border-radius: 8px;
  background: rgba(227, 155, 43, 0.16);
  color: #12243c;
  font-size: 0.82rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.qo-line { min-width: 0; }
.qo-line strong {
  display: block;
  font-weight: 600;
  color: var(--color-text-primary);
}
.qo-line small {
  display: block;
  margin-top: 0.1rem;
  color: var(--color-text-muted);
  font-size: 0.78rem;
}
.qo-line-total {
  font-variant-numeric: tabular-nums;
  font-weight: 600;
  color: var(--color-text-primary);
  white-space: nowrap;
}
.qo-edit {
  grid-column: 1 / -1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}
.qo-edit input {
  width: 4.5rem;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  padding: 0.35rem 0.5rem;
  font: inherit;
}

.qo-card__foot {
  display: grid;
  gap: 0.7rem;
  margin-left: 0.45rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--color-border);
}
.qo-card__foot > p {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
  margin: 0;
}
.qo-card__foot > p span { color: var(--color-text-muted); font-size: 0.85rem; }
.qo-card__foot > p strong {
  font-size: 1.2rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
  color: #12243c;
}
.qo-actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.qo-reject { color: var(--color-danger, #b42318); }
.qo-reason { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.qo-reason .ui-input { flex: 1; min-width: 12rem; }

@media (max-width: 640px) {
  .qo-card__head { grid-template-columns: auto 1fr; }
  .qo-card__meta { grid-column: 2; justify-items: start; }
}
</style>
