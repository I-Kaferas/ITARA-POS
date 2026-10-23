<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import FilterFold from '../../../components/ui/FilterFold.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'
import { extractApiErrorMessage } from '../../../api/client'
import { useAuthStore } from '../../../stores/auth'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { formatMoney } from '../../../utils/format'
import type { CashierShift } from '../../../types'

const { t } = useI18n()
const router = useRouter()
const auth = useAuthStore()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const loading = ref(false)
const error = ref('')
const showOpen = ref(false)
const showClose = ref(false)
const selectedRegisterId = ref('')
const openingBalance = ref('0')
const openingNotes = ref('')
const actualCash = ref('')
const closingNotes = ref('')
const varianceReason = ref('')
const saving = ref(false)
const statusFilter = ref<'all' | 'open' | 'closed'>('all')
const search = ref('')
const menuId = ref<string | null>(null)

const storeIdValue = storeId

const roleSlugs = computed(() =>
  (auth.user?.roles ?? [])
    .map(role => (typeof role === 'string' ? role : role.slug))
    .filter((slug): slug is string => Boolean(slug)),
)
const isCashier = computed(() => roleSlugs.value.includes('cashier'))
const canViewAllShifts = computed(() =>
  Boolean(auth.user?.is_super_admin)
  || roleSlugs.value.some(slug =>
    ['administrator', 'company_owner', 'branch_manager', 'store_manager', 'super_admin'].includes(slug),
  ),
)
const canOpenShift = computed(() => isCashier.value)

const activeRegisters = computed(() => store.cashRegisters.filter(r => r.is_active !== false))
const myShift = computed(() => store.currentCashierShift)
const busyRegisterIds = computed(() => new Set(
  store.cashierShifts.filter(shift => shift.status === 'open').map(shift => shift.cash_register_id),
))
const freeRegisters = computed(() => activeRegisters.value.filter(reg => !busyRegisterIds.value.has(reg.id)))

const scopedShifts = computed(() => {
  if (canViewAllShifts.value && storeId.value) return store.cashierShifts
  const userId = auth.user?.id
  if (!userId) return []
  return store.cashierShifts.filter(shift => shift.cashier_id === userId)
})

const activeCount = computed(() => scopedShifts.value.filter(shift => shift.status === 'open').length)
const closedCount = computed(() => scopedShifts.value.filter(shift => shift.status === 'closed').length)

const visibleShifts = computed(() => {
  const query = search.value.trim().toLowerCase()
  return scopedShifts.value
    .filter(shift => statusFilter.value === 'all' || shift.status === statusFilter.value)
    .filter(shift => {
      if (!query) return true
      const hay = [
        shiftCode(shift),
        shift.cashier?.name,
        shift.cash_register?.name,
        shift.cash_register?.code,
        shift.branch?.name,
      ].filter(Boolean).join(' ').toLowerCase()
      return hay.includes(query)
    })
    .slice()
    .sort((a, b) => {
      if (a.status !== b.status) return a.status === 'open' ? -1 : 1
      return new Date(b.opened_at).getTime() - new Date(a.opened_at).getTime()
    })
})
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(visibleShifts)

async function load() {
  loading.value = true
  error.value = ''
  try {
    await store.loadCurrentCashierShift()
    if (canViewAllShifts.value && storeIdValue.value) {
      await Promise.all([
        store.loadCashRegisters(storeIdValue.value),
        store.loadStoreCashierShifts(storeIdValue.value),
      ])
    } else {
      await store.loadMyCashierShifts()
      if (storeIdValue.value) {
        await store.loadCashRegisters(storeIdValue.value)
      }
    }
    const preferred = freeRegisters.value[0]?.id ?? activeRegisters.value[0]?.id ?? ''
    if (!selectedRegisterId.value || !freeRegisters.value.some(reg => reg.id === selectedRegisterId.value)) {
      selectedRegisterId.value = preferred
    }
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.loadError'))
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(storeId, load)
useRealtimeSync(realtimeTopics.shifts, load)

function shiftCode(shift: CashierShift) {
  const opened = new Date(shift.opened_at)
  const y = opened.getFullYear()
  const m = String(opened.getMonth() + 1).padStart(2, '0')
  const d = String(opened.getDate()).padStart(2, '0')
  const tail = shift.id.replace(/-/g, '').slice(-4)
  return `SH-${y}${m}${d}-${tail}`
}

function shiftTime(shift: CashierShift) {
  return new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit' }).format(new Date(shift.opened_at))
}

function durationLabel(shift: CashierShift) {
  const start = new Date(shift.opened_at).getTime()
  const end = shift.closed_at ? new Date(shift.closed_at).getTime() : Date.now()
  const mins = Math.max(0, Math.round((end - start) / 60000))
  if (mins < 60) return `${mins}m`
  const hours = Math.floor(mins / 60)
  const rest = mins % 60
  return rest ? `${hours}h ${rest}m` : `${hours}h`
}

function isMine(shift: CashierShift) {
  return shift.id === myShift.value?.id || (shift.status === 'open' && shift.cashier_id === auth.user?.id)
}

function openModal() {
  if (!canOpenShift.value) {
    error.value = t('pointOfSale.shifts.cashierOnly')
    return
  }
  if (myShift.value) {
    error.value = t('pointOfSale.shifts.alreadyOpen')
    return
  }
  if (!storeIdValue.value) {
    error.value = t('pos.selectStore')
    return
  }
  if (!freeRegisters.value.length) {
    error.value = t('pointOfSale.shifts.noFreeRegister')
    return
  }
  openingBalance.value = '0'
  openingNotes.value = ''
  selectedRegisterId.value = freeRegisters.value[0].id
  showOpen.value = true
}

function closeModal() {
  const shift = myShift.value
  if (!shift) return
  actualCash.value = String((shift.expected_cash ?? 0) / 100)
  closingNotes.value = ''
  varianceReason.value = ''
  showClose.value = true
}

async function confirmOpen() {
  if (!canOpenShift.value) {
    error.value = t('pointOfSale.shifts.cashierOnly')
    showOpen.value = false
    return
  }
  if (myShift.value) {
    error.value = t('pointOfSale.shifts.alreadyOpen')
    showOpen.value = false
    return
  }
  if (!selectedRegisterId.value) return
  saving.value = true
  error.value = ''
  try {
    await store.openCashierShift(selectedRegisterId.value, {
      opening_balance: Number(openingBalance.value.replace(',', '.')) || 0,
      opening_notes: openingNotes.value || undefined,
    })
    showOpen.value = false
    await load()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.openError'))
  } finally {
    saving.value = false
  }
}

async function confirmClose() {
  const registerId = myShift.value?.cash_register_id
  if (!registerId) return
  saving.value = true
  error.value = ''
  try {
    const expected = myShift.value?.expected_cash ?? 0
    const actual = Math.round((Number(actualCash.value.replace(',', '.')) || 0) * 100)
    if (actual !== expected && !varianceReason.value.trim()) {
      error.value = t('pos.varianceReasonRequired')
      saving.value = false
      return
    }
    await store.closeCashierShift(registerId, {
      actual_cash: Number(actualCash.value.replace(',', '.')) || 0,
      closing_notes: closingNotes.value || undefined,
      variance_reason: varianceReason.value.trim() || undefined,
    })
    showClose.value = false
    await load()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.closeError'))
  } finally {
    saving.value = false
  }
}

function goDetail(id: string) {
  menuId.value = null
  router.push({ name: 'pos-shift-detail', params: { id } })
}

function toggleMenu(id: string) {
  menuId.value = menuId.value === id ? null : id
}
</script>

<template>
  <PageFrame>
    <div class="shifts-root" @click="menuId = null">
      <div v-if="!canOpenShift && !canViewAllShifts" class="shifts-note">
        {{ t('pointOfSale.shifts.cashierOnly') }}
      </div>
      <div v-else-if="canOpenShift && !storeId" class="shifts-note">
        {{ t('pos.selectStore') }}
      </div>

      <template v-if="canOpenShift || canViewAllShifts">
        <header class="shifts-head">
          <div class="shifts-brand">
            <span class="shifts-mark" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="8" />
                <path d="M12 8v5l3 2" stroke-linecap="round" />
              </svg>
            </span>
            <div>
              <h1>{{ t('pointOfSale.shifts.boardTitle') }}</h1>
              <p>{{ t('pointOfSale.shifts.subtitle') }}</p>
            </div>
          </div>
          <div class="shifts-actions">
            <button type="button" class="shifts-btn shifts-btn--ghost" :disabled="loading" @click.stop="load">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M20 12a8 8 0 1 1-2.2-5.5" stroke-linecap="round" />
                <path d="M20 4v5h-5" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
              {{ t('pointOfSale.shifts.refresh') }}
            </button>
            <button
              v-if="myShift && (canOpenShift || isMine(myShift))"
              type="button"
              class="shifts-btn shifts-btn--danger"
              @click.stop="closeModal"
            >
              <span class="shifts-stop" aria-hidden="true" />
              {{ t('pointOfSale.shifts.closeAction') }}
            </button>
            <button
              v-else-if="canOpenShift"
              type="button"
              class="shifts-btn shifts-btn--primary"
              :disabled="!storeId || !freeRegisters.length"
              @click.stop="openModal"
            >
              {{ t('pointOfSale.shifts.openAction') }}
            </button>
          </div>
        </header>

        <section class="shifts-stats">
          <article class="shifts-stat">
            <span class="shifts-stat__icon shifts-stat__icon--live" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="16" height="16"><circle cx="12" cy="12" r="5" fill="#1fa971" /></svg>
            </span>
            <div>
              <strong>{{ activeCount }}</strong>
              <span>{{ t('pointOfSale.shifts.activeShifts') }}</span>
            </div>
          </article>
          <article class="shifts-stat">
            <span class="shifts-stat__icon shifts-stat__icon--closed" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="14" height="14"><rect x="6" y="6" width="12" height="12" rx="2" fill="#8b97ad" /></svg>
            </span>
            <div>
              <strong>{{ closedCount }}</strong>
              <span>{{ t('pointOfSale.shifts.closedShifts') }}</span>
            </div>
          </article>
          <article class="shifts-stat">
            <span class="shifts-stat__icon shifts-stat__icon--total" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="4" y="4" width="6" height="6" rx="1" />
                <rect x="14" y="4" width="6" height="6" rx="1" />
                <rect x="4" y="14" width="6" height="6" rx="1" />
                <rect x="14" y="14" width="6" height="6" rx="1" />
              </svg>
            </span>
            <div>
              <strong>{{ scopedShifts.length }}</strong>
              <span>{{ t('pointOfSale.shifts.totalShifts') }}</span>
            </div>
          </article>
        </section>

        <FilterFold>
        <div class="shifts-toolbar">
          <div class="shifts-filters" role="tablist">
            <button
              v-for="opt in ([
                ['all', t('pointOfSale.shifts.filterAll')],
                ['open', t('pointOfSale.shifts.active')],
                ['closed', t('pointOfSale.shifts.closed')],
              ] as const)"
              :key="opt[0]"
              type="button"
              role="tab"
              :aria-selected="statusFilter === opt[0]"
              :class="{ 'is-on': statusFilter === opt[0] }"
              @click="statusFilter = opt[0]"
            >
              {{ opt[1] }}
            </button>
          </div>
          <label class="shifts-search">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="11" cy="11" r="7" />
              <path d="M20 20l-3.5-3.5" stroke-linecap="round" />
            </svg>
            <input v-model="search" type="search" :placeholder="t('pointOfSale.shifts.search')" />
          </label>
        </div>
        </FilterFold>

        <p v-if="error" class="shifts-error">{{ error }}</p>
        <p v-if="!activeRegisters.length" class="shifts-note">{{ t('pointOfSale.shifts.noRegisterHint') }}</p>
        <p v-else-if="!myShift && !freeRegisters.length" class="shifts-note">{{ t('pointOfSale.shifts.noFreeRegister') }}</p>

        <LoadingBlock v-if="loading && !scopedShifts.length" :label="t('common.loading')" />

        <template v-else-if="visibleShifts.length">
        <div class="shifts-grid">
          <article
            v-for="shift in paged"
            :key="shift.id"
            class="shift-card"
            :class="{ 'shift-card--open': shift.status === 'open' }"
          >
            <div class="shift-card__top">
              <button type="button" class="shift-card__title" @click="goDetail(shift.id)">
                <span class="shift-dot" :class="{ 'is-live': shift.status === 'open' }" />
                <strong>{{ shiftCode(shift) }}</strong>
                <em :class="shift.status === 'open' ? 'is-live' : 'is-closed'">
                  {{ shift.status === 'open' ? t('pointOfSale.shifts.active') : t('pointOfSale.shifts.closed') }}
                </em>
              </button>
              <div class="shift-menu">
                <button type="button" class="shift-menu__btn" :aria-label="t('pointOfSale.shifts.details')" @click.stop="toggleMenu(shift.id)">
                  ···
                </button>
                <div class="fold-panel fold-panel--pop shift-menu__pop" :class="{ 'is-open': menuId === shift.id }" @click.stop>
                <div class="fold-panel__body" :inert="menuId !== shift.id">
                <div class="shift-menu__panel">
                  <button type="button" @click="goDetail(shift.id)">{{ t('pointOfSale.shifts.details') }}</button>
                  <button v-if="isMine(shift) && shift.status === 'open'" type="button" @click="menuId = null; closeModal()">
                    {{ t('pointOfSale.shifts.closeAction') }}
                  </button>
                </div>
                </div>
                </div>
              </div>
            </div>
            <p class="shift-card__meta">
              <span>{{ shift.cashier?.name || '—' }}</span>
              <span>{{ shiftTime(shift) }}</span>
            </p>
            <dl class="shift-metrics">
              <div>
                <dt>{{ formatMoney(shift.opening_balance) }}</dt>
                <dd>{{ t('pointOfSale.shifts.opening') }}</dd>
              </div>
              <div>
                <dt class="is-sales">{{ formatMoney(shift.sales_total) }}</dt>
                <dd>{{ t('pointOfSale.shifts.sales') }}</dd>
              </div>
              <div>
                <dt>{{ shift.orders_count ?? 0 }}</dt>
                <dd>{{ t('pointOfSale.shifts.orders') }}</dd>
              </div>
              <div>
                <dt class="is-duration">{{ durationLabel(shift) }}</dt>
                <dd>{{ t('pointOfSale.shifts.duration') }}</dd>
              </div>
            </dl>
            <p class="shift-card__store">{{ (shift.cash_register?.name || shift.branch?.name || '—').toUpperCase() }}</p>
          </article>
        </div>
        <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
        </template>

        <div v-else class="shifts-empty">
          <p>{{ t('pointOfSale.shifts.empty') }}</p>
          <button v-if="!myShift && freeRegisters.length" type="button" class="shifts-btn shifts-btn--primary" @click="openModal">
            {{ t('pointOfSale.shifts.openAction') }}
          </button>
        </div>
      </template>
    </div>

    <AppModal :open="showOpen" :title="t('pointOfSale.shifts.openAction')" @close="showOpen = false">
      <div class="space-y-3">
        <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.shifts.openHint') }}</p>
        <div>
          <FieldLabel icon="shift">{{ t('pointOfSale.shifts.register') }}</FieldLabel>
          <select v-model="selectedRegisterId" class="ui-select w-full">
            <option v-for="reg in freeRegisters" :key="reg.id" :value="reg.id">
              {{ reg.name }} ({{ reg.code }})
            </option>
          </select>
        </div>
        <div>
          <FieldLabel icon="coins">{{ t('pointOfSale.shifts.openingBalance') }}</FieldLabel>
          <input v-model="openingBalance" type="text" class="ui-input w-full" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('pointOfSale.shifts.notes') }}</FieldLabel>
          <textarea v-model="openingNotes" rows="2" class="ui-input w-full" />
        </div>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="ui-btn ui-btn--secondary" @click="showOpen = false">{{ t('common.cancel') }}</button>
          <button type="button" class="ui-btn ui-btn--primary" :class="{ 'is-busy': saving }" :disabled="saving || !selectedRegisterId" @click="confirmOpen">
            {{ saving ? t('common.saving') : t('pointOfSale.shifts.openAction') }}
          </button>
        </div>
      </div>
    </AppModal>

    <AppModal :open="showClose" :title="t('pointOfSale.shifts.closeAction')" @close="showClose = false">
      <div class="space-y-3">
        <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.shifts.closeHint') }}</p>
        <div v-if="myShift" class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
          <div class="flex justify-between gap-3">
            <span>{{ t('pointOfSale.shifts.expected') }}</span>
            <strong>{{ formatMoney(myShift.expected_cash) }}</strong>
          </div>
          <div class="mt-1 flex justify-between gap-3">
            <span>{{ t('pointOfSale.shifts.sales') }}</span>
            <strong>{{ formatMoney(myShift.sales_total) }}</strong>
          </div>
        </div>
        <div>
          <FieldLabel icon="coins">{{ t('pointOfSale.shifts.actualCash') }}</FieldLabel>
          <input v-model="actualCash" type="text" class="ui-input w-full" required />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('pos.varianceReason') }}</FieldLabel>
          <textarea v-model="varianceReason" rows="2" class="ui-input w-full" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('pointOfSale.shifts.notes') }}</FieldLabel>
          <textarea v-model="closingNotes" rows="2" class="ui-input w-full" />
        </div>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="ui-btn ui-btn--secondary" @click="showClose = false">{{ t('common.cancel') }}</button>
          <button type="button" class="ui-btn ui-btn--primary" :class="{ 'is-busy': saving }" :disabled="saving" @click="confirmClose">
            {{ saving ? t('common.saving') : t('pointOfSale.shifts.closeAction') }}
          </button>
        </div>
      </div>
    </AppModal>
  </PageFrame>
</template>

<style>
.app-content:has(.shifts-root) {
  display: flex;
  flex-direction: column;
  padding: 0;
  --sh-bg: var(--color-canvas);
  --sh-card: var(--color-surface);
  --sh-line: var(--color-border);
  --sh-title: var(--color-text-primary);
  --sh-text: var(--color-text);
  --sh-muted: var(--color-text-muted);
  --sh-primary: var(--color-brand-600);
  --sh-live: var(--color-success);
  --sh-live-bg: var(--color-success-bg);
  --sh-closed-bg: var(--color-brand-100);
  --sh-total-bg: var(--color-accent-soft);
  --sh-store: #9a6412;
  --sh-duration: var(--color-warning);
  --sh-menu: var(--color-surface);
  --sh-menu-hover: var(--color-table-row-hover);
  --sh-menu-shadow: 0 12px 30px rgba(20, 32, 43, 0.14);
  --sh-error-bg: var(--color-danger-bg);
  --sh-error: var(--color-danger);
  --sh-note-bg: var(--color-warning-bg);
  --sh-note: var(--color-warning);
  background: var(--sh-bg);
}

.app-content .shifts-root {
  box-sizing: border-box;
  flex: 1 1 auto;
  align-self: stretch;
  width: 100%;
  max-width: none;
  margin: 0;
  min-height: 100%;
  padding: 22px 24px 36px;
  background: var(--sh-bg);
  color: var(--sh-text);
}

[data-theme='dark'] .app-content:has(.shifts-root) {
  --sh-bg: #070b16;
  --sh-card: #151c2c;
  --sh-line: #2a3448;
  --sh-title: #f4f7ff;
  --sh-text: #e8eefc;
  --sh-muted: #9aa6bf;
  --sh-primary: #7c5cff;
  --sh-live: #3ddc97;
  --sh-live-bg: #143528;
  --sh-closed-bg: #243044;
  --sh-total-bg: #2a2158;
  --sh-store: #b9a6ff;
  --sh-duration: #f5a524;
  --sh-menu: #101828;
  --sh-menu-hover: #1c2740;
  --sh-menu-shadow: 0 12px 30px rgba(0, 0, 0, 0.35);
  --sh-error-bg: #2a1830;
  --sh-error: #ffb4b4;
  --sh-note-bg: #241c12;
  --sh-note: #f3d7a1;
}

.app-content .shifts-root h1 {
  margin: 0;
  color: var(--sh-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.app-content .shifts-root p {
  margin: 0;
  color: var(--sh-muted);
}

.app-content .shifts-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 16px;
}

.app-content .shifts-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.app-content .shifts-brand > div {
  min-width: 0;
}

.app-content .shifts-mark {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  flex: 0 0 auto;
  border-radius: 14px;
  background: var(--sh-primary);
  color: #fff;
}

.app-content .shifts-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.app-content .shifts-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 42px;
  padding: 0 14px;
  border-radius: 12px;
  border: 1px solid transparent;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.app-content .shifts-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.app-content .shifts-btn--ghost {
  background: var(--sh-card);
  color: var(--sh-text);
  border-color: var(--sh-line);
}

.app-content .shifts-btn--danger {
  background: #e23d3d;
  color: #fff;
}

.app-content .shifts-btn--primary {
  background: var(--sh-primary);
  color: #fff;
}

.app-content .shifts-stop {
  width: 10px;
  height: 10px;
  border-radius: 2px;
  background: currentColor;
}

.app-content .shifts-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.app-content .shifts-stat {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  border-radius: 16px;
  background: var(--sh-card);
  border: 1px solid var(--sh-line);
}

.app-content .shifts-stat strong {
  display: block;
  color: var(--sh-title);
  font-size: 1.35rem;
  line-height: 1.1;
}

.app-content .shifts-stat span {
  color: var(--sh-muted);
  font-size: 12px;
}

.app-content .shifts-stat__icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  flex: 0 0 auto;
}

.app-content .shifts-stat__icon--live { background: var(--sh-live-bg); }
.app-content .shifts-stat__icon--closed { background: var(--sh-closed-bg); }
.app-content .shifts-stat__icon--total { background: var(--sh-total-bg); color: var(--sh-store); }

.app-content .shifts-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-top: 16px;
}

.app-content .shifts-filters {
  display: flex;
  gap: 8px;
}

.app-content .shifts-filters button {
  height: 38px;
  padding: 0 16px;
  border-radius: 10px;
  border: 1px solid var(--sh-line);
  background: var(--sh-card);
  color: var(--sh-muted);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.app-content .shifts-filters button.is-on {
  background: var(--sh-primary);
  border-color: var(--sh-primary);
  color: #fff;
}

.app-content .shifts-search {
  display: flex;
  align-items: center;
  gap: 8px;
  width: min(280px, 100%);
  height: 42px;
  padding: 0 12px;
  border-radius: 12px;
  border: 1px solid var(--sh-line);
  background: var(--sh-card);
  color: var(--sh-muted);
}

.app-content .shifts-search input {
  width: 100%;
  height: auto;
  min-height: 0;
  padding: 0;
  border: 0 !important;
  outline: none;
  box-shadow: none !important;
  background: transparent !important;
  color: var(--sh-title) !important;
  font-size: 14px;
}

.app-content .shifts-error,
.app-content .shifts-note {
  margin-top: 12px;
  padding: 10px 12px;
  border-radius: 10px;
  background: var(--sh-error-bg);
  color: var(--sh-error);
}

.app-content .shifts-note {
  background: var(--sh-note-bg);
  color: var(--sh-note);
}

.app-content .shifts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 340px), 1fr));
  gap: 12px;
  margin-top: 16px;
}

.app-content .shift-card {
  padding: 14px 14px 14px 16px;
  border-radius: 18px;
  background: var(--sh-card);
  border: 1px solid var(--sh-line);
}

.app-content .shift-card--open {
  border-color: #1fa971;
}

.app-content .shift-card__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
}

.app-content .shift-card__title {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  cursor: pointer;
  text-align: left;
}

.app-content .shift-card__title strong {
  color: var(--sh-title);
  font-size: 16px;
  font-weight: 800;
}

.app-content .shift-card__title em {
  padding: 2px 8px;
  border-radius: 999px;
  font-style: normal;
  font-size: 11px;
  font-weight: 700;
}

.app-content .shift-card__title em.is-live {
  background: var(--sh-live-bg);
  color: var(--sh-live);
}

.app-content .shift-card__title em.is-closed {
  background: var(--sh-closed-bg);
  color: var(--sh-muted);
}

.app-content .shift-dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: #8b97ad;
  flex: 0 0 auto;
}

.app-content .shift-dot.is-live {
  background: #1fa971;
}

.app-content .shift-menu {
  position: relative;
}

.app-content .shift-menu__btn {
  border: 0;
  background: transparent;
  color: var(--sh-muted);
  font-size: 18px;
  letter-spacing: 1px;
  cursor: pointer;
}

.app-content .shift-menu__pop {
  position: absolute;
  right: 0;
  top: 28px;
  z-index: 4;
}

.app-content .shift-menu__panel {
  min-width: 160px;
  padding: 6px;
  border-radius: 12px;
  background: var(--sh-menu);
  border: 1px solid var(--sh-line);
  box-shadow: var(--sh-menu-shadow);
}

.app-content .shift-menu__panel button {
  display: block;
  width: 100%;
  padding: 8px 10px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: var(--sh-text);
  text-align: left;
  cursor: pointer;
}

.app-content .shift-menu__panel button:hover {
  background: var(--sh-menu-hover);
}

.app-content .shift-card__meta {
  display: flex;
  gap: 14px;
  margin: 6px 0 0 18px !important;
  color: var(--sh-muted);
  font-size: 12px;
}

.app-content .shift-metrics {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  margin: 14px 0 0 18px;
}

.app-content .shift-metrics dt {
  color: var(--sh-title);
  font-size: 15px;
  font-weight: 800;
}

.app-content .shift-metrics dt.is-sales {
  color: var(--sh-live);
}

.app-content .shift-metrics dt.is-duration {
  color: var(--sh-duration);
}

.app-content .shift-metrics dd {
  margin: 2px 0 0;
  color: var(--sh-muted);
  font-size: 11px;
}

.app-content .shift-card__store {
  margin: 12px 0 0 18px !important;
  color: var(--sh-store) !important;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.app-content .shifts-empty {
  display: grid;
  justify-items: start;
  gap: 12px;
  margin-top: 28px;
}

@media (max-width: 800px) {
  .app-content .shifts-stats {
    grid-template-columns: 1fr;
  }

  .app-content .shift-metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    row-gap: 10px;
  }
}
</style>
