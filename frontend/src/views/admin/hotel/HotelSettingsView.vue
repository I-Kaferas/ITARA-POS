<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { computeStayTaxes } from '../../../utils/hotelSettings'
import { formatDateTime } from '../../../utils/format'
import { getAppCurrency } from '../../../utils/currency'
import HotelChrome from './HotelChrome.vue'

type HotelSettings = {
  check_in_time: string
  check_out_time: string
  early_arrival_limit: string
  early_arrival_fee: number
  late_departure_limit: string
  late_departure_fee: number
  deposit_amount: number
  free_cancel_hours: number
  cancel_penalty_percent: number
  charge_no_shows: boolean
  no_show_penalty_percent: number
  vat_enabled: boolean
  vat_rate: number
  tc_enabled: boolean
  tc_rate: number
  room_price_tax_inclusive: boolean
  occupancy_tax_enabled: boolean
  service_fee_enabled: boolean
  currency_code: string
  currency_symbol: string
  currency_symbol_position: 'before' | 'after'
  allow_overbooking: boolean
  hk_shift_start: string
  hk_shift_end: string
  auto_dirty_on_checkout: boolean
  notify_arrival: boolean
  notify_departure: boolean
  notify_new_reservation: boolean
  notify_unpaid_balance: boolean
  saved_at: string | null
}

const { t, locale } = useI18n()
const store = useBackofficeStore()

const loading = ref(false)
const saving = ref(false)
const error = ref('')
const message = ref('')
const form = reactive<HotelSettings>(emptySettings())

const currencyOptions = computed(() =>
  store.currencies
    .filter(c => c.is_active)
    .slice()
    .sort((a, b) => Number(b.is_default) - Number(a.is_default) || a.code.localeCompare(b.code)),
)

const selectedCurrency = computed(() =>
  currencyOptions.value.find(c => c.code === form.currency_code)
  ?? store.currencies.find(c => c.code === form.currency_code)
  ?? null,
)

const moneyPreview = computed(() => formatMoneyPreview(100, form.currency_symbol, form.currency_symbol_position))

const exampleNight = computed(() => {
  const entered = 40
  const taxes = computeStayTaxes(Math.round(entered * 100), {
    vat_enabled: form.vat_enabled,
    vat_rate: form.vat_rate,
    tc_enabled: form.tc_enabled,
    tc_rate: form.tc_rate,
    room_price_tax_inclusive: form.room_price_tax_inclusive,
  })
  return {
    entered,
    ht: taxes.htCents / 100,
    vat: taxes.vatCents / 100,
    tc: taxes.tcCents / 100,
    total: taxes.totalCents / 100,
    mode: form.room_price_tax_inclusive ? 'inclusive' as const : 'exclusive' as const,
  }
})

watch(() => form.currency_code, (code) => {
  const row = currencyOptions.value.find(c => c.code === code) ?? store.currencies.find(c => c.code === code)
  if (!row) return
  form.currency_symbol = row.symbol || row.code
})

onMounted(async () => {
  await Promise.all([store.loadCurrencies(true).catch(() => undefined), load()])
  if (!form.currency_code) {
    const def = currencyOptions.value.find(c => c.is_default) ?? currencyOptions.value[0]
    if (def) {
      form.currency_code = def.code
      form.currency_symbol = def.symbol || def.code
    }
  }
})

function emptySettings(): HotelSettings {
  return {
    check_in_time: '14:00',
    check_out_time: '12:00',
    early_arrival_limit: '08:00',
    early_arrival_fee: 0,
    late_departure_limit: '18:00',
    late_departure_fee: 0,
    deposit_amount: 0,
    free_cancel_hours: 24,
    cancel_penalty_percent: 100,
    charge_no_shows: true,
    no_show_penalty_percent: 100,
    vat_enabled: true,
    vat_rate: 10,
    tc_enabled: true,
    tc_rate: 5,
    room_price_tax_inclusive: false,
    occupancy_tax_enabled: false,
    service_fee_enabled: false,
    currency_code: getAppCurrency(),
    currency_symbol: '$',
    currency_symbol_position: 'before',
    allow_overbooking: false,
    hk_shift_start: '08:00',
    hk_shift_end: '17:00',
    auto_dirty_on_checkout: true,
    notify_arrival: true,
    notify_departure: true,
    notify_new_reservation: true,
    notify_unpaid_balance: true,
    saved_at: null,
  }
}

function moneyFromCents(cents: unknown) {
  return Number(((Number(cents) || 0) / 100).toFixed(2))
}

function formatMoneyPreview(amount: number, symbol: string, position: 'before' | 'after') {
  const value = Number(amount || 0).toLocaleString(locale.value === 'fr' ? 'fr-FR' : 'en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })
  return position === 'after' ? `${value}${symbol}` : `${symbol}${value}`
}

function formatClock(value: string) {
  const [hRaw, mRaw] = String(value || '').split(':')
  const h = Number(hRaw)
  const m = Number(mRaw)
  if (!Number.isFinite(h) || !Number.isFinite(m)) return value || '—'
  const date = new Date()
  date.setHours(h, m, 0, 0)
  return date.toLocaleTimeString(locale.value === 'fr' ? 'fr-FR' : 'en-US', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

function applyDoc(doc: Record<string, any> | undefined) {
  const base = emptySettings()
  if (!doc) {
    Object.assign(form, base)
    return
  }
  Object.assign(form, {
    check_in_time: doc.check_in_time || base.check_in_time,
    check_out_time: doc.check_out_time || base.check_out_time,
    early_arrival_limit: doc.early_arrival_limit || base.early_arrival_limit,
    early_arrival_fee: moneyFromCents(doc.early_arrival_fee_cents),
    late_departure_limit: doc.late_departure_limit || base.late_departure_limit,
    late_departure_fee: moneyFromCents(doc.late_departure_fee_cents),
    deposit_amount: moneyFromCents(doc.deposit_amount_cents),
    free_cancel_hours: Number(doc.free_cancel_hours ?? 24),
    cancel_penalty_percent: Number(doc.cancel_penalty_percent ?? 100),
    charge_no_shows: doc.charge_no_shows !== false,
    no_show_penalty_percent: Number(doc.no_show_penalty_percent ?? 100),
    vat_enabled: doc.vat_enabled !== false,
    vat_rate: Number(doc.vat_rate ?? 10),
    tc_enabled: doc.tc_enabled !== false,
    tc_rate: Number(doc.tc_rate ?? 5),
    room_price_tax_inclusive: Boolean(doc.room_price_tax_inclusive),
    occupancy_tax_enabled: Boolean(doc.occupancy_tax_enabled),
    service_fee_enabled: Boolean(doc.service_fee_enabled),
    currency_code: String(doc.currency_code || getAppCurrency()).toUpperCase(),
    currency_symbol: String(doc.currency_symbol || '$'),
    currency_symbol_position: doc.currency_symbol_position === 'after' ? 'after' : 'before',
    allow_overbooking: Boolean(doc.allow_overbooking),
    hk_shift_start: doc.hk_shift_start || base.hk_shift_start,
    hk_shift_end: doc.hk_shift_end || base.hk_shift_end,
    auto_dirty_on_checkout: doc.auto_dirty_on_checkout !== false,
    notify_arrival: doc.notify_arrival !== false,
    notify_departure: doc.notify_departure !== false,
    notify_new_reservation: doc.notify_new_reservation !== false,
    notify_unpaid_balance: doc.notify_unpaid_balance !== false,
    saved_at: doc.saved_at ?? null,
  })
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const docs = (await api.get<{ data: { docs: Record<string, any>[] } }>('/hospitality')).data.docs
    applyDoc(docs.find(doc => doc.kind === 'hotel_settings' || doc.id === 'hotel-settings'))
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  error.value = ''
  message.value = ''
  try {
    const docs = (await api.post<{ data: { docs: Record<string, any>[] } }>('/hospitality/actions', {
      action: 'upsert_hotel_settings',
      check_in_time: form.check_in_time,
      check_out_time: form.check_out_time,
      early_arrival_limit: form.early_arrival_limit,
      early_arrival_fee_cents: Math.round(Math.max(0, Number(form.early_arrival_fee) || 0) * 100),
      late_departure_limit: form.late_departure_limit,
      late_departure_fee_cents: Math.round(Math.max(0, Number(form.late_departure_fee) || 0) * 100),
      deposit_amount_cents: Math.round(Math.max(0, Number(form.deposit_amount) || 0) * 100),
      free_cancel_hours: Number(form.free_cancel_hours) || 0,
      cancel_penalty_percent: Number(form.cancel_penalty_percent) || 0,
      charge_no_shows: form.charge_no_shows,
      no_show_penalty_percent: Number(form.no_show_penalty_percent) || 0,
      vat_enabled: form.vat_enabled,
      vat_rate: Number(form.vat_rate) || 0,
      tc_enabled: form.tc_enabled,
      tc_rate: Number(form.tc_rate) || 0,
      room_price_tax_inclusive: form.room_price_tax_inclusive,
      occupancy_tax_enabled: form.occupancy_tax_enabled,
      service_fee_enabled: form.service_fee_enabled,
      currency_code: form.currency_code,
      currency_symbol: form.currency_symbol,
      currency_symbol_position: form.currency_symbol_position,
      allow_overbooking: form.allow_overbooking,
      hk_shift_start: form.hk_shift_start,
      hk_shift_end: form.hk_shift_end,
      auto_dirty_on_checkout: form.auto_dirty_on_checkout,
      notify_arrival: form.notify_arrival,
      notify_departure: form.notify_departure,
      notify_new_reservation: form.notify_new_reservation,
      notify_unpaid_balance: form.notify_unpaid_balance,
    })).data.docs
    applyDoc(docs.find(doc => doc.kind === 'hotel_settings' || doc.id === 'hotel-settings'))
    message.value = t('hotel.settings.saved')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <HotelChrome scroll-body>
    <div class="settings-page">
      <div class="settings-page__toolbar">
        <div>
          <h2 class="settings-page__title">{{ t('hotel.settings.title') }}</h2>
          <p class="settings-page__hint">{{ t('hotel.settings.hint') }}</p>
        </div>
        <button class="btn-primary" :disabled="saving || loading" @click="save">
          {{ saving ? t('common.loading') : t('common.save') }}
        </button>
      </div>

      <p v-if="error" class="settings-banner settings-banner--error">{{ error }}</p>
      <p v-if="message" class="settings-banner settings-banner--ok">{{ message }}</p>

      <div class="settings-layout">
        <div class="settings-main">
          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.arrival') }}</h3>
            <div class="settings-grid">
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.settings.checkIn') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.checkInHint') }}</p>
                <input v-model="form.check_in_time" type="time" class="field">
              </div>
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.settings.checkOut') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.checkOutHint') }}</p>
                <input v-model="form.check_out_time" type="time" class="field">
              </div>
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.settings.earlyLimit') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.earlyLimitHint') }}</p>
                <input v-model="form.early_arrival_limit" type="time" class="field">
              </div>
              <div>
                <FieldLabel icon="coins">{{ t('hotel.settings.earlyFee') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.earlyFeeHint') }}</p>
                <div class="money-field">
                  <span class="money-field__prefix">{{ form.currency_symbol || '$' }}</span>
                  <input v-model.number="form.early_arrival_fee" type="number" min="0" step="0.01" class="field">
                </div>
              </div>
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.settings.lateLimit') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.lateLimitHint') }}</p>
                <input v-model="form.late_departure_limit" type="time" class="field">
              </div>
              <div>
                <FieldLabel icon="coins">{{ t('hotel.settings.lateFee') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.lateFeeHint') }}</p>
                <div class="money-field">
                  <span class="money-field__prefix">{{ form.currency_symbol || '$' }}</span>
                  <input v-model.number="form.late_departure_fee" type="number" min="0" step="0.01" class="field">
                </div>
              </div>
            </div>
          </section>

          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.deposit') }}</h3>
            <p class="section-hint">{{ t('hotel.settings.depositHint') }}</p>
            <div class="settings-grid settings-grid--1">
              <div>
                <FieldLabel icon="lock">{{ t('hotel.settings.depositAmount') }}</FieldLabel>
                <div class="money-field">
                  <span class="money-field__prefix">{{ form.currency_symbol || '$' }}</span>
                  <input v-model.number="form.deposit_amount" type="number" min="0" step="0.01" class="field">
                </div>
              </div>
            </div>
          </section>

          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.cancel') }}</h3>
            <div class="settings-grid">
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.settings.freeCancel') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.freeCancelHint') }}</p>
                <div class="suffix-field">
                  <input v-model.number="form.free_cancel_hours" type="number" min="0" class="field">
                  <span class="suffix-field__mark">h</span>
                </div>
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('hotel.settings.cancelPenalty') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.cancelPenaltyHint') }}</p>
                <div class="suffix-field">
                  <input v-model.number="form.cancel_penalty_percent" type="number" min="0" max="100" class="field">
                  <span class="suffix-field__mark">%</span>
                </div>
              </div>
            </div>
            <label class="toggle-row">
              <span>
                <strong>{{ t('hotel.settings.chargeNoShows') }}</strong>
                <small>{{ t('hotel.settings.chargeNoShowsHint') }}</small>
              </span>
              <input v-model="form.charge_no_shows" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <div v-if="form.charge_no_shows" class="settings-grid settings-grid--1 mt-3">
              <div>
                <FieldLabel icon="percent">{{ t('hotel.settings.noShowPenalty') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.noShowPenaltyHint') }}</p>
                <div class="suffix-field">
                  <input v-model.number="form.no_show_penalty_percent" type="number" min="0" max="100" class="field">
                  <span class="suffix-field__mark">%</span>
                </div>
              </div>
            </div>
          </section>

          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.taxes') }}</h3>
            <label class="toggle-row">
              <span>
                <strong>{{ t('hotel.settings.vat') }}</strong>
                <small>{{ t('hotel.settings.vatHint') }}</small>
              </span>
              <input v-model="form.vat_enabled" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <div v-if="form.vat_enabled" class="settings-grid settings-grid--1 mt-3">
              <div>
                <FieldLabel icon="percent">{{ t('hotel.settings.vatRate') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.vatRateHint') }}</p>
                <div class="suffix-field">
                  <input v-model.number="form.vat_rate" type="number" min="0" max="100" step="0.01" class="field">
                  <span class="suffix-field__mark">%</span>
                </div>
              </div>
            </div>

            <label class="toggle-row mt-4">
              <span>
                <strong>{{ t('hotel.settings.tc') }}</strong>
                <small>{{ t('hotel.settings.tcHint') }}</small>
              </span>
              <input v-model="form.tc_enabled" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <div v-if="form.tc_enabled" class="settings-grid settings-grid--1 mt-3">
              <div>
                <FieldLabel icon="percent">{{ t('hotel.settings.tcRate') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.tcRateHint') }}</p>
                <div class="suffix-field">
                  <input v-model.number="form.tc_rate" type="number" min="0" max="100" step="0.01" class="field">
                  <span class="suffix-field__mark">%</span>
                </div>
              </div>
            </div>

            <label class="toggle-row mt-4">
              <span>
                <strong>{{ t('hotel.settings.taxInclusive') }}</strong>
                <small>{{ t('hotel.settings.taxInclusiveHint') }}</small>
              </span>
              <input v-model="form.room_price_tax_inclusive" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <label class="toggle-row mt-3">
              <span>
                <strong>{{ t('hotel.settings.occupancyTax') }}</strong>
                <small>{{ t('hotel.settings.occupancyTaxHint') }}</small>
              </span>
              <input v-model="form.occupancy_tax_enabled" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <label class="toggle-row mt-3">
              <span>
                <strong>{{ t('hotel.settings.serviceFee') }}</strong>
                <small>{{ t('hotel.settings.serviceFeeHint') }}</small>
              </span>
              <input v-model="form.service_fee_enabled" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
          </section>

          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.currency') }}</h3>
            <div class="settings-grid">
              <div class="settings-span">
                <FieldLabel icon="coins">{{ t('hotel.settings.catalogCurrency') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.catalogCurrencyHint') }}</p>
                <select v-model="form.currency_code" class="field">
                  <option v-for="currency in currencyOptions" :key="currency.id" :value="currency.code">
                    {{ currency.code }} — {{ currency.name }}
                  </option>
                </select>
              </div>
              <div>
                <FieldLabel icon="tag">{{ t('hotel.settings.isoCode') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.isoCodeHint') }}</p>
                <input :value="form.currency_code" class="field" readonly>
              </div>
              <div>
                <FieldLabel icon="coins">{{ t('hotel.settings.symbol') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.symbolHint') }}</p>
                <input v-model="form.currency_symbol" class="field" maxlength="8">
              </div>
              <div>
                <FieldLabel icon="adjust">{{ t('hotel.settings.symbolPosition') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.preview') }} · {{ moneyPreview }}</p>
                <select v-model="form.currency_symbol_position" class="field">
                  <option value="before">{{ t('hotel.settings.symbolBefore') }}</option>
                  <option value="after">{{ t('hotel.settings.symbolAfter') }}</option>
                </select>
              </div>
            </div>
            <label class="toggle-row mt-4">
              <span>
                <strong>{{ t('hotel.settings.overbooking') }}</strong>
                <small>{{ t('hotel.settings.overbookingHint') }}</small>
              </span>
              <input v-model="form.allow_overbooking" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
          </section>

          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.housekeeping') }}</h3>
            <div class="settings-grid">
              <div>
                <FieldLabel icon="broom">{{ t('hotel.settings.hkStart') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.hkStartHint') }}</p>
                <input v-model="form.hk_shift_start" type="time" class="field">
              </div>
              <div>
                <FieldLabel icon="broom">{{ t('hotel.settings.hkEnd') }}</FieldLabel>
                <p class="field-hint">{{ t('hotel.settings.hkEndHint') }}</p>
                <input v-model="form.hk_shift_end" type="time" class="field">
              </div>
            </div>
            <label class="toggle-row mt-4">
              <span>
                <strong>{{ t('hotel.settings.autoDirty') }}</strong>
                <small>{{ t('hotel.settings.autoDirtyHint') }}</small>
              </span>
              <input v-model="form.auto_dirty_on_checkout" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
          </section>

          <section class="settings-card">
            <h3>{{ t('hotel.settings.sections.notifications') }}</h3>
            <label class="toggle-row">
              <span>
                <strong>{{ t('hotel.settings.notifyArrival') }}</strong>
                <small>{{ t('hotel.settings.notifyArrivalHint') }}</small>
              </span>
              <input v-model="form.notify_arrival" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <label class="toggle-row mt-3">
              <span>
                <strong>{{ t('hotel.settings.notifyDeparture') }}</strong>
                <small>{{ t('hotel.settings.notifyDepartureHint') }}</small>
              </span>
              <input v-model="form.notify_departure" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <label class="toggle-row mt-3">
              <span>
                <strong>{{ t('hotel.settings.notifyReservation') }}</strong>
                <small>{{ t('hotel.settings.notifyReservationHint') }}</small>
              </span>
              <input v-model="form.notify_new_reservation" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
            <label class="toggle-row mt-3">
              <span>
                <strong>{{ t('hotel.settings.notifyUnpaid') }}</strong>
                <small>{{ t('hotel.settings.notifyUnpaidHint') }}</small>
              </span>
              <input v-model="form.notify_unpaid_balance" type="checkbox" class="toggle-row__input">
              <span class="toggle-row__track" aria-hidden="true" />
            </label>
          </section>
        </div>

        <aside class="settings-preview">
          <div class="settings-preview__card">
            <h3>{{ t('hotel.settings.previewTitle') }}</h3>
            <dl class="preview-list">
              <div><dt>{{ t('hotel.settings.checkIn') }}</dt><dd>{{ formatClock(form.check_in_time) }}</dd></div>
              <div><dt>{{ t('hotel.settings.checkOut') }}</dt><dd>{{ formatClock(form.check_out_time) }}</dd></div>
              <div>
                <dt>{{ t('hotel.settings.symbol') }}</dt>
                <dd>{{ form.currency_symbol }} ({{ form.currency_code }})</dd>
              </div>
              <div>
                <dt>{{ t('hotel.settings.freeCancel') }}</dt>
                <dd>{{ form.free_cancel_hours }}h {{ t('hotel.settings.beforeArrival') }}</dd>
              </div>
              <div><dt>{{ t('hotel.settings.vat') }}</dt><dd>{{ form.vat_enabled ? `${form.vat_rate}%` : t('hotel.settings.off') }}</dd></div>
              <div><dt>{{ t('hotel.settings.tc') }}</dt><dd>{{ form.tc_enabled ? `${form.tc_rate}%` : t('hotel.settings.off') }}</dd></div>
              <div>
                <dt>{{ t('hotel.settings.rateMode') }}</dt>
                <dd>{{ form.room_price_tax_inclusive ? t('hotel.settings.inclusive') : t('hotel.settings.exclusive') }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.settings.occupancyTax') }}</dt>
                <dd>{{ form.occupancy_tax_enabled ? t('hotel.settings.on') : t('hotel.settings.off') }}</dd>
              </div>
            </dl>

            <div class="preview-example">
              <h4>{{ t('hotel.settings.exampleTitle') }}</h4>
              <p>
                {{ t('hotel.settings.exampleLine', {
                  entered: formatMoneyPreview(exampleNight.entered, form.currency_symbol, form.currency_symbol_position),
                  mode: exampleNight.mode === 'inclusive' ? t('hotel.settings.inclusiveShort') : t('hotel.settings.exclusiveShort'),
                  ht: formatMoneyPreview(exampleNight.ht, form.currency_symbol, form.currency_symbol_position),
                  vat: formatMoneyPreview(exampleNight.vat, form.currency_symbol, form.currency_symbol_position),
                  tc: formatMoneyPreview(exampleNight.tc, form.currency_symbol, form.currency_symbol_position),
                  total: formatMoneyPreview(exampleNight.total, form.currency_symbol, form.currency_symbol_position),
                }) }}
              </p>
              <p class="preview-example__note">
                {{ exampleNight.mode === 'inclusive' ? t('hotel.settings.exampleInclusiveNote') : t('hotel.settings.exampleExclusiveNote') }}
                <template v-if="form.vat_enabled || form.tc_enabled">
                  ·
                  <template v-if="form.vat_enabled">{{ t('hotel.settings.vat') }} {{ form.vat_rate }}%</template>
                  <template v-if="form.vat_enabled && form.tc_enabled"> + </template>
                  <template v-if="form.tc_enabled">{{ t('hotel.settings.tc') }} {{ form.tc_rate }}%</template>
                </template>
              </p>
            </div>

            <p class="preview-saved">
              {{ t('hotel.settings.lastSaved') }}:
              {{ form.saved_at ? formatDateTime(form.saved_at) : t('hotel.settings.neverSaved') }}
            </p>
            <p v-if="selectedCurrency" class="preview-currency-meta">
              {{ selectedCurrency.code }} — {{ selectedCurrency.name }}
            </p>
          </div>
        </aside>
      </div>
    </div>
  </HotelChrome>
</template>

<style scoped>
.settings-page {
  display: grid;
  gap: 1rem;
}

.settings-page__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.85rem;
}

.settings-page__title {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 650;
  color: #1a2833;
}

.settings-page__hint,
.section-hint,
.field-hint {
  margin: 0.3rem 0 0;
  font-size: 0.84rem;
  color: #66727c;
  line-height: 1.4;
}

.field-hint {
  margin-bottom: 0.4rem;
}

.settings-banner {
  margin: 0;
  padding: 0.75rem 0.9rem;
  border-radius: 0.75rem;
  font-size: 0.875rem;
}

.settings-banner--error {
  background: #fef2f2;
  color: #b91c1c;
}

.settings-banner--ok {
  background: #ecfdf5;
  color: #047857;
}

.settings-layout {
  display: grid;
  gap: 1rem;
}

@media (min-width: 1100px) {
  .settings-layout {
    grid-template-columns: minmax(0, 1fr) 20rem;
    align-items: start;
  }

  .settings-preview {
    position: sticky;
    top: 0.75rem;
  }
}

.settings-main {
  display: grid;
  gap: 1rem;
}

.settings-card,
.settings-preview__card {
  padding: 1.2rem 1.3rem;
  border: 1px solid var(--color-border, #e4e8ec);
  border-radius: 0.9rem;
  background: #fff;
}

.settings-card h3,
.settings-preview__card h3 {
  margin: 0 0 1rem;
  font-size: 0.98rem;
  font-weight: 650;
  color: #1a2833;
}

.settings-grid {
  display: grid;
  gap: 0.95rem 1rem;
  grid-template-columns: 1fr;
}

@media (min-width: 760px) {
  .settings-grid {
    grid-template-columns: 1fr 1fr;
  }

  .settings-grid--1,
  .settings-span {
    grid-column: 1 / -1;
  }
}

.money-field,
.suffix-field {
  position: relative;
}

.money-field__prefix,
.suffix-field__mark {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  color: #64748b;
  font-weight: 650;
  pointer-events: none;
}

.money-field__prefix {
  left: 0.85rem;
}

.money-field .field {
  padding-left: 1.7rem;
}

.suffix-field__mark {
  right: 0.85rem;
}

.suffix-field .field {
  padding-right: 2rem;
}

.toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 0.95rem;
  border: 1px solid #e8edf1;
  border-radius: 0.8rem;
  background: #f8fafb;
  cursor: pointer;
}

.toggle-row span:first-child {
  display: grid;
  gap: 0.2rem;
}

.toggle-row strong {
  font-size: 0.9rem;
  color: #1e293b;
}

.toggle-row small {
  font-size: 0.8rem;
  color: #66727c;
  line-height: 1.35;
}

.toggle-row__input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.toggle-row__track {
  width: 2.45rem;
  height: 1.35rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: #cbd5e1;
  position: relative;
  transition: background 0.16s ease;
}

.toggle-row__track::after {
  content: '';
  position: absolute;
  top: 0.15rem;
  left: 0.16rem;
  width: 1.05rem;
  height: 1.05rem;
  border-radius: 999px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.2);
  transition: transform 0.16s ease;
}

.toggle-row__input:checked + .toggle-row__track {
  background: #0f766e;
}

.toggle-row__input:checked + .toggle-row__track::after {
  transform: translateX(1.05rem);
}

.mt-3 { margin-top: 0.75rem; }
.mt-4 { margin-top: 1rem; }

.preview-list {
  margin: 0;
  display: grid;
  gap: 0.65rem;
}

.preview-list > div {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.84rem;
}

.preview-list dt {
  margin: 0;
  color: #66727c;
}

.preview-list dd {
  margin: 0;
  font-weight: 650;
  color: #1a2833;
  text-align: right;
}

.preview-example {
  margin-top: 1rem;
  padding: 0.9rem;
  border-radius: 0.75rem;
  background: #f4f7f9;
}

.preview-example h4 {
  margin: 0 0 0.45rem;
  font-size: 0.84rem;
  color: #1a2833;
}

.preview-example p {
  margin: 0;
  font-size: 0.82rem;
  color: #334155;
  line-height: 1.45;
}

.preview-example__note {
  margin-top: 0.45rem !important;
  color: #66727c !important;
}

.preview-saved,
.preview-currency-meta {
  margin: 0.85rem 0 0;
  font-size: 0.78rem;
  color: #80909c;
}
</style>
