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
}>()

const emit = defineEmits<{
  increment: [lineId: string]
  decrement: [lineId: string]
  quantity: [lineId: string, quantity: number]
  remove: [lineId: string]
  close: []
  selectCustomer: [customer: PosCustomerOption | null]
  addCustomer: []
}>()

const { t, locale } = useI18n()
const pos = usePosStore()

const orderDate = ref(new Date().toISOString().slice(0, 10))
const customerQuery = ref('')
const customerResults = ref<PosCustomerOption[]>([])
const customerLoading = ref(false)
const showResults = ref(false)

const itemCount = computed(() => props.lines.reduce((sum, line) => sum + line.quantity, 0))

const dateLabel = computed(() => {
  try {
    const d = new Date(`${orderDate.value}T12:00:00`)
    return new Intl.DateTimeFormat(locale.value, {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(d).replace(/,/g, '').replace(/\s+/g, ' - ')
  } catch {
    return orderDate.value
  }
})

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
</script>

<template>
  <aside class="pos-cart">
    <div class="pos-cart__header">
      <div class="pos-cart__title-row">
        <span class="pos-cart__icon">
          <AppIcon name="receipt" :size="18" />
        </span>
        <div>
          <h2 class="pos-cart__title">{{ t('pos.currentOrder') }}</h2>
          <p class="pos-cart__meta">{{ itemCount }} {{ t('pos.articles') }}</p>
        </div>
      </div>
      <button class="pos-cart__close" type="button" :title="t('pos.cart')" @click="emit('close')">×</button>
    </div>

    <label class="pos-cart__date">
      <AppIcon name="calendar" :size="16" />
      <span>{{ dateLabel }}</span>
      <input v-model="orderDate" type="date" />
    </label>

    <div class="pos-cart__customer">
      <div class="pos-cart__customer-row">
        <div class="pos-cart__customer-search">
          <AppIcon name="search" :size="15" />
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
        <button type="button" class="pos-cart__add-customer" @click="createCustomerQuick">
          {{ t('pos.addCustomer') }}
        </button>
      </div>

      <div v-if="showResults && (customerLoading || customerResults.length || customerQuery.trim())" class="pos-cart__customer-dropdown">
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

    <div class="pos-cart__lines">
      <article v-for="line in lines" :key="line.lineId" class="pos-cart__line">
        <div class="pos-cart__media">
          <img v-if="line.product.primary_image_cdn_url" :src="line.product.primary_image_cdn_url" :alt="line.product.name" />
          <span v-else>{{ line.product.name.trim().charAt(0).toUpperCase() }}</span>
        </div>
        <div class="pos-cart__body">
          <div class="pos-cart__line-top">
            <div class="min-w-0">
              <p class="pos-cart__name">
                {{ line.product.name }}
                <span v-if="needsSaleQuantity(line.product) && !line.isAccompaniment" class="pos-cart__times">x{{ line.quantity }}</span>
                <span v-if="line.isAccompaniment" class="pos-cart__free">{{ t('accompaniments.priceFree') }}</span>
              </p>
              <p class="pos-cart__sku">
                <span v-if="line.product.category_name">{{ line.product.category_name }} · </span>{{ line.product.sku }}
              </p>
            </div>
            <button class="pos-cart__remove" type="button" :title="t('common.delete')" @click="emit('remove', line.lineId)">×</button>
          </div>
          <p class="pos-cart__unit">{{ t('pos.unitPrice') }} {{ formatMoney(line.product.price, currency) }}</p>
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
            <span class="pos-cart__amount">
              {{ formatMoney(lineTotals?.[line.lineId] ?? line.product.price * line.quantity, currency) }}
            </span>
          </div>
        </div>
      </article>

      <div v-if="!lines.length" class="pos-cart__empty">
        <span class="pos-cart__empty-mark">
          <AppIcon name="receipt" :size="36" />
        </span>
        <p class="pos-cart__empty-title">{{ emptyLabel }}</p>
        <p v-if="emptyHint" class="pos-cart__empty-hint">{{ emptyHint }}</p>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.pos-cart {
  width: 100%;
  flex: 1 1 auto;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: #fff;
}

.pos-cart__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1rem 0.65rem;
}

.pos-cart__title-row {
  display: flex;
  align-items: center;
  gap: 0.65rem;
}

.pos-cart__icon {
  width: 2.15rem;
  height: 2.15rem;
  display: grid;
  place-items: center;
  border-radius: 0.7rem;
  background: var(--color-brand-50, #f5f3ff);
  color: var(--color-brand-600);
}

.pos-cart__close {
  display: none;
  width: 1.7rem;
  height: 1.7rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #fff;
  color: var(--color-text-secondary);
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
}

.pos-cart__title {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.pos-cart__meta {
  margin: 0.1rem 0 0;
  font-size: 0.72rem;
  color: var(--color-text-faint);
}

.pos-cart__date {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0 1rem 0.65rem;
  padding: 0.65rem 0.8rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md, 0.75rem);
  background: var(--color-canvas, #f8fafc);
  color: var(--color-text-secondary);
  font-size: 0.84rem;
  font-weight: 600;
  cursor: pointer;
}

.pos-cart__date input {
  position: absolute;
  inset: 0;
  opacity: 0;
  cursor: pointer;
}

.pos-cart__customer {
  position: relative;
  padding: 0 1rem 0.75rem;
  border-bottom: 1px solid var(--color-border);
}

.pos-cart__customer-row {
  display: flex;
  gap: 0.45rem;
}

.pos-cart__customer-search {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0 0.7rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md, 0.75rem);
  background: #fff;
  color: var(--color-text-faint);
}

.pos-cart__customer-search input {
  flex: 1;
  min-width: 0;
  border: 0;
  background: transparent;
  padding: 0.62rem 0;
  font-size: 0.84rem;
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

.pos-cart__add-customer {
  flex-shrink: 0;
  border: 0;
  border-radius: var(--radius-md, 0.75rem);
  padding: 0 0.95rem;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
}

.pos-cart__customer-dropdown {
  position: absolute;
  left: 1rem;
  right: 1rem;
  top: calc(100% - 0.35rem);
  z-index: 20;
  max-height: 14rem;
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md, 0.75rem);
  background: #fff;
  box-shadow: var(--shadow-md, 0 12px 28px rgba(15, 23, 42, 0.12));
}

.pos-cart__customer-item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.1rem;
  width: 100%;
  border: 0;
  border-bottom: 1px solid var(--color-border);
  background: #fff;
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
  color: var(--color-brand-700);
  font-weight: 600;
}

.pos-cart__customer-empty {
  margin: 0;
  padding: 0.75rem;
  font-size: 0.8rem;
  color: var(--color-text-muted);
}

.pos-cart__lines {
  flex: 1;
  overflow-y: auto;
  padding: 0.75rem 1rem 1rem;
}

.pos-cart__line {
  display: flex;
  gap: 0.7rem;
  background: #fff;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg, 0.9rem);
  padding: 0.7rem;
  margin-bottom: 0.55rem;
  box-shadow: var(--shadow-xs);
}

.pos-cart__media {
  width: 3.1rem;
  height: 3.1rem;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  overflow: hidden;
  border-radius: 0.7rem;
  background: var(--color-brand-50, #f5f3ff);
  color: var(--color-brand-700);
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

.pos-cart__times {
  font-weight: 600;
  color: var(--color-text-muted);
}

.pos-cart__free {
  margin-left: 0.35rem;
  border-radius: 999px;
  background: #ecfdf5;
  color: #047857;
  font-size: 0.65rem;
  font-weight: 700;
  padding: 0.1rem 0.4rem;
}

.pos-cart__remove {
  border: 1px solid #fecaca;
  background: #fef2f2;
  color: #dc2626;
  width: 1.45rem;
  height: 1.45rem;
  border-radius: 999px;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  line-height: 1;
}

.pos-cart__sku,
.pos-cart__unit {
  margin: 0.15rem 0 0;
  font-size: 0.7rem;
  color: var(--color-text-faint);
}

.pos-cart__sku {
  font-family: var(--font-mono);
}

.pos-cart__line-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 0.65rem;
}

.pos-cart__no-qty {
  font-size: 0.72rem;
  color: var(--color-text-faint);
}

.pos-cart__qty {
  display: flex;
  align-items: center;
  gap: 0.15rem;
  background: var(--color-canvas);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 0.15rem;
}

.pos-cart__qty button {
  width: 1.7rem;
  height: 1.7rem;
  border: none;
  border-radius: 999px;
  background: #fff;
  cursor: pointer;
  font-size: 0.95rem;
  color: var(--color-text-secondary);
}

.pos-cart__qty button:hover {
  background: var(--color-brand-600);
  color: #fff;
}

.pos-cart__qty input {
  width: 2.2rem;
  border: 0;
  background: transparent;
  text-align: center;
  font-size: 0.82rem;
  font-weight: 750;
  font-family: var(--font-mono);
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
  min-height: 16rem;
  color: var(--color-text-faint);
  text-align: center;
}

.pos-cart__empty-mark {
  width: 4.5rem;
  height: 4.5rem;
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: var(--color-canvas);
  color: #cbd5e1;
  margin-bottom: 0.35rem;
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

@media (max-width: 900px) {
  .pos-cart {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    z-index: 50;
    width: min(22rem, 92%);
    transform: translateX(110%);
    transition: transform 0.2s ease;
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
}
</style>
