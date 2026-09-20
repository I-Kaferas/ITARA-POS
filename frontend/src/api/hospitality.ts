/** Build a scoped hospitality snapshot URL. */
export function hospitalitySnapshotPath(kinds: string[]): string {
  const unique = [...new Set(kinds.filter(Boolean))]
  if (unique.length === 0) return '/hospitality'
  return `/hospitality?kinds=${encodeURIComponent(unique.join(','))}`
}

export const HOTEL_STAY_KINDS = [
  'folio',
  'reservation',
  'room',
  'room_type',
  'hotel_settings',
  'amenity',
  'building',
  'wing',
  'floor',
] as const

export const HOTEL_RESERVATION_KINDS = [
  'reservation',
  'room',
  'room_type',
  'hotel_settings',
  'building',
  'wing',
  'floor',
] as const

export const HOTEL_ROOM_KINDS = [
  'room',
  'room_type',
  'amenity',
  'building',
  'wing',
  'floor',
  'hotel_settings',
] as const

export const HOTEL_CALENDAR_KINDS = [
  'reservation',
  'folio',
  'room',
  'room_type',
] as const

export const HOTEL_HOUSEKEEPING_KINDS = [
  'housekeeping_task',
  'room',
  'room_type',
  'floor',
  'wing',
  'building',
] as const

export const HOTEL_CONCIERGE_KINDS = [
  'concierge_request',
  'folio',
  'reservation',
  'room',
] as const
