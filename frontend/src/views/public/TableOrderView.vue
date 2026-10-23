<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { setAppLocale } from '../../i18n'
import type { AppLocale } from '../../i18n/locales'
import { formatMoney } from '../../utils/format'

type Side = { id: string; name: string }
type Variant = { id: string; name: string; price: number }
type SaleUnit = { id: string; name: string; price: number }
type Product = {
  id: string
  name: string
  description?: string | null
  price: number
  image_url?: string | null
  available: boolean
  variants: Variant[]
  sale_units: SaleUnit[]
  sides: Side[]
}
type Category = { name: string; products: Product[] }
type OrderItem = {
  id: string
  product_id?: string
  name: string
  quantity: number
  note?: string | null
  line_total: number
  options?: { variant_name?: string | null; sides?: Side[]; extras?: { id: string; name: string; quantity: number }[] }
}
type GuestOrder = {
  id: string
  guest_status: string
  rejection_reason?: string | null
  subtotal: number
  tax_total: number
  total: number
  currency: string
  created_at?: string
  items: OrderItem[]
}
type Menu = {
  restaurant: string
  logo_url?: string | null
  table: { name: string; code?: string }
  currency: string
  ordering_open: boolean
  ordering_message?: string | null
  cashier_present: boolean
  categories: Category[]
  orders: GuestOrder[]
}
type CartLine = {
  key: string
  product_id: string
  name: string
  quantity: number
  note: string
  variant_id?: string
  variant_name?: string
  sale_unit_id?: string
  unit_name?: string
  side_ids: string[]
  side_names: string[]
  extras: { product_id: string; name: string; quantity: number }[]
  unit_price: number
}

const route = useRoute()
const { locale } = useI18n()
const token = computed(() => String(route.query.table || ''))
const apiBase = import.meta.env.VITE_API_BASE_URL ?? '/api/v1'

const copy = computed(() => {
  const lang = String(locale.value).slice(0, 2)
  const fr = {
    invalid: 'Ce QR code est invalide ou désactivé.',
    closed: 'La commande est fermée pour cette table.',
    cashierAway: 'Le caissier n’est pas connecté. La commande reste en attente.',
    search: 'Rechercher un plat',
    unavailable: 'Indisponible',
    add: 'Ajouter',
    note: 'Note pour la cuisine',
    notePh: 'Sans sucre, peu salé…',
    sides: 'Accompagnements',
    qty: 'Quantité',
    cart: 'Panier',
    send: 'Envoyer la commande',
    update: 'Mettre à jour',
    empty: 'Le panier est vide.',
    taxes: 'Taxes',
    total: 'Total',
    sent: 'Envoyée',
    approved: 'Approuvée',
    preparing: 'En préparation',
    ready: 'Prête',
    served: 'Servie',
    rejected: 'Refusée',
    cancelled: 'Annulée',
    kitchen_cancelled: 'Annulée en cuisine',
    track: 'Suivi',
    again: 'Commander autre chose',
    cancel: 'Annuler la commande',
    edit: 'Modifier',
    back: 'Retour',
    options: 'Option',
  }
  const en: typeof fr = {
    invalid: 'This QR code is invalid or disabled.',
    closed: 'Ordering is closed for this table.',
    cashierAway: 'The cashier is away. Your order will wait.',
    search: 'Search the menu',
    unavailable: 'Unavailable',
    add: 'Add',
    note: 'Note for the kitchen',
    notePh: 'No sugar, light salt…',
    sides: 'Sides',
    qty: 'Quantity',
    cart: 'Cart',
    send: 'Send order',
    update: 'Update order',
    empty: 'Your cart is empty.',
    taxes: 'Tax',
    total: 'Total',
    sent: 'Sent',
    approved: 'Approved',
    preparing: 'Preparing',
    ready: 'Ready',
    served: 'Served',
    rejected: 'Declined',
    cancelled: 'Cancelled',
    kitchen_cancelled: 'Cancelled in the kitchen',
    track: 'Status',
    again: 'Order something else',
    cancel: 'Cancel order',
    edit: 'Edit',
    back: 'Back',
    options: 'Option',
  }
  const sw: typeof fr = {
    invalid: 'Msimbo huu si sahihi au umezimwa.',
    closed: 'Oda imefungwa kwenye meza hii.',
    cashierAway: 'Keshia hayupo. Oda itasubiri.',
    search: 'Tafuta chakula',
    unavailable: 'Haipatikani',
    add: 'Ongeza',
    note: 'Ujumbe kwa jikoni',
    notePh: 'Bila sukari…',
    sides: 'Vyakula vya nyongeza',
    qty: 'Idadi',
    cart: 'Kikapu',
    send: 'Tuma oda',
    update: 'Sasisha oda',
    empty: 'Kikapu ni tupu.',
    taxes: 'Kodi',
    total: 'Jumla',
    sent: 'Imetumwa',
    approved: 'Imekubaliwa',
    preparing: 'Inaandaliwa',
    ready: 'Iko tayari',
    served: 'Imeletwa',
    rejected: 'Imekataliwa',
    cancelled: 'Imefutwa',
    kitchen_cancelled: 'Imefutwa jikoni',
    track: 'Hali',
    again: 'Agiza tena',
    cancel: 'Futa oda',
    edit: 'Hariri',
    back: 'Rudi',
    options: 'Chaguo',
  }
  return lang === 'en' ? en : lang === 'sw' ? sw : fr
})

const menu = ref<Menu | null>(null)
const error = ref('')
const loading = ref(true)
const sending = ref(false)
const query = ref('')
const category = ref('')
const cartOpen = ref(false)
const sheet = ref<Product | null>(null)
const draftQty = ref(1)
const draftNote = ref('')
const draftVariant = ref('')
const draftUnit = ref('')
const draftSides = ref<string[]>([])
const cart = ref<CartLine[]>([])
const activeOrder = ref<GuestOrder | null>(null)
const editingId = ref<string | null>(null)
const idempotencyKey = ref('')
let poll: number | undefined

const storageKey = computed(() => `itara.qr.cart.${token.value}`)

const products = computed(() => menu.value?.categories.flatMap(group => group.products.map(product => ({ ...product, category: group.name }))) ?? [])
const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  return products.value.filter(product => {
    if (category.value && product.category !== category.value) return false
    if (!q) return true
    return product.name.toLowerCase().includes(q) || (product.description || '').toLowerCase().includes(q)
  })
})
const cartCount = computed(() => cart.value.reduce((sum, line) => sum + line.quantity, 0))
const cartEstimate = computed(() => cart.value.reduce((sum, line) => sum + line.unit_price * line.quantity, 0))

function statusLabel(status: string) {
  const labels = copy.value as Record<string, string>
  return labels[status] || status
}

async function publicFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${apiBase}${path}`, {
    ...init,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': String(locale.value || 'fr'),
      ...(init?.headers || {}),
    },
  })
  const body = await response.json().catch(() => ({}))
  if (!response.ok) {
    const message = body?.message
      || body?.errors?.items?.[0]
      || body?.errors?.table?.[0]
      || copy.value.invalid
    throw new Error(typeof message === 'string' ? message : copy.value.invalid)
  }
  return body as T
}

async function loadMenu() {
  if (!token.value) {
    error.value = copy.value.invalid
    loading.value = false
    return
  }
  try {
    const body = await publicFetch<{ data: Menu }>(`/public/qr/${token.value}`)
    menu.value = body.data
    if (!category.value && body.data.categories[0]) category.value = body.data.categories[0].name
    error.value = ''
  } catch (err) {
    error.value = err instanceof Error ? err.message : copy.value.invalid
    menu.value = null
  } finally {
    loading.value = false
  }
}

function restoreCart() {
  try {
    const raw = localStorage.getItem(storageKey.value)
    cart.value = raw ? JSON.parse(raw) as CartLine[] : []
  } catch {
    cart.value = []
  }
}

watch(cart, (lines) => {
  if (!token.value) return
  localStorage.setItem(storageKey.value, JSON.stringify(lines))
}, { deep: true })

function openProduct(product: Product) {
  if (!product.available || !menu.value?.ordering_open) return
  sheet.value = product
  draftQty.value = 1
  draftNote.value = ''
  draftVariant.value = product.variants[0]?.id || ''
  draftUnit.value = product.sale_units[0]?.id || ''
  draftSides.value = []
}

function addDraft() {
  const product = sheet.value
  if (!product) return
  const variant = product.variants.find(item => item.id === draftVariant.value)
  const unit = product.sale_units.find(item => item.id === draftUnit.value)
  const sides = product.sides.filter(side => draftSides.value.includes(side.id))
  cart.value.push({
    key: crypto.randomUUID(),
    product_id: product.id,
    name: product.name,
    quantity: draftQty.value,
    note: draftNote.value.trim(),
    variant_id: variant?.id,
    variant_name: variant?.name,
    sale_unit_id: unit?.id,
    unit_name: unit?.name,
    side_ids: sides.map(side => side.id),
    side_names: sides.map(side => side.name),
    extras: [],
    unit_price: unit?.price ?? variant?.price ?? product.price,
  })
  sheet.value = null
  cartOpen.value = true
}

function payloadItems() {
  return cart.value.map(line => ({
    product_id: line.product_id,
    quantity: line.quantity,
    note: line.note || null,
    variant_id: line.variant_id || null,
    sale_unit_id: line.sale_unit_id || null,
    side_ids: line.side_ids,
    extras: line.extras.map(extra => ({ product_id: extra.product_id, quantity: extra.quantity })),
  }))
}

async function sendCart() {
  if (!menu.value?.ordering_open || cart.value.length === 0 || sending.value) return
  sending.value = true
  error.value = ''
  if (!idempotencyKey.value) idempotencyKey.value = crypto.randomUUID()
  try {
    const path = editingId.value
      ? `/public/qr/${token.value}/orders/${editingId.value}`
      : `/public/qr/${token.value}/orders`
    const body = await publicFetch<{ data: GuestOrder }>(path, {
      method: editingId.value ? 'PATCH' : 'POST',
      body: JSON.stringify(editingId.value
        ? { items: payloadItems() }
        : { idempotency_key: idempotencyKey.value, locale: String(locale.value).slice(0, 2), items: payloadItems() }),
    })
    activeOrder.value = body.data
    cart.value = []
    editingId.value = null
    idempotencyKey.value = ''
    cartOpen.value = false
    await loadMenu()
  } catch (err) {
    error.value = err instanceof Error ? err.message : copy.value.invalid
  } finally {
    sending.value = false
  }
}

async function refreshOrder() {
  if (!activeOrder.value || !token.value) return
  try {
    const body = await publicFetch<{ data: GuestOrder }>(`/public/qr/${token.value}/orders/${activeOrder.value.id}`)
    activeOrder.value = body.data
  } catch {
    /* keep the last status on a brief network drop */
  }
}

async function cancelOrder() {
  if (!activeOrder.value) return
  const body = await publicFetch<{ data: GuestOrder }>(`/public/qr/${token.value}/orders/${activeOrder.value.id}/cancel`, { method: 'POST' })
  activeOrder.value = body.data
}

function editOrder() {
  const order = activeOrder.value
  if (!order || order.guest_status !== 'sent') return
  editingId.value = order.id
  cart.value = order.items.map(item => ({
    key: item.id,
    product_id: item.product_id || '',
    name: item.name,
    quantity: item.quantity,
    note: item.note || '',
    side_ids: (item.options?.sides || []).map(side => side.id),
    side_names: (item.options?.sides || []).map(side => side.name),
    extras: (item.options?.extras || []).map(extra => ({ product_id: extra.id, name: extra.name, quantity: extra.quantity })),
    unit_price: Math.round(item.line_total / Math.max(1, item.quantity)),
  })).filter(line => line.product_id)
  activeOrder.value = null
  cartOpen.value = true
}

function setLang(lang: AppLocale) {
  void setAppLocale(lang)
}

onMounted(() => {
  restoreCart()
  void loadMenu()
  poll = window.setInterval(() => { void refreshOrder() }, 4000)
})
onBeforeUnmount(() => {
  if (poll) window.clearInterval(poll)
})
</script>

<template>
  <div class="qr">
    <header class="qr__top">
      <div>
        <p class="qr__brand">{{ menu?.restaurant || 'ITARA' }}</p>
        <h1>{{ menu?.table.name || 'Table' }}</h1>
      </div>
      <div class="qr__langs">
        <button type="button" :class="{ on: String(locale).startsWith('fr') }" @click="setLang('fr')">FR</button>
        <button type="button" :class="{ on: String(locale).startsWith('en') }" @click="setLang('en')">EN</button>
        <button type="button" :class="{ on: String(locale).startsWith('sw') }" @click="setLang('sw')">SW</button>
      </div>
    </header>

    <p v-if="loading" class="qr__note">…</p>
    <p v-else-if="error && !menu" class="qr__note qr__note--bad">{{ error }}</p>
    <template v-else-if="menu">
      <p v-if="!menu.ordering_open" class="qr__note qr__note--bad">{{ menu.ordering_message || copy.closed }}</p>
      <p v-else-if="!menu.cashier_present" class="qr__note">{{ copy.cashierAway }}</p>
      <p v-if="error && menu" class="qr__note qr__note--bad">{{ error }}</p>

      <section v-if="activeOrder" class="qr__track">
        <p class="qr__kicker">{{ copy.track }}</p>
        <h2>{{ statusLabel(activeOrder.guest_status) }}</h2>
        <p v-if="activeOrder.rejection_reason">{{ activeOrder.rejection_reason }}</p>
        <ul>
          <li v-for="item in activeOrder.items" :key="item.id">
            <span>{{ item.quantity }} × {{ item.name }}</span>
            <span>{{ formatMoney(item.line_total, activeOrder.currency) }}</span>
            <small v-if="item.note">{{ item.note }}</small>
          </li>
        </ul>
        <p class="qr__total"><span>{{ copy.taxes }}</span><span>{{ formatMoney(activeOrder.tax_total, activeOrder.currency) }}</span></p>
        <p class="qr__total"><strong>{{ copy.total }}</strong><strong>{{ formatMoney(activeOrder.total, activeOrder.currency) }}</strong></p>
        <div class="qr__row">
          <button v-if="activeOrder.guest_status === 'sent'" type="button" class="qr__ghost" @click="editOrder">{{ copy.edit }}</button>
          <button v-if="activeOrder.guest_status === 'sent'" type="button" class="qr__ghost" @click="cancelOrder">{{ copy.cancel }}</button>
          <button type="button" class="qr__go" @click="activeOrder = null">{{ copy.again }}</button>
        </div>
      </section>

      <template v-else>
        <input v-model="query" class="qr__search" type="search" :placeholder="copy.search">
        <div class="qr__tabs">
          <button
            v-for="group in menu.categories"
            :key="group.name"
            type="button"
            :class="{ on: category === group.name }"
            @click="category = group.name"
          >{{ group.name }}</button>
        </div>
        <article v-for="product in filtered" :key="product.id" class="qr__card" :class="{ off: !product.available }">
          <img v-if="product.image_url" :src="product.image_url" alt="">
          <div>
            <h2>{{ product.name }}</h2>
            <p v-if="product.description">{{ product.description }}</p>
            <footer>
              <strong>{{ formatMoney(product.price, menu.currency) }}</strong>
              <button type="button" :disabled="!product.available || !menu.ordering_open" @click="openProduct(product)">
                {{ product.available ? copy.add : copy.unavailable }}
              </button>
            </footer>
          </div>
        </article>
      </template>
    </template>

    <button v-if="cartCount && !activeOrder" type="button" class="qr__fab" @click="cartOpen = true">
      {{ copy.cart }} · {{ cartCount }} · {{ formatMoney(cartEstimate, menu?.currency) }}
    </button>

    <div v-if="sheet" class="qr__sheet" @click.self="sheet = null">
      <form @submit.prevent="addDraft">
        <h2>{{ sheet.name }}</h2>
        <p>{{ formatMoney(sheet.price, menu?.currency) }}</p>
        <label v-if="sheet.variants.length">{{ copy.options }}
          <select v-model="draftVariant">
            <option v-for="variant in sheet.variants" :key="variant.id" :value="variant.id">{{ variant.name }}</option>
          </select>
        </label>
        <label v-if="sheet.sale_units.length">{{ copy.options }}
          <select v-model="draftUnit">
            <option v-for="unit in sheet.sale_units" :key="unit.id" :value="unit.id">{{ unit.name }} · {{ formatMoney(unit.price, menu?.currency) }}</option>
          </select>
        </label>
        <fieldset v-if="sheet.sides.length">
          <legend>{{ copy.sides }}</legend>
          <label v-for="side in sheet.sides" :key="side.id">
            <input v-model="draftSides" type="checkbox" :value="side.id"> {{ side.name }}
          </label>
        </fieldset>
        <label>{{ copy.qty }}
          <input v-model.number="draftQty" type="number" min="1" max="20">
        </label>
        <label>{{ copy.note }}
          <input v-model="draftNote" maxlength="200" :placeholder="copy.notePh">
        </label>
        <button type="submit" class="qr__go">{{ copy.add }}</button>
      </form>
    </div>

    <div v-if="cartOpen" class="qr__sheet" @click.self="cartOpen = false">
      <div>
        <h2>{{ copy.cart }}</h2>
        <p v-if="!cart.length">{{ copy.empty }}</p>
        <article v-for="line in cart" :key="line.key" class="qr__line">
          <div>
            <strong>{{ line.name }}</strong>
            <small v-if="line.variant_name || line.unit_name">{{ line.variant_name || line.unit_name }}</small>
            <small v-if="line.side_names.length">{{ line.side_names.join(', ') }}</small>
            <small v-if="line.note">{{ line.note }}</small>
          </div>
          <input v-model.number="line.quantity" type="number" min="1" max="20">
          <button type="button" @click="cart = cart.filter(item => item.key !== line.key)">×</button>
        </article>
        <button type="button" class="qr__go" :disabled="sending || !cart.length" @click="sendCart">
          {{ editingId ? copy.update : copy.send }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.qr {
  min-height: 100vh;
  background: #f4f7f5;
  color: #14211c;
  font-family: "IBM Plex Sans", sans-serif;
  padding: 1rem 1rem 6rem;
}
.qr__top, .qr__card footer, .qr__row, .qr__total, .qr__line {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  align-items: center;
}
.qr__brand { margin: 0; color: #3d6b58; font-size: 0.8rem; letter-spacing: 0.04em; text-transform: uppercase; }
h1, h2 { margin: 0; font-family: "Plus Jakarta Sans", sans-serif; }
.qr__langs button, .qr__tabs button, .qr__card button, .qr__go, .qr__ghost, .qr__fab {
  border: 0;
  border-radius: 999px;
  padding: 0.45rem 0.8rem;
  background: #fff;
}
.qr__langs button.on, .qr__tabs button.on, .qr__go, .qr__fab { background: #1f6b4a; color: #fff; }
.qr__tabs { display: flex; gap: 0.4rem; overflow: auto; position: sticky; top: 0; background: #f4f7f5; padding: 0.6rem 0; }
.qr__search, .qr__sheet input, .qr__sheet select {
  width: 100%;
  border: 1px solid #d5e0da;
  border-radius: 0.8rem;
  padding: 0.75rem 0.9rem;
  background: #fff;
}
.qr__card, .qr__track, .qr__sheet form, .qr__sheet > div {
  background: #fff;
  border-radius: 1rem;
  padding: 0.9rem;
  margin-top: 0.7rem;
}
.qr__card { display: grid; grid-template-columns: 72px 1fr; gap: 0.8rem; }
.qr__card.off { opacity: 0.55; }
.qr__card img { width: 72px; height: 72px; object-fit: cover; border-radius: 0.7rem; }
.qr__card p, .qr__line small { margin: 0.2rem 0 0; color: #5c6b64; font-size: 0.85rem; }
.qr__note { background: #fff8e8; border-radius: 0.8rem; padding: 0.7rem 0.9rem; }
.qr__note--bad { background: #fde8e8; }
.qr__fab { position: fixed; left: 1rem; right: 1rem; bottom: 1rem; padding: 0.9rem; }
.qr__sheet { position: fixed; inset: 0; background: rgba(20, 33, 28, 0.35); display: flex; align-items: flex-end; }
.qr__sheet form, .qr__sheet > div { width: min(32rem, 100%); margin: 0 auto; border-bottom-left-radius: 0; border-bottom-right-radius: 0; }
.qr__line { align-items: flex-start; }
.qr__line input { width: 4rem; }
.qr__go { width: 100%; margin-top: 0.8rem; }
.qr__track ul { list-style: none; padding: 0; }
.qr__track li { display: grid; grid-template-columns: 1fr auto; gap: 0.2rem 0.8rem; margin: 0.45rem 0; }
.qr__track small { grid-column: 1 / -1; color: #5c6b64; }
</style>
