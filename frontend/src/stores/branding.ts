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
}

const CACHE_KEY = 'pos_tenant_branding'
const CACHE_TTL_MS = 1000 * 60 * 30

function applyCss(branding: TenantBranding) {
  const root = document.documentElement
  root.style.setProperty('--color-brand-500', branding.primary_color)
  root.style.setProperty('--color-brand-600', branding.primary_color)
  root.style.setProperty('--color-brand-700', branding.primary_color)
  root.style.setProperty('--color-accent', branding.accent_color)
  root.style.setProperty('--color-violet-500', branding.accent_color)
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
      if (branding.value.tenant_id) {
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
