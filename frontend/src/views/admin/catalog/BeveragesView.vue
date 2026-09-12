<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { api } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatMoney } from '../../../utils/money'
import type { Product, Warehouse } from '../../../types'

type SaleUnitForm = { name: string; volume_ml: number; price: number; is_base: boolean }
type Dashboard = {
  products: Array<{
    id: string
    name: string
    sku: string
    brand?: string | null
    bottle_volume_ml: number
    cost_price: number
    stock: { ml: number; bottles: number; remainder_ml: number }
    doses_available: number
    dose_name?: string | null
    units: Array<{ id: string; name: string; volume_ml: number; price: number; is_base: boolean; yield_per_bottle: number; profit: number }>
  }>
  today: { sales_count: number; quantity: number; volume_ml: number; revenue: number; cost: number; profit: number }
  top_products: Array<{ name: string; quantity: number; volume_ml: number; revenue: number }>
}

const { t } = useI18n()
const store = useBackofficeStore()
const { confirm: confirmDialog } = useConfirm()

const warehouses = ref<Warehouse[]>([])
const warehouseId = ref('')
const products = ref<Product[]>([])
const dashboard = ref<Dashboard | null>(null)
const showModal = ref(false)
const saving = ref(false)
const productId = ref('')
const bottleVolume = ref(750)
const costPrice = ref(0)
const stockBottles = ref(0)
const units = ref<SaleUnitForm[]>([])

const selected = computed(() => products.value.find(product => product.id === productId.value))

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  warehouseId.value = warehouses.value[0]?.id ?? ''
  await store.loadCompanies()
  const companyId = store.companies[0]?.id
  if (companyId) {
    const catalogs = await store.loadCatalogs(companyId)
    const catalogId = catalogs.find(item => item.is_default)?.id ?? catalogs[0]?.id
    if (catalogId) products.value = await store.loadProducts(catalogId)
  }
  await refresh()
})

async function refresh() {
  const query = warehouseId.value ? `?warehouse_id=${warehouseId.value}` : ''
  dashboard.value = (await api.get<{ data: Dashboard }>(`/beverages${query}`)).data
}

function openCreate() {
  productId.value = ''
  bottleVolume.value = 750
  costPrice.value = 0
  stockBottles.value = 0
  units.value = [
    { name: t('beverages.bottle'), volume_ml: 750, price: 0, is_base: true },
    { name: t('beverages.glass'), volume_ml: 50, price: 0, is_base: false },
    { name: t('beverages.largeGlass'), volume_ml: 100, price: 0, is_base: false },
  ]
  showModal.value = true
}

function onProductChange() {
  const product = selected.value
  if (!product) return
  bottleVolume.value = product.bottle_volume_ml || 750
  costPrice.value = (product.cost_price ?? 0) / 100
  units.value = units.value.map((unit, index) => ({
    ...unit,
    volume_ml: index === 0 ? bottleVolume.value : unit.volume_ml,
    price: index === 0 ? (product.base_price ?? 0) / 100 : unit.price,
  }))
}

function syncBottleVolume() {
  const base = units.value.find(unit => unit.is_base) ?? units.value[0]
  if (base) base.volume_ml = bottleVolume.value
}

function addUnit() {
  units.value.push({ name: '', volume_ml: 50, price: 0, is_base: false })
}

function markBase(index: number) {
  units.value = units.value.map((unit, i) => ({ ...unit, is_base: i === index }))
}

async function save() {
  if (!productId.value) return
  saving.value = true
  try {
    await api.post(`/products/${productId.value}/sale-units`, {
      bottle_volume_ml: bottleVolume.value,
      cost_price: Math.round(Number(costPrice.value) * 100),
      warehouse_id: warehouseId.value || undefined,
      stock_bottles: stockBottles.value,
      units: units.value.map(unit => ({
        name: unit.name,
        volume_ml: Number(unit.volume_ml),
        price: Math.round(Number(unit.price) * 100),
        is_base: unit.is_base,
      })),
    })
    showModal.value = false
    await refresh()
  } finally {
    saving.value = false
  }
}

async function removeBeverage(row: Dashboard['products'][number]) {
  const ok = await confirmDialog(t('beverages.removeMessage', { name: row.name }), {
    title: t('beverages.removeTitle'),
    confirmLabel: t('common.delete'),
    danger: true,
  })
  if (!ok) return

  await api.delete(`/products/${row.id}/sale-units`)
  await refresh()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="m-0 max-w-3xl text-sm text-slate-500">{{ t('beverages.hint') }}</p>
        <div class="flex flex-wrap items-center gap-2">
          <select v-model="warehouseId" class="rounded-lg border border-slate-300 px-3 py-2 text-sm" @change="refresh">
            <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
          </select>
          <button class="rounded-lg bg-[#4a6d86] px-4 py-2 text-sm text-white" @click="openCreate">+ {{ t('beverages.configure') }}</button>
        </div>
      </div>

      <div class="stat-grid">
        <article class="stat">
          <p>{{ t('beverages.todaySales') }}</p>
          <strong>{{ dashboard?.today.sales_count ?? 0 }}</strong>
        </article>
        <article class="stat">
          <p>{{ t('beverages.revenue') }}</p>
          <strong>{{ formatMoney(dashboard?.today.revenue ?? 0) }}</strong>
        </article>
        <article class="stat">
          <p>{{ t('beverages.profit') }}</p>
          <strong class="stat__accent">{{ formatMoney(dashboard?.today.profit ?? 0) }}</strong>
        </article>
        <article class="stat">
          <p>{{ t('beverages.soldMl') }}</p>
          <strong>{{ dashboard?.today.volume_ml ?? 0 }} <span>ml</span></strong>
        </article>
      </div>

      <section class="list">
        <header class="list__head">
          <h2>{{ t('beverages.product') }}</h2>
          <span>{{ dashboard?.products.length ?? 0 }}</span>
        </header>

        <article v-for="row in dashboard?.products ?? []" :key="row.id" class="drink">
          <div class="drink__identity">
            <span class="drink__mark">{{ row.name.trim().charAt(0).toUpperCase() }}</span>
            <div class="min-w-0">
              <h3>{{ row.name }}</h3>
              <p>
                <span class="font-mono">{{ row.sku }}</span>
                <span v-if="row.brand">{{ row.brand }}</span>
                <span>{{ row.bottle_volume_ml }} ml</span>
              </p>
              <button type="button" class="drink__remove" @click="removeBeverage(row)">{{ t('beverages.remove') }}</button>
            </div>
          </div>

          <div class="drink__facts">
            <div>
              <span>{{ t('beverages.stock') }}</span>
              <strong>{{ row.stock.bottles }} {{ t('beverages.bottleShort') }}</strong>
              <small>+ {{ row.stock.remainder_ml }} ml</small>
            </div>
            <div>
              <span>{{ t('beverages.doses') }}</span>
              <strong>{{ row.doses_available }}</strong>
              <small>{{ row.dose_name || '—' }}</small>
            </div>
          </div>

          <ul class="drink__units">
            <li v-for="unit in row.units" :key="unit.id" :class="{ 'is-base': unit.is_base }">
              <span class="drink__unit-name">{{ unit.name }}</span>
              <span class="font-mono">{{ unit.volume_ml }} ml</span>
              <span class="drink__price">{{ formatMoney(unit.price) }}</span>
              <span class="drink__profit">{{ t('beverages.profit') }} {{ formatMoney(unit.profit) }}</span>
            </li>
          </ul>
        </article>

        <p v-if="!dashboard?.products.length" class="list__empty">{{ t('beverages.empty') }}</p>
      </section>

      <section v-if="dashboard?.top_products.length" class="top">
        <h3>{{ t('beverages.top') }}</h3>
        <ol>
          <li v-for="(item, index) in dashboard.top_products" :key="item.name">
            <span class="top__rank">{{ index + 1 }}</span>
            <span class="top__name">{{ item.name }}</span>
            <span class="font-mono">{{ item.quantity }}</span>
            <span class="top__money">{{ formatMoney(item.revenue) }}</span>
          </li>
        </ol>
      </section>
    </div>

    <AppModal :open="showModal" :title="t('beverages.configure')" icon="products" tone="info" size="lg" @close="showModal = false">
      <form class="space-y-4" @submit.prevent="save">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('beverages.product') }}</label>
          <select v-model="productId" required class="w-full rounded-lg border border-slate-300 px-3 py-2" @change="onProductChange">
            <option value="">—</option>
            <option v-for="product in products" :key="product.id" :value="product.id">{{ product.sku }} — {{ product.name }}</option>
          </select>
        </div>
        <div class="grid gap-3 sm:grid-cols-3">
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('beverages.bottleVolume') }}</label>
            <input v-model.number="bottleVolume" type="number" min="1" class="w-full rounded-lg border border-slate-300 px-3 py-2" @change="syncBottleVolume" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('beverages.cost') }}</label>
            <input v-model.number="costPrice" type="number" min="0" step="0.01" class="w-full rounded-lg border border-slate-300 px-3 py-2" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('beverages.stockBottles') }}</label>
            <input v-model.number="stockBottles" type="number" min="0" class="w-full rounded-lg border border-slate-300 px-3 py-2" />
          </div>
        </div>

        <div v-for="(unit, index) in units" :key="index" class="grid gap-2 rounded-lg border border-slate-200 p-3 sm:grid-cols-4">
          <input v-model="unit.name" required class="rounded-lg border border-slate-300 px-3 py-2" :placeholder="t('beverages.unitName')" />
          <input v-model.number="unit.volume_ml" type="number" min="1" class="rounded-lg border border-slate-300 px-3 py-2" :placeholder="t('beverages.ml')" />
          <input v-model.number="unit.price" type="number" min="0" step="0.01" class="rounded-lg border border-slate-300 px-3 py-2" :placeholder="t('beverages.price')" />
          <div class="flex items-center justify-between gap-2">
            <label class="text-sm"><input type="radio" :checked="unit.is_base" @change="markBase(index)" /> {{ t('beverages.base') }}</label>
            <button v-if="units.length > 1" type="button" class="text-sm text-red-600" @click="units.splice(index, 1)">{{ t('common.delete') }}</button>
          </div>
        </div>
        <button type="button" class="text-sm text-[#4a6d86]" @click="addUnit">+ {{ t('beverages.addUnit') }}</button>
        <p class="text-xs text-slate-500">{{ t('beverages.yieldHint', { count: bottleVolume && units[1] ? Math.floor(bottleVolume / (units[1].volume_ml || 1)) : 0 }) }}</p>
        <div class="flex justify-end gap-2">
          <button type="button" class="rounded-lg border border-slate-300 px-4 py-2" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="rounded-lg bg-[#4a6d86] px-4 py-2 text-white" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.stat-grid {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.stat {
  padding: 0.9rem 1rem;
  border-radius: 0.9rem;
  background: #fff;
  border: 1px solid #e6edf3;
}

.stat p {
  margin: 0;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #94a3b8;
}

.stat strong {
  display: block;
  margin-top: 0.35rem;
  font-family: var(--font-mono);
  font-size: 1.25rem;
  font-weight: 650;
  color: #1c2830;
}

.stat strong span {
  font-size: 0.75rem;
  color: #94a3b8;
}

.stat__accent {
  color: #4a6d86;
}

.list,
.top {
  overflow: hidden;
  border-radius: 1rem;
  background: #fff;
  border: 1px solid #e6edf3;
}

.list__head,
.top h3 {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 0;
  padding: 0.85rem 1rem;
  font-size: 0.82rem;
  font-weight: 700;
  color: #1c2830;
  border-bottom: 1px solid #eef2f6;
}

.list__head span {
  min-width: 1.6rem;
  padding: 0.1rem 0.45rem;
  border-radius: 999px;
  background: #f4f1ea;
  color: #8a6420;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  text-align: center;
}

.drink {
  display: grid;
  grid-template-columns: minmax(14rem, 1.1fr) 13rem minmax(16rem, 1.4fr);
  gap: 1rem;
  align-items: start;
  padding: 1rem;
  border-top: 1px solid #f1f5f9;
}

.drink:first-of-type {
  border-top: 0;
}

.drink__identity {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  min-width: 0;
}

.drink__mark {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  height: 2.4rem;
  flex-shrink: 0;
  border-radius: 0.7rem;
  background: #e7eef3;
  color: #4a6d86;
  font-weight: 700;
}

.drink__identity h3 {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 650;
  color: #1c2830;
}

.drink__identity p {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem 0.55rem;
  margin: 0.2rem 0 0;
  font-size: 0.72rem;
  color: #94a3b8;
}

.drink__remove {
  margin-top: 0.35rem;
  padding: 0;
  border: 0;
  background: transparent;
  color: #b45309;
  font-size: 0.75rem;
  font-weight: 650;
  cursor: pointer;
}

.drink__remove:hover {
  color: #9a3412;
}

.drink__facts {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
}

.drink__facts div {
  padding: 0.55rem 0.65rem;
  border-radius: 0.7rem;
  background: #f8fafc;
}

.drink__facts span,
.drink__facts small {
  display: block;
  color: #94a3b8;
  font-size: 0.68rem;
}

.drink__facts strong {
  display: block;
  margin-top: 0.15rem;
  font-family: var(--font-mono);
  font-size: 0.92rem;
  color: #1c2830;
}

.drink__units {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.drink__units li {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 0.15rem 0.7rem;
  align-items: baseline;
  padding: 0.45rem 0.6rem;
  border-radius: 0.7rem;
  border: 1px solid #eef2f6;
}

.drink__units li.is-base {
  border-color: #ead9b4;
  background: #fbf8f2;
}

.drink__unit-name {
  font-size: 0.78rem;
  font-weight: 650;
  color: #1c2830;
}

.drink__units .font-mono,
.drink__price,
.drink__profit {
  font-size: 0.72rem;
}

.drink__units .font-mono {
  color: #94a3b8;
}

.drink__price {
  font-family: var(--font-mono);
  font-weight: 650;
  color: #4a6d86;
}

.drink__profit {
  grid-column: 1 / -1;
  color: #8a6420;
}

.list__empty {
  margin: 0;
  padding: 2.5rem 1rem;
  text-align: center;
  color: #94a3b8;
}

.top {
  padding-bottom: 0.4rem;
}

.top ol {
  margin: 0;
  padding: 0.35rem 0.5rem 0.6rem;
  list-style: none;
}

.top li {
  display: grid;
  grid-template-columns: 1.6rem minmax(0, 1fr) auto auto;
  gap: 0.7rem;
  align-items: center;
  padding: 0.45rem 0.5rem;
  font-size: 0.85rem;
  color: #334155;
}

.top__rank {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.35rem;
  height: 1.35rem;
  border-radius: 999px;
  background: #e7eef3;
  color: #4a6d86;
  font-size: 0.68rem;
  font-weight: 700;
}

.top__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.top__money {
  font-family: var(--font-mono);
  font-weight: 650;
  color: #1c2830;
}

@media (max-width: 1100px) {
  .stat-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .drink {
    grid-template-columns: 1fr;
  }
}
</style>

