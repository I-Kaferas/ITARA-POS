<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { debounceFn } from '../../composables/useLiveSearch'
import { usePosStore } from '../../stores/pos'
import { formatMoney } from '../../utils/money'
import { needsSaleQuantity } from '../../utils/product'
import type { PosCartLine, PosCustomerOption } from '../../types/pos'

const props = defineProps<{
  lines: PosCartLine[]
  currency?: string
  emptyLabel: string
  emptyHint?: string
  customer: PosCustomerOption | null
  lineTotals?: Record<string, number>
  tableName?: string | null
  orderMode: 'dine_in' | 'takeaway' | 'delivery'
}>()

const emit = defineEmits<{
  increment: [lineId: string]
  decrement: [lineId: string]
  quantity: [lineId: string, quantity: number]
  remove: [lineId: string]
  close: []
  selectCustomer: [customer: PosCustomerOption | null]
  addCustomer: []
  setOrderMode: [mode: 'dine_in' | 'takeaway' | 'delivery']
  openTables: []
}>()

const { t } = useI18n()
const pos = usePosStore()

const customerQuery = ref('')
const customerResults = ref<PosCustomerOption[]>([])
const customerLoading = ref(false)
const showResults = ref(false)

const itemCount = computed(() => props.lines.reduce((sum, line) => sum + line.quantity, 0))
const customerDropOpen = computed(() => showResults.value && (customerLoading.value || customerResults.value.length > 0 || customerQuery.value.trim().length > 0))

async function runCustomerSearch() {
  const q = customerQuery.value.trim()
  if (!q) {
    customerResults.value = []
    customerLoading.value = false
    return
  }
  customerLoading.value = true
  try {
    customerResults.value = await pos.searchCustomers(q)
  } catch {
    customerResults.value = []
  } finally {
    customerLoading.value = false
  }
}

const searchCustomersLive = debounceFn(runCustomerSearch, 280)
onBeforeUnmount(() => searchCustomersLive.cancel())

watch(() => props.customer, (customer) => {
  if (customer) {
    customerQuery.value = customer.name
    showResults.value = false
  } else if (!showResults.value) {
    customerQuery.value = ''
  }
})

function onCustomerInput() {
  showResults.value = true
  searchCustomersLive()
}

function pickCustomer(customer: PosCustomerOption) {
  emit('selectCustomer', customer)
  customerQuery.value = customer.name
  showResults.value = false
}

function clearCustomer() {
  emit('selectCustomer', null)
  customerQuery.value = ''
  customerResults.value = []
  showResults.value = false
}

async function createCustomerQuick() {
  const name = customerQuery.value.trim()
  if (!name) {
    emit('addCustomer')
    return
  }
  try {
    const created = await pos.createCustomer({ name })
    emit('selectCustomer', created)
    showResults.value = false
  } catch {
    // status handled by store / caller
  }
}

function lineImage(line: PosCartLine) {
  const raw = line.product.primary_image_cdn_url?.trim()
  if (!raw) return ''
  try {
    const url = new URL(raw, window.location.origin)
    if (url.pathname.startsWith('/storage/')) return `${url.pathname}${url.search}`
  } catch {
    return raw
  }
  return raw
}
</script>

<template>
  <aside class="pos-cart">
    <div class="pos-cart__header">
      <div>
        <h2 class="pos-cart__title">{{ t('pos.orderDetails') }}</h2>
        <p class="pos-cart__meta">{{ itemCount }} {{ t('pos.articles') }}</p>
      </div>
      <button class="pos-cart__close" type="button" :title="t('pos.cart')" @click="emit('close')">×</button>
    </div>

    <div class="pos-cart__modes" role="group" :aria-label="t('pos.orderMode')">
      <button
        type="button"
        class="pos-cart__mode"
        :class="{ 'pos-cart__mode--active': orderMode === 'dine_in' }"
        @click="emit('setOrderMode', 'dine_in')"
      >
        {{ t('pos.dineIn') }}
      </button>
      <button
        type="button"
        class="pos-cart__mode"
        :class="{ 'pos-cart__mode--active': orderMode === 'takeaway' }"
        @click="emit('setOrderMode', 'takeaway')"
      >
        {{ t('pos.takeaway') }}
      </button>
      <button
        type="button"
        class="pos-cart__mode"
        :class="{ 'pos-cart__mode--active': orderMode === 'delivery' }"
        @click="emit('setOrderMode', 'delivery')"
      >
        {{ t('pos.delivery') }}
      </button>
    </div>

    <div class="pos-cart__fields">
      <label class="pos-cart__field">
        <span>{{ t('pos.customerName') }}</span>
        <div class="pos-cart__customer-search">
          <AppIcon name="search" :size="14" />
          <input
            v-model="customerQuery"
            type="search"
            autocomplete="off"
            :placeholder="t('pos.searchCustomer')"
            @input="onCustomerInput"
            @focus="showResults = true"
          />
          <button
            v-if="customer"
            type="button"
            class="pos-cart__customer-clear"
            :title="t('common.delete')"
            @click="clearCustomer"
          >
            ×
          </button>
        </div>
      </label>
      <label class="pos-cart__field">
        <span>{{ t('pos.tableNumber') }}</span>
        <button type="button" class="pos-cart__table" @click="emit('openTables')">
          {{ tableName || t('pos.pickTable') }}
        </button>
      </label>
    </div>

    <div class="fold-panel pos-customer-fold" :class="{ 'is-open': customerDropOpen }">
    <div class="fold-panel__body">
    <div class="pos-cart__customer-dropdown" :inert="!customerDropOpen">
      <p v-if="customerLoading" class="pos-cart__customer-empty">…</p>
      <template v-else>
        <button
          v-for="c in customerResults"
          :key="c.id"
          type="button"
          class="pos-cart__customer-item"
          @click="pickCustomer(c)"
        >
          <strong>{{ c.name }}</strong>
          <span v-if="c.phone">{{ c.phone }}</span>
        </button>
        <p v-if="!customerResults.length && customerQuery.trim()" class="pos-cart__customer-empty">
          {{ t('pos.noCustomerFound') }}
        </p>
        <button
          v-if="customerQuery.trim()"
          type="button"
          class="pos-cart__customer-item pos-cart__customer-item--create"
          @click="createCustomerQuick"
        >
          + {{ t('pos.createCustomer') }} « {{ customerQuery.trim() }} »
        </button>
      </template>
    </div>
    </div>
    </div>

    <div class="pos-cart__section-head">
      <h3>{{ t('pos.orderedMenu') }}</h3>
      <button type="button" class="pos-cart__add-customer" @click="createCustomerQuick">
        {{ t('pos.addCustomer') }}
      </button>
    </div>

    <TransitionGroup name="cart-line" tag="div" class="pos-cart__lines">
      <article v-for="line in lines" :key="line.lineId" class="pos-cart__line">
        <div class="pos-cart__media">
          <img v-if="lineImage(line)" :src="lineImage(line)" :alt="line.product.name" />
          <span v-else>{{ line.product.name.trim().charAt(0).toUpperCase() }}</span>
        </div>
        <div class="pos-cart__body">
          <div class="pos-cart__line-top">
            <div class="min-w-0">
              <p class="pos-cart__name">
                {{ line.product.name }}
                <span v-if="line.isAccompaniment" class="pos-cart__free">{{ t('accompaniments.priceFree') }}</span>
              </p>
              <p class="pos-cart__unit">
                {{ formatMoney(line.product.price, currency) }}
                <template v-if="needsSaleQuantity(line.product) && !line.isAccompaniment">
                  × {{ line.quantity }}
                </template>
              </p>
            </div>
            <button class="pos-cart__remove" type="button" :title="t('common.delete')" @click="emit('remove', line.lineId)">
              <AppIcon name="trash" :size="14" />
            </button>
          </div>
          <div class="pos-cart__line-bottom">
            <div v-if="needsSaleQuantity(line.product) && !line.isAccompaniment" class="pos-cart__qty">
              <button type="button" @click="emit('decrement', line.lineId)">−</button>
              <input
                type="number"
                min="1"
                :value="line.quantity"
                @change="emit('quantity', line.lineId, Math.max(1, Number(($event.target as HTMLInputElement).value) || 1))"
              />
              <button type="button" @click="emit('increment', line.lineId)">+</button>
            </div>
            <span v-else class="pos-cart__no-qty">{{ t('pos.noQuantity') }}</span>
            <span class="pos-cart__amount">
              {{ formatMoney(lineTotals?.[line.lineId] ?? line.product.price * line.quantity, currency) }}
            </span>
          </div>
        </div>
      </article>

      <div v-if="!lines.length" key="empty" class="pos-cart__empty">
        <span class="pos-cart__empty-mark">
          <AppIcon name="receipt" :size="32" />
        </span>
        <p class="pos-cart__empty-title">{{ emptyLabel }}</p>
        <p v-if="emptyHint" class="pos-cart__empty-hint">{{ emptyHint }}</p>
      </div>
    </TransitionGroup>

    <label class="pos-cart__date">
      <AppIcon name="calendar" :size="16" />
      <span>{{ t('pos.orderDate') }}</span>
      <input v-model="pos.orderDate" type="date" :aria-label="t('pos.orderDate')" />
    </label>
  </aside>
</template>

<style scoped>
.pos-cart {
  width: 100%;
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--color-surface, #fff);
}

.pos-cart__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  padding: 1.05rem 1.1rem 0.55rem;
}

.pos-cart__title {
  margin: 0;
  font-family: var(--font-display, var(--font-brand, inherit));
  font-size: 1.15rem;
  font-weight: 750;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.pos-cart__meta {
  margin: 0.15rem 0 0;
  font-size: 0.75rem;
  color: var(--color-text-faint);
}

.pos-cart__close {
  display: none;
  width: 1.7rem;
  height: 1.7rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
}

.pos-cart__modes {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.3rem;
  margin: 0 1.1rem 0.85rem;
  padding: 0.3rem;
  border-radius: 12px;
  background: var(--color-canvas, #eef1f5);
  border: 1px solid var(--color-border, #dbe3ea);
}

.pos-cart__mode {
  border: 0;
  border-radius: 9px;
  padding: 0.55rem 0.35rem;
  background: transparent;
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  font-weight: 700;
  cursor: pointer;
  transition: background 160ms ease, color 160ms ease;
}

.pos-cart__mode--active {
  background: var(--color-brand-600, #12243c);
  color: #fff;
  box-shadow: 0 4px 10px rgba(18, 36, 60, 0.16);
}

.pos-cart__fields {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.55rem;
  padding: 0 1.1rem 0.85rem;
  position: relative;
}

.pos-cart__field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  min-width: 0;
  margin: 0;
  font-size: 0.7rem;
  font-weight: 650;
  color: var(--color-text-muted);
}

.pos-cart__customer-search,
.pos-cart__table {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 2.45rem;
  padding: 0 0.7rem;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 10px;
  background: var(--color-canvas, #f7f8fb);
  color: var(--color-text-faint);
}

.pos-cart__customer-search input {
  flex: 1;
  min-width: 0;
  border: 0;
  background: transparent;
  padding: 0.55rem 0;
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--color-text-primary);
  outline: none;
}

.pos-cart__customer-clear {
  border: 0;
  background: transparent;
  color: var(--color-text-muted);
  font-size: 1rem;
  cursor: pointer;
  line-height: 1;
}

.pos-cart__table {
  width: 100%;
  justify-content: flex-start;
  font-size: 0.82rem;
  font-weight: 650;
  color: var(--color-text-primary);
  cursor: pointer;
  text-align: left;
}

.pos-customer-fold .pos-cart__customer-dropdown {
  margin: -0.35rem 1.1rem 0.65rem;
}

.pos-cart__customer-dropdown {
  margin: 0;
  max-height: 12rem;
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  box-shadow: 0 12px 28px rgba(18, 36, 60, 0.1);
  z-index: 20;
}

.pos-cart__customer-item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.1rem;
  width: 100%;
  border: 0;
  border-bottom: 1px solid var(--color-border);
  background: var(--color-surface);
  padding: 0.65rem 0.8rem;
  text-align: left;
  cursor: pointer;
}

.pos-cart__customer-item:last-child {
  border-bottom: 0;
}

.pos-cart__customer-item span {
  font-size: 0.72rem;
  color: var(--color-text-muted);
}

.pos-cart__customer-item--create {
  color: var(--color-brand-600, #12243c);
  font-weight: 600;
}

.pos-cart__customer-empty {
  margin: 0;
  padding: 0.75rem;
  font-size: 0.8rem;
  color: var(--color-text-muted);
}

.pos-cart__section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  padding: 0.15rem 1.1rem 0.45rem;
}

.pos-cart__section-head h3 {
  margin: 0;
  font-family: var(--font-display, var(--font-brand, inherit));
  font-size: 0.92rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.pos-cart__add-customer {
  border: 0;
  border-radius: 8px;
  padding: 0.35rem 0.65rem;
  background: color-mix(in srgb, var(--color-accent, #e39b2b) 18%, transparent);
  color: #8a5a12;
  font-size: 0.72rem;
  font-weight: 700;
  cursor: pointer;
}

.pos-cart__lines {
  flex: 1;
  overflow-y: auto;
  padding: 0.15rem 1.1rem 0.85rem;
}

.pos-cart__line {
  display: flex;
  gap: 0.7rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border, #e7edf3);
  border-radius: 14px;
  padding: 0.65rem;
  margin-bottom: 0.55rem;
}

.pos-cart__media {
  width: 3.2rem;
  height: 3.2rem;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  overflow: hidden;
  border-radius: 10px;
  background: var(--color-canvas, #eef1f5);
  color: var(--color-brand-600, #12243c);
  font-weight: 700;
}

.pos-cart__media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.pos-cart__body {
  min-width: 0;
  flex: 1;
}

.pos-cart__line-top {
  display: flex;
  justify-content: space-between;
  gap: 0.5rem;
}

.pos-cart__name {
  margin: 0;
  font-size: 0.84rem;
  font-weight: 700;
  line-height: 1.3;
  color: var(--color-text-primary);
}

.pos-cart__free {
  margin-left: 0.35rem;
  border-radius: 999px;
  background: color-mix(in srgb, #0f7a4d 12%, transparent);
  color: #0f7a4d;
  font-size: 0.65rem;
  font-weight: 700;
  padding: 0.1rem 0.4rem;
}

.pos-cart__remove {
  border: 0;
  background: color-mix(in srgb, #dc2626 10%, transparent);
  color: #dc2626;
  width: 1.55rem;
  height: 1.55rem;
  border-radius: 8px;
  cursor: pointer;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}

.pos-cart__unit {
  margin: 0.2rem 0 0;
  font-size: 0.72rem;
  color: var(--color-text-faint);
}

.pos-cart__line-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 0.55rem;
}

.pos-cart__no-qty {
  font-size: 0.72rem;
  color: var(--color-text-faint);
}

.pos-cart__qty {
  display: flex;
  align-items: center;
  gap: 0.15rem;
  background: var(--color-canvas, #eef1f5);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 0.15rem;
}

.pos-cart__qty button {
  width: 1.6rem;
  height: 1.6rem;
  border: none;
  border-radius: 999px;
  background: var(--color-surface);
  cursor: pointer;
  font-size: 0.95rem;
  color: var(--color-text-secondary);
}

.pos-cart__qty button:hover {
  background: var(--color-brand-600, #12243c);
  color: #fff;
}

.pos-cart__qty input {
  width: 2rem;
  border: 0;
  background: transparent;
  text-align: center;
  font-size: 0.8rem;
  font-weight: 750;
  color: var(--color-text-primary);
}

.pos-cart__qty input::-webkit-outer-spin-button,
.pos-cart__qty input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.pos-cart__amount {
  margin-left: auto;
  font-size: 0.9rem;
  font-weight: 750;
  color: var(--color-text-primary);
}

.pos-cart__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  min-height: 12rem;
  color: var(--color-text-faint);
  text-align: center;
}

.pos-cart__empty-mark {
  width: 3.8rem;
  height: 3.8rem;
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: var(--color-canvas, #eef1f5);
  color: #9aa8b5;
  margin-bottom: 0.2rem;
}

.pos-cart__empty-title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--color-text-secondary);
}

.pos-cart__empty-hint {
  margin: 0;
  max-width: 14rem;
  font-size: 0.8rem;
  line-height: 1.4;
}

.pos-cart__date {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: 0.5rem;
  margin: 0;
  padding: 0.65rem 1.1rem;
  border-top: 1px solid var(--color-border);
  background: var(--color-canvas, #f7f8fb);
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  font-weight: 600;
}

.pos-cart__date input {
  margin-left: auto;
  border: 1px solid var(--color-border);
  border-radius: 8px;
  background: var(--color-surface);
  padding: 0.35rem 0.5rem;
  font: inherit;
  font-weight: 600;
  color: var(--color-text-primary);
  cursor: pointer;
}

.cart-line-enter-active,
.cart-line-leave-active {
  transition: opacity 180ms ease, transform 180ms ease;
}

.cart-line-enter-from,
.cart-line-leave-to {
  opacity: 0;
  transform: translateY(6px);
}

@media (max-width: 900px) {
  .pos-cart {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    z-index: 50;
    width: min(22rem, 92%);
    transform: translateX(110%);
    transition: transform 320ms var(--ease-emphasized, ease);
    box-shadow: -12px 0 28px rgba(15, 23, 42, 0.16);
    pointer-events: none;
  }

  :global(.pos-body--cart-open) .pos-cart,
  :global(.pos-side--cart-open) .pos-cart {
    transform: none;
    pointer-events: auto;
  }

  .pos-cart__close {
    display: grid;
    place-items: center;
  }

  .pos-cart__fields {
    grid-template-columns: 1fr;
  }
}
</style>
