import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api, extractApiErrorMessage } from '../api/client'

export type TenantBranding = {
  tenant_id: string
  slug: string
  status: string
  brand_name: string
  tagline: string
  logo_url: string | null
  primary_color: string
  accent_color: string
  support_email: string | null
  support_phone: string | null
  marketing: {
    hero_title: string
    hero_subtitle: string
    cta_label: string
    cta_url: string
  }
  company?: {
    name: string
    trade_name: string | null
    phone: string | null
    email: string | null
    website: string | null
    logo_url: string | null
    currency_code: string | null
    activity_sector: string | null
    legal_form: string | null
    tax_id: string | null
    registration_number: string | null
    fiscal_center: string | null
    opening_hours: string | null
    address: string | null
  } | null
}

const CACHE_KEY = 'pos_tenant_branding_v3'
const CACHE_TTL_MS = 1000 * 60 * 30

function parseHex(hex: string): [number, number, number] | null {
  const match = /^#?([0-9a-f]{6})$/i.exec(hex.trim())
  if (!match) return null
  const value = Number.parseInt(match[1], 16)
  return [(value >> 16) & 255, (value >> 8) & 255, value & 255]
}

function mixToward(hex: string, toward: [number, number, number], amount: number): string {
  const rgb = parseHex(hex)
  if (!rgb) return hex
  const mixed = rgb.map((channel, index) => {
    const next = channel + (toward[index] - channel) * amount
    return Math.max(0, Math.min(255, Math.round(next)))
  })
  return `#${mixed.map(channel => channel.toString(16).padStart(2, '0')).join('')}`
}

function applyCss(branding: TenantBranding) {
  const root = document.documentElement
  const primary = branding.primary_color
  const white: [number, number, number] = [255, 255, 255]
  const black: [number, number, number] = [0, 0, 0]
  const scale: Record<string, string> = {
    '50': mixToward(primary, white, 0.94),
    '100': mixToward(primary, white, 0.88),
    '200': mixToward(primary, white, 0.72),
    '300': mixToward(primary, white, 0.48),
    '400': mixToward(primary, white, 0.22),
    '500': mixToward(primary, white, 0.08),
    '600': primary,
    '700': mixToward(primary, black, 0.14),
    '800': mixToward(primary, black, 0.28),
    '900': mixToward(primary, black, 0.42),
  }
  for (const [step, color] of Object.entries(scale)) {
    root.style.setProperty(`--color-brand-${step}`, color)
  }
  root.style.setProperty('--color-accent', branding.accent_color)
  root.style.setProperty('--color-accent-soft', mixToward(branding.accent_color, white, 0.88))
  const rgb = parseHex(primary)
  if (rgb) {
    root.style.setProperty('--color-focus-ring', `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, 0.22)`)
    root.style.setProperty('--shadow-glow', `0 0 0 3px rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, 0.22)`)
  }
}

function readCache(): TenantBranding | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { at: number; data: TenantBranding }
    if (Date.now() - parsed.at > CACHE_TTL_MS) return null
    return parsed.data
  } catch {
    return null
  }
}

function writeCache(data: TenantBranding) {
  localStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), data }))
}

export const useBrandingStore = defineStore('branding', () => {
  const branding = ref<TenantBranding | null>(readCache())
  const loading = ref(false)
  const error = ref<string | null>(null)

  if (branding.value) applyCss(branding.value)

  async function loadPublic(slug: string) {
    loading.value = true
    error.value = null
    try {
      const response = await fetch(
        `${import.meta.env.VITE_API_BASE_URL ?? '/api/v1'}/public/tenants/${encodeURIComponent(slug)}/branding`,
        { headers: { Accept: 'application/json' } },
      )
      if (!response.ok) throw new Error(response.status === 404 ? 'Tenant introuvable' : 'Erreur branding')
      const body = await response.json()
      branding.value = body.data as TenantBranding
      if (branding.value.tenant_id && !localStorage.getItem('pos_token')) {
        localStorage.setItem('pos_tenant_id', branding.value.tenant_id)
      }
      applyCss(branding.value)
      writeCache(branding.value)
      return branding.value
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Erreur'
      throw e
    } finally {
      loading.value = false
    }
  }

  async function loadCurrent() {
    if (branding.value) {
      applyCss(branding.value)
      return branding.value
    }
    loading.value = true
    error.value = null
    try {
      const response = await api.get<{ data: TenantBranding }>('/tenant/branding')
      branding.value = response.data
      applyCss(branding.value)
      writeCache(branding.value)
      return branding.value
    } catch (e) {
      error.value = extractApiErrorMessage(e)
      throw e
    } finally {
      loading.value = false
    }
  }

  async function save(payload: Record<string, unknown>) {
    loading.value = true
    error.value = null
    try {
      const response = await api.put<{ data: TenantBranding }>('/tenant/branding', payload)
      branding.value = response.data
      applyCss(branding.value)
      writeCache(branding.value)
      return branding.value
    } catch (e) {
      error.value = extractApiErrorMessage(e)
      throw e
    } finally {
      loading.value = false
    }
  }

  function clear() {
    branding.value = null
    localStorage.removeItem(CACHE_KEY)
  }

  return { branding, loading, error, loadPublic, loadCurrent, save, clear }
})
