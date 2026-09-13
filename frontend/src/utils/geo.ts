import { intlLocale } from '../i18n/locales'

/** ISO 3166-1 alpha-2 codes. Names come from Intl.DisplayNames. */
const COUNTRY_CODES = [
  'AD', 'AE', 'AF', 'AG', 'AI', 'AL', 'AM', 'AO', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AW', 'AX', 'AZ',
  'BA', 'BB', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI', 'BJ', 'BL', 'BM', 'BN', 'BO', 'BQ', 'BR', 'BS', 'BT', 'BV', 'BW', 'BY', 'BZ',
  'CA', 'CC', 'CD', 'CF', 'CG', 'CH', 'CI', 'CK', 'CL', 'CM', 'CN', 'CO', 'CR', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ',
  'DE', 'DJ', 'DK', 'DM', 'DO', 'DZ',
  'EC', 'EE', 'EG', 'EH', 'ER', 'ES', 'ET',
  'FI', 'FJ', 'FK', 'FM', 'FO', 'FR',
  'GA', 'GB', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GL', 'GM', 'GN', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GU', 'GW', 'GY',
  'HK', 'HM', 'HN', 'HR', 'HT', 'HU',
  'ID', 'IE', 'IL', 'IM', 'IN', 'IO', 'IQ', 'IR', 'IS', 'IT',
  'JE', 'JM', 'JO', 'JP',
  'KE', 'KG', 'KH', 'KI', 'KM', 'KN', 'KP', 'KR', 'KW', 'KY', 'KZ',
  'LA', 'LB', 'LC', 'LI', 'LK', 'LR', 'LS', 'LT', 'LU', 'LV', 'LY',
  'MA', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MK', 'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MU', 'MV', 'MW', 'MX', 'MY', 'MZ',
  'NA', 'NC', 'NE', 'NF', 'NG', 'NI', 'NL', 'NO', 'NP', 'NR', 'NU', 'NZ',
  'OM',
  'PA', 'PE', 'PF', 'PG', 'PH', 'PK', 'PL', 'PM', 'PN', 'PR', 'PS', 'PT', 'PW', 'PY',
  'QA',
  'RE', 'RO', 'RS', 'RU', 'RW',
  'SA', 'SB', 'SC', 'SD', 'SE', 'SG', 'SH', 'SI', 'SJ', 'SK', 'SL', 'SM', 'SN', 'SO', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ',
  'TC', 'TD', 'TF', 'TG', 'TH', 'TJ', 'TK', 'TL', 'TM', 'TN', 'TO', 'TR', 'TT', 'TV', 'TW', 'TZ',
  'UA', 'UG', 'UM', 'US', 'UY', 'UZ',
  'VA', 'VC', 'VE', 'VG', 'VI', 'VN', 'VU',
  'WF', 'WS',
  'YE', 'YT',
  'ZA', 'ZM', 'ZW',
] as const

const COUNTRY_SET = new Set<string>(COUNTRY_CODES)

const NAME_LOCALES = ['en', 'fr', 'sw', 'en-GB', 'fr-FR', 'sw-KE']

/** Names stored in existing records that DisplayNames may not reverse-map. */
const COUNTRY_ALIASES: Record<string, string> = {
  burundi: 'BI',
  rwanda: 'RW',
  kenya: 'KE',
  tanzania: 'TZ',
  uganda: 'UG',
  'rdc': 'CD',
  'drc': 'CD',
  'dr congo': 'CD',
  'rd congo': 'CD',
  'congo kinshasa': 'CD',
  'republique democratique du congo': 'CD',
  'democratic republic of the congo': 'CD',
  'congo brazzaville': 'CG',
  'republic of the congo': 'CG',
}

const PREFERRED_TIMEZONES = [
  'Africa/Bujumbura',
  'Africa/Kigali',
  'Africa/Nairobi',
  'Africa/Dar_es_Salaam',
  'Africa/Kampala',
  'Africa/Lubumbashi',
  'Africa/Johannesburg',
  'Europe/Paris',
  'Europe/Brussels',
  'UTC',
]

export type CountryOption = { code: string; name: string }
export type TimezoneOption = { id: string; label: string }

function normalizeName(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
}

let nameIndex: Map<string, string> | null = null

function countryNameIndex(): Map<string, string> {
  if (nameIndex) return nameIndex

  const index = new Map<string, string>()
  for (const locale of NAME_LOCALES) {
    let names: Intl.DisplayNames
    try {
      names = new Intl.DisplayNames([locale], { type: 'region' })
    } catch {
      continue
    }
    for (const code of COUNTRY_CODES) {
      const label = names.of(code)
      if (!label || label.toUpperCase() === code) continue
      const key = normalizeName(label)
      if (key && !index.has(key)) index.set(key, code)
    }
  }
  for (const [alias, code] of Object.entries(COUNTRY_ALIASES)) {
    index.set(normalizeName(alias), code)
  }
  nameIndex = index
  return index
}

function regionName(code: string, locale: string): string {
  try {
    return new Intl.DisplayNames([intlLocale(locale), 'en'], { type: 'region' }).of(code) ?? code
  } catch {
    return code
  }
}

/** Normalize a stored country code or localized name to ISO 3166-1 alpha-2. */
export function countryCode(value?: string | null): string {
  const raw = (value ?? '').trim()
  if (!raw) return ''
  const upper = raw.toUpperCase()
  if (upper.length === 2 && COUNTRY_SET.has(upper)) return upper
  return countryNameIndex().get(normalizeName(raw)) ?? ''
}

export function countryOptions(locale: string): CountryOption[] {
  const options = COUNTRY_CODES.map((code) => ({
    code,
    name: regionName(code, locale),
  }))
  options.sort((a, b) => a.name.localeCompare(b.name, intlLocale(locale)))
  const burundi = options.findIndex((option) => option.code === 'BI')
  if (burundi > 0) {
    const [pinned] = options.splice(burundi, 1)
    options.unshift(pinned)
  }
  return options
}

function timezoneIds(): string[] {
  try {
    return Intl.supportedValuesOf('timeZone')
  } catch {
    return [...PREFERRED_TIMEZONES]
  }
}

function zoneOffset(timeZone: string): string {
  try {
    const part = new Intl.DateTimeFormat('en-GB', {
      timeZone,
      timeZoneName: 'shortOffset',
      hour: '2-digit',
    }).formatToParts(new Date()).find((item) => item.type === 'timeZoneName')?.value
    return part && part !== timeZone ? part : ''
  } catch {
    return ''
  }
}

export function timezones(): TimezoneOption[] {
  const seen = new Set<string>()
  const ordered = [...PREFERRED_TIMEZONES, ...timezoneIds()].filter((id) => {
    if (seen.has(id)) return false
    seen.add(id)
    return true
  })

  return ordered.map((id) => {
    const offset = zoneOffset(id)
    const place = id.replaceAll('_', ' ')
    return { id, label: offset ? `${place} (${offset})` : place }
  })
}
