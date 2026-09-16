export type HotelSettingsDoc = {
  kind?: string
  id?: string
  check_in_time?: string
  check_out_time?: string
  early_arrival_limit?: string
  early_arrival_fee_cents?: number
  late_departure_limit?: string
  late_departure_fee_cents?: number
  deposit_amount_cents?: number
  free_cancel_hours?: number
  cancel_penalty_percent?: number
  charge_no_shows?: boolean
  no_show_penalty_percent?: number
  vat_enabled?: boolean
  vat_rate?: number
  tc_enabled?: boolean
  tc_rate?: number
  room_price_tax_inclusive?: boolean
  occupancy_tax_enabled?: boolean
  service_fee_enabled?: boolean
  currency_code?: string
  currency_symbol?: string
  currency_symbol_position?: 'before' | 'after'
  allow_overbooking?: boolean
  hk_shift_start?: string
  hk_shift_end?: string
  auto_dirty_on_checkout?: boolean
  notify_arrival?: boolean
  notify_departure?: boolean
  notify_new_reservation?: boolean
  notify_unpaid_balance?: boolean
}

export type StayTaxBreakdown = {
  htCents: number
  vatCents: number
  tcCents: number
  totalCents: number
}

export function defaultHotelSettings(): Required<Pick<HotelSettingsDoc,
  | 'check_in_time'
  | 'check_out_time'
  | 'deposit_amount_cents'
  | 'vat_enabled'
  | 'vat_rate'
  | 'tc_enabled'
  | 'tc_rate'
  | 'room_price_tax_inclusive'
  | 'currency_code'
  | 'currency_symbol'
  | 'currency_symbol_position'
  | 'allow_overbooking'
  | 'auto_dirty_on_checkout'
  | 'free_cancel_hours'
  | 'cancel_penalty_percent'
>> {
  return {
    check_in_time: '14:00',
    check_out_time: '12:00',
    deposit_amount_cents: 0,
    vat_enabled: true,
    vat_rate: 10,
    tc_enabled: true,
    tc_rate: 5,
    room_price_tax_inclusive: false,
    currency_code: 'USD',
    currency_symbol: '$',
    currency_symbol_position: 'before',
    allow_overbooking: false,
    auto_dirty_on_checkout: true,
    free_cancel_hours: 24,
    cancel_penalty_percent: 100,
  }
}

export function findHotelSettings(docs: HotelSettingsDoc[] | undefined | null): HotelSettingsDoc {
  const defaults = defaultHotelSettings()
  const doc = (docs ?? []).find(item => item.kind === 'hotel_settings' || item.id === 'hotel-settings')
  return { ...defaults, ...(doc ?? {}) }
}

export function computeStayTaxes(enteredCents: number, settings: HotelSettingsDoc): StayTaxBreakdown {
  const entered = Math.max(0, Math.round(Number(enteredCents) || 0))
  const vatRate = settings.vat_enabled === false ? 0 : Number(settings.vat_rate ?? 0)
  const tcRate = settings.tc_enabled === false ? 0 : Number(settings.tc_rate ?? 0)

  if (settings.room_price_tax_inclusive) {
    const divisor = 1 + (vatRate + tcRate) / 100
    const ht = divisor > 0 ? Math.round(entered / divisor) : entered
    const vatCents = Math.round(ht * (vatRate / 100))
    const tcCents = Math.round(ht * (tcRate / 100))
    return { htCents: ht, vatCents, tcCents, totalCents: entered }
  }

  const vatCents = Math.round(entered * (vatRate / 100))
  const tcCents = Math.round(entered * (tcRate / 100))
  return {
    htCents: entered,
    vatCents,
    tcCents,
    totalCents: entered + vatCents + tcCents,
  }
}

export function moneyFromSettingsCents(cents: number | undefined | null) {
  return Number((((Number(cents) || 0) / 100)).toFixed(2))
}
