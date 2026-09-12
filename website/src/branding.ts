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

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api/v1'
export const DEFAULT_SLUG = import.meta.env.VITE_DEFAULT_TENANT_SLUG ?? 'demo'
export const ADMIN_LOGIN_URL = import.meta.env.VITE_ADMIN_URL ?? 'http://localhost:5173/login'

export async function fetchPublicBranding(slug: string): Promise<TenantBranding> {
  const controller = new AbortController()
  const timer = window.setTimeout(() => controller.abort(), 8000)
  try {
    const response = await fetch(
      `${API_BASE}/public/tenants/${encodeURIComponent(slug)}/branding`,
      { headers: { Accept: 'application/json' }, signal: controller.signal },
    )
    if (!response.ok) {
      throw new Error(response.status === 404 ? 'Tenant introuvable' : 'Impossible de charger la marque')
    }
    const body = await response.json()
    return body.data as TenantBranding
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') {
      throw new Error('Délai dépassé — vérifiez que l’API tourne sur :8000')
    }
    throw e
  } finally {
    window.clearTimeout(timer)
  }
}

export function applyBranding(branding: TenantBranding) {
  const root = document.documentElement
  root.style.setProperty('--brand-primary', branding.primary_color)
  root.style.setProperty('--brand-accent', branding.accent_color)
  document.title = `${branding.brand_name} · Point de vente`
}

export function resolveAdminLoginUrl(slug: string): string {
  const url = new URL(ADMIN_LOGIN_URL, window.location.origin)
  url.searchParams.set('tenant', slug)
  return url.toString()
}

export function resolveCtaUrl(branding: TenantBranding): string {
  const custom = branding.marketing.cta_url?.trim()
  if (custom && /^https?:\/\//i.test(custom)) {
    try {
      const url = new URL(custom)
      url.searchParams.set('tenant', branding.slug)
      return url.toString()
    } catch {
      // fall through
    }
  }
  return resolveAdminLoginUrl(branding.slug)
}
