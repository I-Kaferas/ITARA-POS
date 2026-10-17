import { getLocale } from './i18n'

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
export const ADMIN_LOGIN_URL = import.meta.env.VITE_ADMIN_URL ?? 'http://localhost:4173/login'
export const ADMIN_REGISTER_URL =
  import.meta.env.VITE_ADMIN_REGISTER_URL?.trim()
  || `${ADMIN_LOGIN_URL.replace(/\/login\/?$/, '')}/login?intent=register`

/** Public product name on the marketing site (vitrine). */
export const PRODUCT_NAME = 'ITARA BUSINESS CORE'
/** Default product mark (served from `website/public/brand`). */
export const PRODUCT_LOGO_URL = '/brand/itara-nexus-logo.png'
export const BRAND_PRIMARY = '#12243C'
export const BRAND_ACCENT = '#E39B2B'

function normalizePublicBranding(data: TenantBranding): TenantBranding {
  const heroTitle = data.marketing.hero_title?.trim()
  const replaceHero =
    !heroTitle
    || heroTitle.toLowerCase() === data.brand_name.trim().toLowerCase()
    || /ma boutique/i.test(heroTitle)

  return {
    ...data,
    brand_name: PRODUCT_NAME,
    tagline:
      data.tagline?.trim()
      && !/ma boutique/i.test(data.tagline)
        ? data.tagline
        : 'Caisse, stock et back-office unifiés — ITARA BUSINESS CORE',
    primary_color: BRAND_PRIMARY,
    accent_color: BRAND_ACCENT,
    marketing: {
      ...data.marketing,
      hero_title: replaceHero ? PRODUCT_NAME : heroTitle,
      hero_subtitle:
        data.marketing.hero_subtitle?.trim()
        || 'Vendez en caisse, suivez le stock et pilotez votre activité en temps réel.',
    },
  }
}

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
    return normalizePublicBranding(body.data as TenantBranding)
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') {
      throw new Error('Délai dépassé — vérifiez que l’API tourne sur :8001')
    }
    throw e
  } finally {
    window.clearTimeout(timer)
  }
}

export function applyBranding(branding: TenantBranding) {
  const root = document.documentElement
  root.style.setProperty('--brand-primary', branding.primary_color || BRAND_PRIMARY)
  root.style.setProperty('--brand-primary-700', '#0f1f34')
  root.style.setProperty('--brand-primary-800', '#0d1a2b')
  root.style.setProperty('--brand-primary-900', '#0a1523')
  root.style.setProperty('--brand-accent', branding.accent_color || BRAND_ACCENT)
  document.title = `${PRODUCT_NAME}`
}

function withLang(url: URL) {
  url.searchParams.set('lang', getLocale())
  return url.toString()
}

export function resolveAdminLoginUrl(slug: string): string {
  const url = new URL(ADMIN_LOGIN_URL, window.location.origin)
  url.searchParams.set('tenant', slug)
  return withLang(url)
}

export function resolveAdminRegisterUrl(slug: string): string {
  try {
    const url = new URL(ADMIN_REGISTER_URL, window.location.origin)
    url.searchParams.set('tenant', slug)
    if (!url.searchParams.has('intent')) url.searchParams.set('intent', 'register')
    return withLang(url)
  } catch {
    return resolveAdminLoginUrl(slug)
  }
}

export function resolveCtaUrl(branding: TenantBranding): string {
  const custom = branding.marketing.cta_url?.trim()
  if (custom && /^https?:\/\//i.test(custom)) {
    try {
      const url = new URL(custom)
      url.searchParams.set('tenant', branding.slug)
      return withLang(url)
    } catch {
      // fall through
    }
  }
  return resolveAdminLoginUrl(branding.slug)
}
