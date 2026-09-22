<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import AppIcon from '../../../components/ui/AppIcon.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Customer } from '../../../types'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>

type GuestRow = {
  key: string
  customer_id: string | null
  name: string
  email: string
  phone: string
  code: string
  is_active: boolean
  reservations: number
  stays: number
  last_arrive: string
  last_status: string
  last_room: string
  last_code: string
}

const { t } = useI18n()
const store = useBackofficeStore()
const ctx = useContextStore()

const docs = ref<Doc[]>([])
const loading = ref(false)
const error = ref('')
const search = ref('')

const reservations = computed(() =>
  docs.value.filter(d => d.kind === 'reservation'),
)

function isHotelCustomer(c: Customer) {
  const meta = c.metadata
  return Boolean(meta && typeof meta === 'object' && (meta as Record<string, unknown>).hotel_guest)
}

function statusOf(row: Doc) {
  return String(row.status || '')
}

function isStay(row: Doc) {
  return ['checked_in', 'checked_out'].includes(statusOf(row))
}

const guests = computed<GuestRow[]>(() => {
  const byKey = new Map<string, GuestRow>()

  function ensure(key: string, seed: Partial<GuestRow> & { name: string }): GuestRow {
    let row = byKey.get(key)
    if (!row) {
      row = {
        key,
        customer_id: seed.customer_id ?? null,
        name: seed.name,
        email: seed.email || '',
        phone: seed.phone || '',
        code: seed.code || '',
        is_active: seed.is_active !== false,
        reservations: 0,
        stays: 0,
        last_arrive: '',
        last_status: '',
        last_room: '',
        last_code: '',
      }
      byKey.set(key, row)
    }
    return row
  }

  for (const rsv of reservations.value) {
    const customerId = String(rsv.customer_id || '').trim()
    const name = String(rsv.guest_name || '').trim() || t('hotel.guests.unknown')
    const email = String(rsv.guest_email || '').trim()
    const phone = String(rsv.guest_phone || '').trim()
    const key = customerId
      ? `id:${customerId}`
      : `guest:${name.toLowerCase()}|${email.toLowerCase()}|${phone}`

    const customer = customerId
      ? store.customers.find(c => c.id === customerId)
      : undefined

    const row = ensure(key, {
      customer_id: customerId || null,
      name: customer?.name || name,
      email: customer?.email || email,
      phone: customer?.phone || phone,
      code: customer?.code || '',
      is_active: customer?.is_active !== false,
    })

    row.reservations += 1
    if (isStay(rsv)) row.stays += 1

    const arrive = String(rsv.arrive_on || rsv.checked_in_at || '').slice(0, 10)
    if (arrive && (!row.last_arrive || arrive >= row.last_arrive)) {
      row.last_arrive = arrive
      row.last_status = statusOf(rsv)
      row.last_room = String(rsv.room_number || '')
      row.last_code = String(rsv.stay_code || rsv.reservation_no || rsv.booking_code || '')
    }
  }

  for (const customer of store.customers) {
    if (!isHotelCustomer(customer)) continue
    const key = `id:${customer.id}`
    if (byKey.has(key)) continue
    ensure(key, {
      customer_id: customer.id,
      name: customer.name,
      email: customer.email || '',
      phone: customer.phone || '',
      code: customer.code || '',
      is_active: customer.is_active !== false,
    })
  }

  return Array.from(byKey.values()).sort((a, b) => {
    if (a.last_arrive && b.last_arrive) return b.last_arrive.localeCompare(a.last_arrive)
    if (a.last_arrive) return -1
    if (b.last_arrive) return 1
    return a.name.localeCompare(b.name)
  })
})

const filteredGuests = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return guests.value
  return guests.value.filter((g) => {
    const hay = `${g.name} ${g.email} ${g.phone} ${g.code} ${g.last_room} ${g.last_code}`.toLowerCase()
    return hay.includes(q)
  })
})

const stats = computed(() => ({
  total: guests.value.length,
  withStay: guests.value.filter(g => g.stays > 0).length,
  active: guests.value.filter(g => g.is_active).length,
}))

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return parts.slice(0, 2).map(p => p[0]?.toUpperCase() || '').join('')
}

function statusLabel(status: string) {
  if (!status) return '—'
  const key = `hotel.reservations.status.${status}`
  const translated = t(key)
  return translated === key ? status : translated
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [docsRes] = await Promise.all([
      api.get<{ data: { docs: Doc[] } }>('/hospitality'),
      store.loadCustomers().catch(() => undefined),
    ])
    docs.value = docsRes.data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

watch(() => ctx.currentStoreId, () => { load() })
onMounted(load)
</script>

<template>
  <HotelChrome scroll-body>
    <div class="hg">
      <header class="hg__head">
        <div>
          <h2>{{ t('hotel.guests.title') }}</h2>
          <p>{{ t('hotel.guests.subtitle') }}</p>
        </div>
        <div class="hg__actions">
          <button type="button" class="btn btn--ghost" :disabled="loading" @click="load">
            {{ t('common.refresh') }}
          </button>
          <RouterLink class="btn btn--primary" to="/admin/hotel/reservations">
            <AppIcon name="calendar" :size="14" />
            {{ t('hotel.guests.newReservation') }}
          </RouterLink>
        </div>
      </header>

      <p v-if="error" class="hg__error">{{ error }}</p>

      <section class="hg__stats">
        <article class="hg__stat">
          <span>{{ t('hotel.guests.stats.total') }}</span>
          <strong>{{ stats.total }}</strong>
        </article>
        <article class="hg__stat">
          <span>{{ t('hotel.guests.stats.withStay') }}</span>
          <strong>{{ stats.withStay }}</strong>
        </article>
        <article class="hg__stat">
          <span>{{ t('hotel.guests.stats.active') }}</span>
          <strong>{{ stats.active }}</strong>
        </article>
      </section>

      <div class="hg__toolbar">
        <input
          v-model="search"
          class="field hg__search"
          :placeholder="t('hotel.guests.searchPh')"
        >
      </div>

      <div class="hg__table-wrap">
        <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />
        <table v-else class="hg__table">
          <thead>
            <tr>
              <th>{{ t('hotel.guests.cols.client') }}</th>
              <th>{{ t('hotel.guests.cols.contact') }}</th>
              <th>{{ t('hotel.guests.cols.reservations') }}</th>
              <th>{{ t('hotel.guests.cols.stays') }}</th>
              <th>{{ t('hotel.guests.cols.lastStay') }}</th>
              <th>{{ t('hotel.guests.cols.status') }}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in filteredGuests" :key="row.key">
              <td>
                <div class="hg__client">
                  <span class="hg__avatar">{{ initials(row.name) }}</span>
                  <div>
                    <strong>{{ row.name }}</strong>
                    <small v-if="row.code">{{ row.code }}</small>
                  </div>
                </div>
              </td>
              <td>
                <div class="hg__contact">
                  <span>{{ row.email || '—' }}</span>
                  <small>{{ row.phone || '—' }}</small>
                </div>
              </td>
              <td>{{ row.reservations }}</td>
              <td>{{ row.stays }}</td>
              <td>
                <div class="hg__last">
                  <strong>{{ row.last_arrive || '—' }}</strong>
                  <small v-if="row.last_room">#{{ row.last_room }}</small>
                  <small v-else-if="row.last_code">{{ row.last_code }}</small>
                </div>
              </td>
              <td>
                <span class="hg-pill" :class="row.is_active ? 'hg-pill--on' : 'hg-pill--off'">
                  {{ row.is_active ? t('hotel.guests.active') : t('hotel.guests.inactive') }}
                </span>
                <small v-if="row.last_status" class="hg__status">{{ statusLabel(row.last_status) }}</small>
              </td>
              <td>
                <RouterLink
                  v-if="row.customer_id"
                  class="hg__link"
                  :to="`/admin/customers/${row.customer_id}`"
                >
                  {{ t('common.view') }}
                </RouterLink>
                <span v-else class="hg__muted-inline">—</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!loading && !filteredGuests.length" class="hg__empty">
          {{ t('hotel.guests.empty') }}
        </p>
      </div>
    </div>
  </HotelChrome>
</template>

<style scoped>
.hg {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-bottom: 1.5rem;
}

.hg__head {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.85rem;
  align-items: flex-start;
}

.hg__head h2 {
  margin: 0;
  font-size: 1.35rem;
  color: #1c2830;
}

.hg__head p {
  margin: 0.25rem 0 0;
  color: #66727c;
  font-size: 0.88rem;
}

.hg__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.hg__error {
  margin: 0;
  color: #b91c1c;
  font-size: 0.88rem;
}

.hg__stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.65rem;
}

.hg__stat {
  background: #fff;
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
  padding: 0.85rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.hg__stat span {
  font-size: 0.78rem;
  font-weight: 700;
  color: #64748b;
}

.hg__stat strong {
  font-size: 1.45rem;
  color: #1c2830;
}

.hg__toolbar {
  display: flex;
  gap: 0.5rem;
}

.hg__search {
  flex: 1;
  min-width: 12rem;
}

.hg__table-wrap {
  background: #fff;
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
  overflow: auto;
}

.hg__table {
  width: 100%;
  border-collapse: collapse;
  min-width: 820px;
}

.hg__table th,
.hg__table td {
  padding: 0.75rem 0.85rem;
  text-align: left;
  border-bottom: 1px solid #eef2f6;
  vertical-align: middle;
}

.hg__table th {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #7b8d9a;
  background: #f8fafc;
  font-weight: 700;
}

.hg__client {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.hg__client strong,
.hg__contact span,
.hg__last strong {
  display: block;
  color: #1c2830;
  font-size: 0.88rem;
}

.hg__client small,
.hg__contact small,
.hg__last small,
.hg__status {
  display: block;
  color: #7b8d9a;
  font-size: 0.72rem;
  margin-top: 0.15rem;
}

.hg__avatar {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  background: #be185d;
  color: #fff;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.72rem;
  font-weight: 700;
  flex-shrink: 0;
}

.hg-pill {
  display: inline-flex;
  padding: 0.18rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
}

.hg-pill--on { background: #d1fae5; color: #047857; }
.hg-pill--off { background: #f1f5f9; color: #64748b; }

.hg__link {
  color: var(--color-brand-600, var(--color-brand-600));
  font-weight: 700;
  font-size: 0.78rem;
  text-decoration: none;
}

.hg__empty,
.hg__muted {
  margin: 0;
  padding: 1.25rem;
  color: #7b8d9a;
  font-size: 0.88rem;
}

.hg__muted-inline { color: #94a3b8; }

@media (max-width: 720px) {
  .hg__stats { grid-template-columns: 1fr; }
}
</style>
