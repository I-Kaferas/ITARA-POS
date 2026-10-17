<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import WorkspaceSplash from '../../components/auth/WorkspaceSplash.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import LanguageSwitcher from '../../components/ui/LanguageSwitcher.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { setAppLocale } from '../../i18n'
import { isAppLocale, type AppLocale } from '../../i18n/locales'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'
import type { Company } from '../../types'

const DEMO_EMAIL = 'admin@pos.local'
const DEMO_PASSWORD = 'password'
const DEFAULT_SLUG = 'demo'
const ITARA_LOGO_URL = '/brand/itara-nexus-logo.png?v=3'
const PRODUCT_NAME = 'ITARA NEXUS'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const brandingStore = useBrandingStore()
const context = useContextStore()
const backoffice = useBackofficeStore()

const email = ref('')
const password = ref('')
const twoFactorCode = ref('')
const showTwoFactor = ref(false)
const showPassword = ref(false)
const logoFailed = ref(false)
const showSplash = ref(false)
const company = ref<Company | null>(null)

const branding = computed(() => brandingStore.branding)
const loginLogoUrl = computed(() => ITARA_LOGO_URL)
const initial = computed(() => 'I')
const splashBrand = computed(() => {
  const companyName = splashCompany.value
  if (companyName) return companyName
  const custom = branding.value?.brand_name?.trim() || ''
  const generic = ['itara nexus', 'itara nexus business core']
  if (custom && !generic.includes(custom.toLowerCase())) return custom
  return PRODUCT_NAME
})
const splashTagline = computed(() => {
  const tagline = branding.value?.tagline?.trim() || ''
  const generic = [
    'itara nexus',
    'itara nexus business core',
    splashBrand.value.toLowerCase(),
    'point de vente professionnel',
    'vendez plus vite',
    'suivez vos stocks',
  ]
  const normalized = tagline.toLowerCase()
  if (tagline && !generic.some(part => normalized.includes(part))) return tagline
  return t('auth.brandTitle')
})
const splashCompany = computed(() => {
  return company.value?.name?.trim()
    || company.value?.trade_name?.trim()
    || context.currentStore?.branch?.company?.name?.trim()
    || context.currentStore?.branch?.company?.trade_name?.trim()
    || branding.value?.company?.name?.trim()
    || branding.value?.company?.trade_name?.trim()
    || ''
})
const tenantLogo = computed(() => branding.value?.logo_url?.trim() || '')

async function resolveCompany(): Promise<Company | null> {
  const fromStore = context.currentStore?.branch?.company
    ?? context.stores.find(store => store.branch?.company)?.branch?.company
    ?? null

  try {
    await backoffice.loadCompanies()
    const list = backoffice.companies
    const matched = fromStore
      ? list.find(item => item.id === fromStore.id)
      : null
    const withLogo = list.find(item => item.logo_url?.trim())
    return matched ?? withLogo ?? list[0] ?? fromStore ?? null
  } catch {
    return fromStore
  }
}

function resolveTenantSlug(): string {
  const fromQuery = typeof route.query.tenant === 'string' ? route.query.tenant.trim() : ''
  if (fromQuery) return fromQuery.toLowerCase()

  const host = window.location.hostname
  const isIp = /^\d{1,3}(\.\d{1,3}){3}$/.test(host)
  if (host === 'localhost' || isIp) return DEFAULT_SLUG

  const parts = host.split('.')
  if (parts.length >= 3 && parts[0] && parts[0] !== 'www') {
    return parts[0].toLowerCase()
  }

  return DEFAULT_SLUG
}

onMounted(() => {
  const raw = String(route.query.lang || '').toLowerCase().slice(0, 2)
  if (isAppLocale(raw)) void setAppLocale(raw as AppLocale)
  void brandingStore.loadPublic(resolveTenantSlug()).catch(() => undefined)
})

function fillDemo() {
  email.value = DEMO_EMAIL
  password.value = DEMO_PASSWORD
}

function useAnotherAccount() {
  showTwoFactor.value = false
  twoFactorCode.value = ''
  auth.error = null
}

function prepareWelcome() {
  if (showSplash.value) return
  company.value = null
  showSplash.value = true
}

async function bootWorkspace(report: { milestone: (ratio: number, step?: number) => void }) {
  if (auth.user?.is_super_admin && !auth.user.tenant_id) {
    report.milestone(1, 2)
    return
  }
  report.milestone(0.18, 0)
  await context.loadStores()
  report.milestone(0.62, 1)
  await Promise.all([
    brandingStore.loadCurrent().catch(() => undefined),
    resolveCompany()
      .then((value) => {
        company.value = value
      })
      .catch(() => {
        company.value = null
      }),
  ])
  report.milestone(1, 2)
}

async function onSplashDone() {
  if (auth.user?.is_super_admin && !auth.user.tenant_id) {
    await router.push({ name: 'platform' })
    return
  }
  await router.push({ name: 'dashboard' })
}

async function submit() {
  try {
    if (showTwoFactor.value) {
      await auth.verifyTwoFactor(twoFactorCode.value)
      await prepareWelcome()
      return
    }

    const result = await auth.login(email.value, password.value)
    if (result.requiresTwoFactor) {
      showTwoFactor.value = true
      return
    }

    await prepareWelcome()
  } catch {
    // error shown via store
  }
}
</script>

<template>
  <div
    class="login"
    :inert="showSplash"
    :style="{
      '--login-primary': branding?.primary_color || '#12243c',
      '--login-accent': branding?.accent_color || '#E39B2B',
    }"
  >
    <aside class="login__brand">
      <img
        class="login__scene"
        src="/brand/login-background.png"
        alt=""
        aria-hidden="true"
      />
      <div class="login__brand-veil" aria-hidden="true" />
      <img
        class="login__watermark"
        :src="loginLogoUrl"
        alt=""
        aria-hidden="true"
      />
      <div class="login__brand-inner">
        <div class="login__brand-mid">
          <img
            class="login__brand-mark"
            :src="loginLogoUrl"
            :alt="PRODUCT_NAME"
          />
          <span class="login__eyebrow">Business CORE</span>
          <h1 class="login__visually-hidden">{{ PRODUCT_NAME }}</h1>
          <p class="login__trade">{{ t('auth.brandTitle') }}</p>
          <p>{{ t('auth.brandSubtitle') }}</p>
        </div>

        <div class="login__brand-bottom">
          <ul class="login__points">
            <li>
              <span class="login__point-icon" aria-hidden="true"><AppIcon name="device-pos" :size="15" /></span>
              <span class="login__point-title">{{ t('auth.featureCatalog') }}</span>
            </li>
            <li>
              <span class="login__point-icon" aria-hidden="true"><AppIcon name="bed" :size="15" /></span>
              <span class="login__point-title">{{ t('auth.featureStores') }}</span>
            </li>
            <li>
              <span class="login__point-icon" aria-hidden="true"><AppIcon name="inventory" :size="15" /></span>
              <span class="login__point-title">{{ t('auth.featureSaas') }}</span>
            </li>
          </ul>
          <p class="login__foot">© {{ new Date().getFullYear() }} {{ PRODUCT_NAME }}</p>
        </div>
      </div>
    </aside>

    <main class="login__panel">
      <div class="login__panel-frame" aria-hidden="true" />

      <form class="login__form" @submit.prevent="submit">
        <div class="login__form-top">
          <div class="login__form-brand">
            <img
              v-if="loginLogoUrl && !logoFailed"
              class="login__logo"
              :src="loginLogoUrl"
              alt="ITARA NEXUS Business CORE"
              @error="logoFailed = true"
            />
            <span v-else class="login__mark">{{ initial }}</span>
          </div>
          <div class="login__tools">
            <LanguageSwitcher />
          </div>
        </div>

        <div class="login__form-head">
          <p class="login__form-kicker">{{ PRODUCT_NAME }}</p>
          <h2>{{ showTwoFactor ? t('auth.twoFactorTitle') : t('auth.login') }}</h2>
          <p class="login__lead">
            {{ showTwoFactor ? t('auth.twoFactorSubtitle') : t('auth.loginSubtitle') }}
          </p>
        </div>

        <div class="login__form-body">
          <div v-if="showTwoFactor" class="ui-field">
            <FieldLabel icon="lock" for="otp">{{ t('auth.twoFactorCode') }}</FieldLabel>
            <input
              id="otp"
              v-model="twoFactorCode"
              class="ui-input login__otp"
              type="text"
              inputmode="numeric"
              autocomplete="one-time-code"
              maxlength="6"
              required
            />
          </div>

          <template v-else>
            <div class="ui-field">
              <FieldLabel icon="mail" for="email">{{ t('auth.email') }}</FieldLabel>
              <input
                id="email"
                v-model="email"
                class="ui-input"
                type="email"
                autocomplete="email"
                required
              />
            </div>

            <div class="ui-field">
              <div class="login__label-row">
                <FieldLabel icon="lock" for="password">{{ t('auth.password') }}</FieldLabel>
                <RouterLink to="/forgot-password">{{ t('auth.forgotPassword') }}</RouterLink>
              </div>
              <div class="login__secret">
                <input
                  id="password"
                  v-model="password"
                  class="ui-input"
                  :type="showPassword ? 'text' : 'password'"
                  autocomplete="current-password"
                  required
                />
                <button
                  type="button"
                  :aria-label="showPassword ? t('auth.hidePassword') : t('auth.showPassword')"
                  @click="showPassword = !showPassword"
                >
                  <svg v-if="showPassword" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7">
                    <path d="M3 3l18 18" />
                    <path d="M10.5 10.7a2 2 0 0 0 2.8 2.8" />
                    <path d="M9.9 5.1A10.8 10.8 0 0 1 12 5c5 0 9.3 3.1 11 7a11.8 11.8 0 0 1-4.1 5" />
                    <path d="M6.1 6.1A11.6 11.6 0 0 0 1 12c.7 1.6 1.8 3 3.2 4.1" />
                  </svg>
                  <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7">
                    <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" />
                    <circle cx="12" cy="12" r="3" />
                  </svg>
                </button>
              </div>
            </div>
          </template>

          <p v-if="auth.error" class="login__error" role="alert">{{ auth.error }}</p>

          <button class="ui-btn ui-btn--primary login__submit" type="submit" :disabled="auth.loading">
            <AppIcon :name="showTwoFactor ? 'lock' : 'key'" :size="16" />
            {{ auth.loading ? t('common.loading') : showTwoFactor ? t('auth.verify') : t('auth.login') }}
          </button>
        </div>

        <div class="login__form-foot">
          <p class="login__secure">{{ t('auth.secureNote') }}</p>
          <button v-if="showTwoFactor" class="login__quiet" type="button" @click="useAnotherAccount">
            <AppIcon name="account" :size="14" />
            {{ t('auth.changeAccount') }}
          </button>
          <button v-else class="login__quiet" type="button" @click="fillDemo">
            <AppIcon name="account" :size="14" />
            {{ t('auth.useDemo') }}
          </button>
        </div>
      </form>
    </main>

    <WorkspaceSplash
      v-if="showSplash"
      :brand-name="splashBrand"
      :tagline="splashTagline"
      :logo-url="tenantLogo"
      :boot="bootWorkspace"
      @done="onSplashDone"
    />
  </div>
</template>

<style scoped>
@keyframes login-rise {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes login-fade {
  from { opacity: 0; }
  to { opacity: 1; }
}

.login {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(22rem, 0.95fr);
  width: 100%;
  max-width: 100%;
  margin-inline: auto;
  height: 100%;
  min-height: 100dvh;
  overflow: hidden;
  background: #f4f6f8;
  font-family: var(--font-sans, "IBM Plex Sans", system-ui, sans-serif);
}

.login__brand {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 0;
  min-height: 0;
  padding: clamp(2rem, 5vh, 3.5rem) clamp(1.75rem, 4vw, 3.25rem);
  overflow: hidden;
  background: #0a1523;
  border-right: 0;
  color: #fff;
  isolation: isolate;
  font-family: inherit;
}

.login__scene {
  position: absolute;
  /* Crop past the baked-in logo in login-background.png */
  inset: -14% -10% -10%;
  z-index: 0;
  width: auto;
  height: auto;
  min-width: 122%;
  min-height: 122%;
  object-fit: cover;
  object-position: 62% 12%;
  filter: brightness(0.94) contrast(1.05) saturate(1.05) blur(3.5px);
  transform: scale(1.04);
  pointer-events: none;
  user-select: none;
  animation: login-fade 900ms var(--ease-out, ease) both;
}

.login__brand-veil {
  position: absolute;
  inset: 0;
  z-index: 1;
  /* Stronger dark glass so copy stays readable over the photo */
  background:
    linear-gradient(
      180deg,
      color-mix(in srgb, #071018 68%, transparent) 0%,
      color-mix(in srgb, #071018 48%, transparent) 34%,
      color-mix(in srgb, #071018 55%, transparent) 62%,
      color-mix(in srgb, #071018 82%, transparent) 100%
    );
  backdrop-filter: blur(2px);
  -webkit-backdrop-filter: blur(2px);
  pointer-events: none;
}

.login__watermark {
  display: none;
}

.login__brand-inner {
  position: relative;
  z-index: 3;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: clamp(1.25rem, 2.8vh, 2rem);
  flex-shrink: 0;
  width: min(100%, 34rem);
  margin: auto;
  padding-block: 0.35rem;
  text-align: center;
  animation: login-rise 520ms var(--ease-out, ease) both;
}

.login__identity {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.9rem;
  min-width: 0;
}

.login__brand-logo {
  width: 3.25rem;
  height: 3.25rem;
  flex-shrink: 0;
  object-fit: contain;
  padding: 0.3rem;
  border-radius: 0.7rem;
  background: var(--color-surface);
}

.login__brand-mark {
  display: block;
  width: auto;
  height: clamp(4.5rem, 9.5vh, 6.25rem);
  max-width: min(100%, 16rem);
  margin: 0 auto 1.35rem;
  object-fit: contain;
  filter: brightness(0) invert(1) drop-shadow(0 8px 28px rgba(0, 0, 0, 0.35));
  opacity: 0.98;
}

.login__visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.login__kicker,
.login__eyebrow {
  margin: 0 0 0.85rem;
  max-width: 28rem;
  font-size: clamp(0.88rem, 1.35vw, 1.05rem);
  font-weight: 600;
  letter-spacing: 0.14em;
  line-height: 1.4;
  text-transform: uppercase;
  color: color-mix(in srgb, var(--login-accent, #e39b2b) 92%, #fff);
  text-shadow: 0 1px 12px rgba(0, 0, 0, 0.35);
}

.login__brand-mid {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 100%;
}

.login__brand-mid h1 {
  margin: 0;
  max-width: 14ch;
  font-family: inherit;
  font-size: clamp(2.35rem, 3.6vw, 3.1rem);
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1.08;
  text-align: center;
  text-wrap: balance;
  color: #fff;
  text-shadow: 0 2px 24px rgba(0, 0, 0, 0.35);
}

.login__trade {
  margin: 0.75rem 0 0;
  font-family: inherit;
  font-size: clamp(1.15rem, 2vw, 1.45rem);
  font-weight: 600;
  letter-spacing: -0.02em;
  line-height: 1.35;
  color: #fff;
  text-align: center;
  text-shadow: 0 2px 16px rgba(0, 0, 0, 0.4);
}

.login__brand-mid > p:not(.login__trade):not(.login__eyebrow) {
  margin: 1.1rem 0 0;
  max-width: 38ch;
  font-family: inherit;
  font-size: clamp(1rem, 1.5vw, 1.15rem);
  font-weight: 400;
  letter-spacing: 0;
  line-height: 1.6;
  color: rgba(255, 255, 255, 0.9);
  text-align: center;
  text-shadow: 0 1px 12px rgba(0, 0, 0, 0.35);
}

.login__eyebrow,
.login__point-title,
.login__foot {
  font-family: inherit;
}

.login__brand-bottom {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5rem;
  width: 100%;
}

.login__points {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 0.55rem 1.35rem;
  width: 100%;
  margin: 0;
  padding: 1.15rem 0 0;
  border-top: 1px solid rgba(255, 255, 255, 0.16);
  list-style: none;
}

.login__points li {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  min-width: 0;
  padding: 0;
  border: 0;
  background: transparent;
  text-align: left;
}

.login__point-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: color-mix(in srgb, var(--login-accent, #e39b2b) 28%, transparent);
  color: var(--login-accent, #e39b2b);
}

.login__point-title {
  font-size: clamp(0.92rem, 1.2vw, 1.05rem);
  font-weight: 600;
  line-height: 1.35;
  color: rgba(255, 255, 255, 0.95);
}

.login__foot {
  margin: 0;
  font-size: 0.85rem;
  font-weight: 400;
  color: rgba(255, 255, 255, 0.62);
  text-align: center;
}

.login__panel {
  position: relative;
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  height: 100%;
  align-items: stretch;
  justify-content: stretch;
  padding: 0;
  overflow: auto;
  background: #f4f6f8;
}

.login__panel-frame {
  display: none;
}

.login__form {
  position: relative;
  z-index: 1;
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  box-sizing: border-box;
  width: 100%;
  max-width: none;
  height: 100%;
  min-height: 100%;
  margin: 0;
  padding: clamp(1.5rem, 4vh, 2.25rem) clamp(1.5rem, 4vw, 2.75rem) 1.65rem;
  background: #fff;
  border: 0;
  border-radius: 0;
  box-shadow: none;
  animation: login-rise 640ms 60ms var(--ease-out, ease) both;
}

.login__form-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.15rem;
}

.login__form-brand {
  min-width: 0;
}

.login__tools {
  position: relative;
  z-index: 2;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.login__form-head {
  padding: 0;
}

.login__logo {
  display: block;
  width: auto;
  height: 3.75rem;
  max-width: 10rem;
  margin: 0;
  object-fit: contain;
  object-position: left center;
}

.login__mark {
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  margin: 0;
  border-radius: 8px;
  background: var(--login-primary, #12243c);
  color: #fff;
  font-family: inherit;
  font-size: 0.95rem;
  font-weight: 600;
}

.login__form-kicker {
  margin: 0 0 0.5rem;
  font-size: 0.8125rem;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--login-accent, #e39b2b);
}

.login__form-body {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  justify-content: center;
  min-height: 0;
  padding: 1.35rem 0 0;
}

.login__form-foot {
  margin-top: auto;
  padding: 1.25rem 0 0;
  border-top: 1px solid var(--color-border, #e3e7eb);
  background: transparent;
}

.login__form,
.login__panel {
  font-family: inherit;
}

.login__form h2 {
  margin: 0;
  font-family: inherit;
  font-size: clamp(1.75rem, 2.4vw, 2rem);
  font-weight: 600;
  line-height: 1.2;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.login__lead {
  margin: 0.5rem 0 0;
  font-family: inherit;
  font-size: 1.05rem;
  font-weight: 400;
  line-height: 1.5;
  color: var(--color-text-muted);
}

.login__form-kicker,
.login__form :deep(.ui-input),
.login__form :deep(.ui-label),
.login__form :deep(.field-label),
.login__submit,
.login__quiet,
.login__secure {
  font-family: inherit;
}

.login__form :deep(.ui-field) {
  width: 100%;
  margin-bottom: 1.15rem;
}

.login__form :deep(.ui-field + .ui-field) {
  margin-top: 0;
}

.login__form :deep(.ui-label),
.login__form :deep(.field-label) {
  font-size: 0.9375rem;
}

.login__form :deep(.ui-input) {
  width: 100%;
  min-height: 3.25rem;
  font-size: 1rem;
  font-weight: 400;
  background: #f7f9fb;
  border: 1px solid var(--color-border-strong, #d7e0e8);
  border-radius: 8px;
  transition: border-color 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
}

.login__form :deep(.ui-input:hover) {
  border-color: #c3d0db;
  background: #f3f6f9;
}

.login__form :deep(.ui-input:focus) {
  background: var(--color-surface);
  border-color: var(--login-primary, #12243c);
  box-shadow: 0 0 0 3px rgba(18, 36, 60, 0.14);
}

.login__label-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--space-3);
}

.login__label-row .ui-label,
.login__label-row .field-label {
  margin-bottom: 6px;
}

.login__label-row a {
  margin-bottom: 6px;
  font-size: var(--text-label, 13px);
  font-weight: 500;
  line-height: var(--line-label, 18px);
  color: var(--color-ink-brand, var(--login-primary));
  text-decoration: none;
}

.login__label-row a:hover {
  text-decoration: underline;
}

.login__secret {
  position: relative;
}

.login__secret .ui-input {
  padding-right: 2.7rem;
}

.login__secret button {
  position: absolute;
  top: 0;
  right: 0.2rem;
  display: flex;
  width: 2.45rem;
  height: 100%;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: 0.65rem;
  background: transparent;
  color: var(--color-text-faint);
  cursor: pointer;
}

.login__secret button:hover {
  color: var(--color-ink-brand, var(--login-primary));
  background: color-mix(in srgb, var(--login-primary) 8%, transparent);
}

.login__secret svg {
  width: 1rem;
  height: 1rem;
}

.login__otp {
  text-align: center;
  letter-spacing: 0.32em;
}

.login__error {
  margin: 0 0 0.85rem;
  padding: 0.7rem 0.8rem;
  border-radius: 8px;
  border: 1px solid #fecaca;
  background: var(--color-danger-bg);
  color: light-dark(#b42318, #e0a39e);
  font-size: 0.9375rem;
}

.login__submit {
  width: 100%;
  margin-top: 0.25rem;
  min-height: 3.25rem;
  border: 0;
  border-radius: 8px;
  font-size: 1.05rem;
  font-weight: 600;
  letter-spacing: 0;
  background: var(--login-primary, #12243c);
  color: #fff;
  box-shadow: 0 1px 2px rgba(15, 31, 52, 0.18);
  transition: background 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}

.login__submit:hover:not(:disabled) {
  background: color-mix(in srgb, var(--login-primary, #12243c) 88%, #000);
  box-shadow: 0 4px 12px rgba(15, 31, 52, 0.18);
}

.login__submit:active:not(:disabled) {
  transform: scale(0.985);
}

.login__submit:disabled {
  opacity: 0.7;
}

.login__secure {
  margin: 0;
  font-size: 0.8125rem;
  line-height: 1.45;
  color: var(--color-text-muted);
  text-align: center;
}

.login__quiet {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  width: 100%;
  margin-top: 0.65rem;
  padding: 0.55rem 0.75rem;
  border: 1px solid var(--color-border, #e3e7eb);
  border-radius: 8px;
  background: #f7f9fb;
  color: var(--color-text-secondary);
  font-size: 0.9375rem;
  font-weight: 500;
  cursor: pointer;
  text-align: center;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}

.login__quiet:hover {
  background: var(--color-surface);
  border-color: color-mix(in srgb, var(--login-primary) 28%, var(--color-border));
  color: var(--color-ink-brand, var(--login-primary));
}

@media (max-width: 900px) {
  .login {
    display: flex;
    flex-direction: column;
    height: auto;
    min-height: 100dvh;
    overflow: visible;
  }

  .login__brand {
    padding: 1.5rem 1.25rem 1.4rem;
    min-height: 12.5rem;
  }

  .login__scene {
    inset: -10% -6% -6%;
    min-width: 112%;
    min-height: 112%;
    object-position: 55% 20%;
  }

  .login__brand-veil {
    background:
      linear-gradient(
        180deg,
        color-mix(in srgb, #071018 48%, transparent) 0%,
        color-mix(in srgb, #071018 16%, transparent) 40%,
        color-mix(in srgb, #071018 68%, transparent) 100%
      );
  }

  .login__brand-mark {
    height: 2.5rem;
    margin-bottom: 0.75rem;
  }

  .login__rule {
    display: none;
  }

  .login__brand-inner {
    gap: 0.75rem;
    width: 100%;
    height: auto;
    min-height: 0;
  }

  .login__brand-bottom,
  .login__brand-mid > p:not(.login__trade):not(.login__eyebrow),
  .login__rule,
  .login__eyebrow {
    display: none;
  }

  .login__brand,
  .login__panel,
  .login__form {
    min-width: 0;
    max-width: 100%;
  }

  .login__brand-mid h1 {
    max-width: 22ch;
    font-size: 1.55rem;
  }

  .login__trade {
    font-size: 0.9rem;
  }

  .login__panel {
    flex: 1;
    align-items: stretch;
    justify-content: stretch;
    padding: 0;
    min-height: 0;
  }

  .login__form {
    width: 100%;
    max-width: none;
    min-height: 100%;
    margin: 0;
    padding: 1.25rem 1.15rem 1.2rem;
  }

  .login__form-top {
    margin-bottom: 0.95rem;
  }

  .login__label-row {
    flex-wrap: wrap;
  }
}

@media (prefers-reduced-motion: reduce) {
  .login__brand-inner,
  .login__form,
  .login__scene,
  .login__tools {
    animation: none;
  }
}
</style>
