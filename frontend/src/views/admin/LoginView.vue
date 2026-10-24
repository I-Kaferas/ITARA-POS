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
import { api, extractApiErrorMessage } from '../../api/client'
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
const showPasswordConfirm = ref(false)
const logoFailed = ref(false)
const showSplash = ref(false)
const company = ref<Company | null>(null)
const registering = computed(() => route.query.intent === 'register')
const signupDone = ref(false)
const signupError = ref('')
const signupBusy = ref(false)
const companyName = ref('')
const adminName = ref('')
const phone = ref('')
const passwordConfirm = ref('')
const plan = ref('starter')
const plans = ['starter', 'professional', 'business', 'enterprise'] as const
const planIcons = {
  starter: 'device-pos',
  professional: 'restaurant',
  business: 'bed',
  enterprise: 'layers',
} as const

const branding = computed(() => brandingStore.branding)
const loginPrimary = computed(() => customColor(branding.value?.primary_color, '#12243c') ?? 'var(--color-brand-600)')
const loginAccent = computed(() => customColor(branding.value?.accent_color, '#e39b2b') ?? 'var(--color-accent)')
const loginLogoUrl = computed(() => ITARA_LOGO_URL)

function customColor(color: string | null | undefined, legacyDefault: string): string | null {
  const value = color?.trim()
  return value && value.toLowerCase() !== legacyDefault ? value : null
}
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
  if (registering.value) {
    if (!signupDone.value) await submitSignup()
    return
  }
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

async function submitSignup() {
  signupError.value = ''
  if (password.value !== passwordConfirm.value) {
    signupError.value = t('auth.signupPasswordMismatch')
    return
  }
  signupBusy.value = true
  try {
    const response = await api.post<{ data: { message: string } }>('/public/signup', {
      company_name: companyName.value.trim(),
      admin_name: adminName.value.trim(),
      email: email.value.trim(),
      phone: phone.value.trim() || null,
      password: password.value,
      password_confirmation: passwordConfirm.value,
      plan: plan.value,
    }, { skipOffline: true })
    signupDone.value = true
    signupError.value = ''
    void response
  } catch (err) {
    signupError.value = extractApiErrorMessage(err)
  } finally {
    signupBusy.value = false
  }
}
</script>

<template>
  <div
    class="login"
    :class="{ 'login--signup': registering || signupDone }"
    :inert="showSplash"
    :style="{
      '--login-primary': loginPrimary,
      '--login-accent': loginAccent,
    }"
  >
    <aside class="login__brand">
      <img
        class="login__scene"
        src="/brand/login-background.png"
        alt=""
        aria-hidden="true"
      />
      <div class="login__veil" aria-hidden="true" />
      <div class="login__brand-copy">
        <div v-if="registering || signupDone" class="login__signup-bar">
          <img
            v-if="!logoFailed"
            class="login__signup-mark"
            :src="loginLogoUrl"
            alt=""
            @error="logoFailed = true"
          />
          <span v-else class="login__signup-fallback" aria-hidden="true">{{ initial }}</span>
          <div class="login__signup-id">
            <p class="login__eyebrow">Business CORE</p>
            <p class="login__signup-name">{{ PRODUCT_NAME }}</p>
          </div>
          <LanguageSwitcher tone="glass" compact />
        </div>
        <div class="login__brand-top">
          <p class="login__eyebrow">Business CORE</p>
          <h1 class="login__visually-hidden">{{ PRODUCT_NAME }}</h1>
          <p class="login__trade">{{ t('auth.brandTitle') }}</p>
          <p class="login__brand-lead">{{ t('auth.brandSubtitle') }}</p>
        </div>
        <div class="login__brand-bottom">
        <ul class="login__points">
          <li>
            <span class="login__point-icon" aria-hidden="true"><AppIcon name="device-pos" :size="16" /></span>
            <span class="login__point-title">{{ t('auth.featureCatalog') }}</span>
            <span class="login__point-desc">{{ t('auth.featureCatalogDesc') }}</span>
          </li>
          <li>
            <span class="login__point-icon" aria-hidden="true"><AppIcon name="bed" :size="16" /></span>
            <span class="login__point-title">{{ t('auth.featureStores') }}</span>
            <span class="login__point-desc">{{ t('auth.featureStoresDesc') }}</span>
          </li>
          <li>
            <span class="login__point-icon" aria-hidden="true"><AppIcon name="inventory" :size="16" /></span>
            <span class="login__point-title">{{ t('auth.featureSaas') }}</span>
            <span class="login__point-desc">{{ t('auth.featureSaasDesc') }}</span>
          </li>
        </ul>
        <p class="login__foot">© {{ new Date().getFullYear() }} {{ PRODUCT_NAME }}</p>
        </div>
      </div>
    </aside>

    <main class="login__panel">
      <form class="login__form" :class="{ 'login__form--signup': registering || signupDone }" @submit.prevent="submit">
        <div class="login__tools">
          <LanguageSwitcher />
        </div>

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

        <div class="login__form-head">
          <p class="login__form-kicker">{{ PRODUCT_NAME }}</p>
          <h2>{{ showTwoFactor ? t('auth.twoFactorTitle') : registering ? t('auth.signupTitle') : t('auth.login') }}</h2>
          <p class="login__lead">
            {{ showTwoFactor ? t('auth.twoFactorSubtitle') : registering ? t('auth.signupSubtitle') : t('auth.loginSubtitle') }}
          </p>
        </div>

        <div class="login__form-body">
          <template v-if="signupDone">
            <div class="signup-done">
              <span class="signup-done__mark" aria-hidden="true"><AppIcon name="check" :size="22" /></span>
              <h3>{{ t('auth.signupTitle') }}</h3>
              <p>{{ t('auth.signupSent') }}</p>
              <RouterLink class="ui-btn ui-btn--primary login__submit" to="/login">{{ t('auth.backToLogin') }}</RouterLink>
            </div>
          </template>
          <template v-else-if="registering">
            <section class="signup-section">
              <header class="signup-section__head">
                <span class="signup-section__step" aria-hidden="true">01</span>
                <p class="signup-section__title">{{ t('auth.signupSectionOrg') }}</p>
              </header>
              <div class="signup-grid">
                <div class="ui-field">
                  <FieldLabel icon="building" for="company">{{ t('auth.signupCompany') }}</FieldLabel>
                  <input id="company" v-model="companyName" class="ui-input" type="text" autocomplete="organization" required />
                </div>
                <div class="ui-field">
                  <FieldLabel icon="account" for="admin-name">{{ t('auth.signupAdmin') }}</FieldLabel>
                  <input id="admin-name" v-model="adminName" class="ui-input" type="text" autocomplete="name" required />
                </div>
                <div class="ui-field">
                  <FieldLabel icon="mail" for="signup-email">{{ t('auth.email') }}</FieldLabel>
                  <input id="signup-email" v-model="email" class="ui-input" type="email" autocomplete="email" required />
                </div>
                <div class="ui-field">
                  <FieldLabel icon="phone" for="phone">{{ t('auth.signupPhone') }}</FieldLabel>
                  <input id="phone" v-model="phone" class="ui-input" type="tel" autocomplete="tel" />
                </div>
              </div>
            </section>

            <section class="signup-section">
              <header class="signup-section__head">
                <span class="signup-section__step" aria-hidden="true">02</span>
                <p class="signup-section__title">{{ t('auth.signupPlan') }}</p>
              </header>
              <div class="signup-plans" role="radiogroup" :aria-label="t('auth.signupPlan')">
                <label
                  v-for="item in plans"
                  :key="item"
                  class="signup-plan"
                  :class="{ 'is-on': plan === item }"
                >
                  <input v-model="plan" type="radio" name="plan" :value="item" />
                  <span class="signup-plan__icon" aria-hidden="true">
                    <AppIcon :name="planIcons[item]" :size="16" />
                  </span>
                  <span class="signup-plan__copy">
                    <span class="signup-plan__name">{{ t(`auth.signupPlans.${item}.name`) }}</span>
                    <span class="signup-plan__hint">{{ t(`auth.signupPlans.${item}.hint`) }}</span>
                  </span>
                  <span class="signup-plan__radio" aria-hidden="true"></span>
                </label>
              </div>
            </section>

            <section class="signup-section">
              <header class="signup-section__head">
                <span class="signup-section__step" aria-hidden="true">03</span>
                <p class="signup-section__title">{{ t('auth.signupSectionAccess') }}</p>
              </header>
              <p class="signup-note">{{ t('auth.signupPasswordHint') }}</p>
              <div class="signup-grid">
                <div class="ui-field">
                  <FieldLabel icon="lock" for="signup-password">{{ t('auth.password') }}</FieldLabel>
                  <div class="login__secret">
                    <input
                      id="signup-password"
                      v-model="password"
                      class="ui-input"
                      :type="showPassword ? 'text' : 'password'"
                      autocomplete="new-password"
                      minlength="8"
                      required
                    />
                    <button
                      type="button"
                      :aria-label="showPassword ? t('auth.hidePassword') : t('auth.showPassword')"
                      @click="showPassword = !showPassword"
                    >
                      <AppIcon name="eye" :size="16" />
                    </button>
                  </div>
                </div>
                <div class="ui-field">
                  <FieldLabel icon="lock" for="password-confirm">{{ t('auth.confirmPassword') }}</FieldLabel>
                  <div class="login__secret">
                    <input
                      id="password-confirm"
                      v-model="passwordConfirm"
                      class="ui-input"
                      :type="showPasswordConfirm ? 'text' : 'password'"
                      autocomplete="new-password"
                      minlength="8"
                      required
                    />
                    <button
                      type="button"
                      :aria-label="showPasswordConfirm ? t('auth.hidePassword') : t('auth.showPassword')"
                      @click="showPasswordConfirm = !showPasswordConfirm"
                    >
                      <AppIcon name="eye" :size="16" />
                    </button>
                  </div>
                </div>
              </div>
            </section>

            <div class="signup-actions">
              <p v-if="signupError" class="login__error" role="alert">
                <AppIcon name="alert" :size="18" />
                <span>{{ signupError }}</span>
              </p>
              <button class="ui-btn ui-btn--primary login__submit" type="submit" :disabled="signupBusy">
                <AppIcon name="check" :size="16" />
                {{ signupBusy ? t('common.loading') : t('auth.signupSubmit') }}
              </button>
              <RouterLink class="login__quiet" to="/login">{{ t('auth.backToLogin') }}</RouterLink>
            </div>
          </template>
          <div v-else-if="showTwoFactor" class="ui-field">
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

          <p v-if="!registering && !signupDone && auth.error" class="login__error" role="alert">
            <AppIcon name="alert" :size="18" />
            <span>{{ auth.error }}</span>
          </p>

          <button v-if="!registering && !signupDone" class="ui-btn ui-btn--primary login__submit" type="submit" :disabled="auth.loading">
            <AppIcon :name="showTwoFactor ? 'lock' : 'key'" :size="16" />
            {{ auth.loading ? t('common.loading') : showTwoFactor ? t('auth.verify') : t('auth.login') }}
          </button>
        </div>

        <div v-if="!registering && !signupDone" class="login__form-foot">
          <p class="login__secure">{{ t('auth.secureNote') }}</p>
          <RouterLink class="login__quiet" :to="{ path: '/login', query: { intent: 'register' } }">
            <AppIcon name="building" :size="14" />
            {{ t('auth.signupLink') }}
          </RouterLink>
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
  grid-template-columns: minmax(0, 1.2fr) minmax(24rem, 0.8fr);
  width: 100%;
  max-width: 100%;
  margin: 0;
  /* html zoom shrinks 100dvh, so fill the app shell instead. */
  height: 100%;
  max-height: none;
  min-height: 100%;
  overflow: hidden;
  background: var(--color-canvas);
  color: var(--color-text-primary);
  font-family: var(--font-sans);
}

.login__brand {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: stretch;
  min-width: 0;
  min-height: 0;
  height: 100%;
  padding: 0;
  overflow: hidden;
  background: #071018;
  border-right: 0;
  color: #fff;
  isolation: isolate;
  font-family: inherit;
}

.login__scene {
  position: absolute;
  inset: 0;
  z-index: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center bottom;
  filter: brightness(0.6) contrast(1.05);
  pointer-events: none;
  user-select: none;
  animation: login-fade 700ms var(--ease-out, ease) both;
}

.login__veil {
  position: absolute;
  inset: 0;
  z-index: 0;
  background: rgba(7, 16, 24, 0.72);
  pointer-events: none;
}

.login__brand-copy {
  position: relative;
  z-index: 1;
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  justify-content: space-between;
  min-height: 0;
  width: auto;
  height: 100%;
  margin: 0;
  padding: 0 2.25rem;
  box-sizing: border-box;
  background: transparent;
  text-align: center;
  animation: login-rise 520ms var(--ease-out, ease) both;
}

.login__brand-top,
.login__brand-bottom {
  width: min(100%, 40rem);
  margin-inline: auto;
}

.login__brand-top {
  padding-top: 2.75rem;
  padding-bottom: 1.5rem;
}

.login__brand-bottom {
  padding-top: 1.5rem;
  padding-bottom: 2.5rem;
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
  margin: 0 0 0.45rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  line-height: 1.3;
  text-transform: uppercase;
  color: var(--login-accent, #e39b2b);
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
  margin: 0;
  max-width: 16ch;
  font-family: inherit;
  font-size: clamp(2rem, 2.8vw, 2.65rem);
  font-weight: 650;
  letter-spacing: -0.035em;
  line-height: 1.08;
  color: #fff;
  text-align: center;
  margin-inline: auto;
}

.login__brand-lead {
  margin: 0.35rem 0 0;
  max-width: 48ch;
  font-size: 0.84rem;
  font-weight: 400;
  line-height: 1.5;
  color: rgba(255, 255, 255, 0.74);
  text-align: center;
  margin-inline: auto;
}

.login__eyebrow,
.login__point-title,
.login__foot {
  font-family: inherit;
}

.login__points {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.7rem;
  width: 100%;
  margin: 0;
  padding: 0;
  list-style: none;
}

.login__points li {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  min-width: 0;
  padding: 0.85rem 0.85rem 0.75rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  background: rgba(8, 16, 26, 0.38);
  backdrop-filter: blur(10px);
  text-align: center;
}

.login__point-icon {
  display: grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 8px;
  background: rgba(227, 155, 43, 0.16);
  color: var(--login-accent, #e39b2b);
}

.login__point-title {
  font-size: 0.84rem;
  font-weight: 650;
  line-height: 1.3;
  color: #fff;
}

.login__point-desc {
  font-size: 0.8rem;
  line-height: 1.35;
  color: rgba(255, 255, 255, 0.66);
}

.login__foot {
  margin: 0.85rem 0 0;
  font-size: 0.75rem;
  font-weight: 500;
  letter-spacing: 0.02em;
  color: rgba(255, 255, 255, 0.48);
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
  background:
    radial-gradient(640px 320px at 100% 0%, color-mix(in srgb, var(--color-brand-500) 7%, transparent), transparent 70%),
    radial-gradient(520px 280px at 0% 100%, color-mix(in srgb, var(--color-accent) 7%, transparent), transparent 70%),
    var(--color-surface);
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
  padding: var(--space-10) var(--space-7) var(--space-7);
  background: transparent;
  border: 0;
  border-radius: 0;
  box-shadow: none;
  animation: login-rise var(--motion-page) 60ms var(--ease-out, ease) both;
}

/* Keep the sign-in column at a comfortable reading width. */
.login__form:not(.login__form--signup) > :not(.login__tools) {
  width: 100%;
  max-width: 28rem;
  margin-inline: auto;
}

.login__form-brand {
  min-width: 0;
  margin-bottom: 1.15rem;
}

.login__tools {
  position: absolute;
  top: 1.15rem;
  right: 1.25rem;
  z-index: 2;
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
  border-radius: var(--radius-md);
  background: var(--login-primary);
  color: #fff;
  font-family: inherit;
  font-size: 0.95rem;
  font-weight: 600;
}

.login__form-kicker {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0 0 var(--space-3);
  font-size: var(--text-xs);
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--color-ink-brand);
}

.login__form-kicker::before {
  content: "";
  width: 1.5rem;
  height: 3px;
  border-radius: var(--radius-pill);
  background: linear-gradient(90deg, var(--login-primary), var(--login-accent));
}

.login__form-body {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  justify-content: center;
  min-height: 0;
  padding: 1.15rem 0 0;
}

.login__form-foot {
  margin-top: 1.25rem;
  padding: 0.95rem 0 0;
  border-top: 1px solid var(--color-border, #e3e7eb);
  background: transparent;
}

.login__form,
.login__panel {
  font-family: inherit;
}

.login__form h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(1.75rem, 1.4rem + 1.2vw, 2.25rem);
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.login__lead {
  max-width: 60ch;
  margin: var(--space-2) 0 0;
  font-family: inherit;
  font-size: var(--text-md);
  font-weight: 400;
  line-height: 1.6;
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
  min-height: var(--control-xl);
  padding-inline: var(--space-4);
  font-size: var(--text-base);
  font-weight: 400;
  color: var(--color-text-primary);
  background: var(--color-surface);
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  box-shadow: inset 0 1px 2px rgba(15, 23, 42, 0.03);
  transition:
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-normal) var(--ease-out),
    background-color var(--motion-fast) var(--ease-out);
}

.login__form :deep(.ui-input:hover:not(:focus)) {
  border-color: #94a3b8;
}

.login__form :deep(.ui-input:focus) {
  outline: none;
  background: var(--color-surface);
  border-color: var(--login-primary);
  box-shadow: 0 0 0 4px color-mix(in srgb, var(--login-primary) 22%, transparent);
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

.login__secret :deep(.ui-input) {
  padding-right: 3.25rem;
}

.login__secret button {
  position: absolute;
  top: 50%;
  right: 2px;
  display: flex;
  width: var(--touch-min);
  height: var(--touch-min);
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--color-text-muted);
  cursor: pointer;
  transform: translateY(-50%);
  transition: background-color var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.login__secret button:hover {
  color: var(--color-ink-brand);
  background: var(--color-brand-50);
}

.login__secret button:focus-visible {
  outline: 2px solid var(--login-primary);
  outline-offset: -2px;
}

.login__secret svg {
  width: 1.25rem;
  height: 1.25rem;
}

.login__otp {
  text-align: center;
  letter-spacing: 0.32em;
}

.login__error {
  display: flex;
  align-items: flex-start;
  gap: var(--space-2);
  margin: 0 0 var(--space-4);
  padding: var(--space-3) var(--space-4);
  border: 1px solid #fecaca;
  border-left: 4px solid var(--color-danger);
  border-radius: var(--radius-md);
  background: var(--color-danger-bg);
  color: var(--color-danger-strong);
  font-size: var(--text-sm);
  font-weight: 500;
  line-height: 1.5;
  animation: bright-slide-up var(--motion-normal) var(--ease-out);
}

.login__error :deep(svg) {
  flex-shrink: 0;
  margin-top: 1px;
}

.login__submit {
  width: 100%;
  margin-top: var(--space-1);
  min-height: var(--control-xl);
  border: 1px solid color-mix(in srgb, var(--login-primary) 80%, #000);
  border-radius: var(--radius-md);
  font-size: var(--text-md);
  font-weight: 600;
  letter-spacing: -0.005em;
  background: linear-gradient(180deg, var(--login-primary), color-mix(in srgb, var(--login-primary) 86%, #000));
  color: #fff;
  box-shadow:
    0 1px 2px color-mix(in srgb, var(--login-primary) 24%, transparent),
    0 8px 20px -6px color-mix(in srgb, var(--login-primary) 45%, transparent);
  transition:
    box-shadow var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out),
    filter var(--motion-fast) var(--ease-out);
}

.login__submit:hover:not(:disabled) {
  transform: var(--lift);
  filter: brightness(1.04);
  box-shadow:
    0 2px 4px color-mix(in srgb, var(--login-primary) 24%, transparent),
    0 14px 28px -8px color-mix(in srgb, var(--login-primary) 55%, transparent);
}

.login__submit:active:not(:disabled) {
  transform: translateY(0) scale(0.98);
  transition-duration: var(--motion-fast);
}

.login__submit:focus-visible {
  outline: 2px solid var(--login-primary);
  outline-offset: 3px;
}

.login__submit:disabled {
  opacity: 0.65;
  cursor: progress;
}

.login__secure {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  margin: 0;
  font-size: var(--text-xs);
  line-height: 1.5;
  color: var(--color-text-muted);
  text-align: center;
}

.login__quiet {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  width: 100%;
  min-height: var(--touch-min);
  margin-top: var(--space-3);
  padding: var(--space-2) var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
  font-weight: 500;
  cursor: pointer;
  text-align: center;
  text-decoration: none;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.login__quiet:hover {
  background: var(--color-brand-50);
  border-color: var(--color-brand-200);
  color: var(--color-ink-brand);
  transform: var(--lift);
}

.login__quiet:focus-visible {
  outline: 2px solid var(--login-primary);
  outline-offset: 2px;
}

.login__signup-bar {
  display: none;
}

.login--signup {
  grid-template-columns: minmax(0, 1.2fr) minmax(24rem, 0.8fr);
}

.login--signup .login__brand-copy {
  overflow: hidden;
}

.login--signup .login__form-brand {
  display: none;
}

.login--signup .login__panel {
  overflow: hidden;
}

.login__form--signup {
  flex: 1 1 auto;
  width: min(100%, 52rem);
  height: 100%;
  min-height: 0;
  max-height: 100%;
  margin: 0 auto;
  padding: clamp(0.7rem, 1.6vh, 1.15rem) clamp(1.25rem, 2vw, 2.15rem) clamp(0.45rem, 1.2vh, 0.85rem);
  overflow: hidden;
  justify-content: center;
}

.login--signup .login__tools {
  top: 1.35rem;
  right: 2.35rem;
}

.login--signup .login__form-head {
  padding-right: 9.5rem;
}

.login--signup .login__form--signup .login__form-body {
  flex: 0 0 auto;
  min-height: 0;
  justify-content: flex-start;
  overflow: hidden;
}

.login__form--signup h2 {
  font-size: clamp(1.28rem, 1.7vw, 1.6rem);
}

.login__form--signup .login__form-kicker {
  margin-bottom: 0.35rem;
}

.login__form--signup .login__lead {
  max-width: 52ch;
  margin-top: 0.2rem;
  font-size: 0.84rem;
  line-height: 1.35;
}

.login__form--signup .login__form-body {
  flex: 0 1 auto;
  justify-content: flex-start;
  overflow: hidden;
  padding-top: 0.45rem;
  scrollbar-width: none;
}

.login__form--signup :deep(.ui-input) {
  min-height: 2.35rem;
  padding-top: 0.3rem;
  padding-bottom: 0.3rem;
}

.signup-section + .signup-section {
  margin-top: 0.15rem;
  padding-top: 0.55rem;
  border-top: 1px solid var(--color-table-border);
}

.signup-section__head {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0 0 0.4rem;
}

.signup-section__step {
  display: grid;
  place-items: center;
  width: 1.7rem;
  height: 1.7rem;
  flex-shrink: 0;
  border-radius: var(--radius-pill);
  background: var(--color-brand-50);
  color: var(--color-ink-brand);
  box-shadow: inset 0 0 0 1px var(--color-brand-100);
  font-size: var(--text-2xs);
  font-weight: 700;
  letter-spacing: 0.04em;
  line-height: 1;
}

.signup-section__title {
  margin: 0;
  color: var(--color-text-secondary);
  font-size: var(--text-xs);
  font-weight: 700;
  letter-spacing: 0.12em;
  line-height: 1.3;
  text-transform: uppercase;
}

.signup-note {
  margin: 0 0 0.35rem;
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  line-height: 1.35;
}

.signup-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 0.65rem;
}

.signup-grid :deep(.ui-field) {
  margin-bottom: 0.4rem;
}

.signup-plans {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.45rem;
  margin: 0;
}

.signup-plan {
  position: relative;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: center;
  gap: 0.1rem 0.5rem;
  min-height: 0;
  padding: 0.55rem 1.65rem 0.55rem 0.6rem;
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  cursor: pointer;
  transition:
    border-color var(--motion-fast) var(--ease-out),
    background-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.signup-plan__icon {
  display: grid;
  place-items: center;
  width: 1.85rem;
  height: 1.85rem;
  border-radius: var(--radius-sm, 8px);
  background: var(--color-surface-muted);
  color: var(--color-text-secondary);
  transition: background-color var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.signup-plan:hover {
  border-color: var(--color-brand-300);
  box-shadow: var(--shadow-sm);
  transform: var(--lift);
}

.signup-plan input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.signup-plan.is-on {
  border-color: var(--login-primary);
  background: var(--color-brand-50);
  box-shadow: 0 0 0 1px var(--login-primary), var(--shadow-sm);
}

.signup-plan.is-on .signup-plan__icon {
  background: var(--login-primary);
  color: #fff;
}

.signup-plan:has(input:focus-visible) {
  outline: 2px solid var(--login-primary);
  outline-offset: 2px;
}

/* Selected state is shown by the check mark, not by color alone. */
.signup-plan__radio {
  position: absolute;
  top: 0.45rem;
  right: 0.4rem;
  display: grid;
  place-items: center;
  width: 1.05rem;
  height: 1.05rem;
  border: 1.5px solid var(--color-border-strong);
  border-radius: 50%;
  background: var(--color-surface);
  transition: background-color var(--motion-fast) var(--ease-out), border-color var(--motion-fast) var(--ease-out);
}

.signup-plan.is-on .signup-plan__radio {
  border-color: var(--login-primary);
  background: var(--login-primary);
}

.signup-plan.is-on .signup-plan__radio::after {
  content: "";
  width: 0.45rem;
  height: 0.26rem;
  margin-top: -0.12rem;
  border-bottom: 2px solid #fff;
  border-left: 2px solid #fff;
  transform: rotate(-45deg);
}

.signup-plan__copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.08rem;
}

.signup-plan__name {
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-weight: 700;
  line-height: 1.3;
}

.signup-plan__hint {
  color: var(--color-text-muted);
  font-size: 0.72rem;
  line-height: 1.3;
}

.signup-actions {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  margin-top: 0.15rem;
  padding-top: 0.15rem;
  background: transparent;
}

.login__form--signup .login__submit {
  min-height: 2.55rem;
  margin-top: 0.2rem;
}

.signup-actions .login__quiet {
  margin-top: 0;
  border: 0;
  background: transparent;
  padding: var(--space-2) var(--space-3);
}

.signup-actions .login__quiet:hover {
  border-color: transparent;
  background: transparent;
  color: var(--color-ink-brand);
  text-decoration: underline;
  text-underline-offset: 3px;
  transform: none;
}

.login__signup-mark,
.login__signup-fallback {
  width: 2.35rem;
  height: 2.35rem;
  flex-shrink: 0;
  border-radius: 0.55rem;
  background: #fff;
}

.login__signup-mark {
  object-fit: contain;
  padding: 0.2rem;
}

.login__signup-fallback {
  display: grid;
  place-items: center;
  color: #12243c;
  font-weight: 700;
}

.login__signup-id {
  min-width: 0;
  flex: 1 1 auto;
}

.login__signup-bar .login__eyebrow {
  margin: 0;
}

.login__signup-name {
  margin: 0.05rem 0 0;
  color: #fff;
  font-size: 0.95rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  line-height: 1.15;
}

.login__signup-bar :deep(.lang) {
  flex-shrink: 0;
}

.signup-done {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.7rem;
  max-width: 28rem;
  margin: auto 0;
}

.signup-done {
  animation: bright-slide-up var(--motion-slow) var(--ease-out) backwards;
}

.signup-done__mark {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  border-radius: var(--radius-lg);
  background: var(--color-success-bg);
  color: var(--color-success);
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--color-success) 22%, transparent);
}

.signup-done h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: clamp(1.375rem, 1.2rem + 0.8vw, 1.75rem);
  font-weight: 700;
  letter-spacing: -0.025em;
}

.signup-done p {
  max-width: 60ch;
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-base);
  line-height: 1.6;
}

.signup-done .login__submit {
  width: auto;
  min-width: 12rem;
  text-decoration: none;
}

@media (max-width: 1100px) {
  .login__trade {
    font-size: 1.85rem;
  }
}

@media (max-width: 900px) {
  .login {
    display: flex;
    flex-direction: column;
    height: 100%;
    max-height: 100%;
    min-height: 0;
    overflow: hidden;
  }

  .login__brand {
    height: 11rem;
    min-height: 11rem;
    flex: 0 0 auto;
  }

  .login__scene {
    object-position: center 58%;
  }

  .login__brand-copy {
    width: auto;
    height: 100%;
    margin: 0;
    padding: 1.15rem 1rem;
  }

  .login__points,
  .login__brand-lead,
  .login__foot {
    display: none;
  }

  .login__trade {
    max-width: none;
    font-size: 1.35rem;
  }

  .login__brand,
  .login__panel,
  .login__form {
    min-width: 0;
    max-width: 100%;
  }

  .login__panel {
    flex: 1 1 auto;
    align-items: stretch;
    justify-content: stretch;
    padding: 0;
    min-height: 0;
    height: auto;
    width: 100%;
    overflow: hidden;
  }

  .login__form {
    width: 100%;
    max-width: none;
    min-height: 0;
    height: auto;
    flex: 1 1 auto;
    margin: 0;
    padding: 3.5rem 1.25rem 1.25rem;
    overflow: hidden;
  }

  .login__form-body {
    min-height: 0;
    justify-content: flex-start;
    overflow: auto;
  }

  .login__form-foot {
    flex-shrink: 0;
  }

  .login__label-row {
    flex-wrap: wrap;
  }

  .signup-grid,
  .signup-plans {
    grid-template-columns: 1fr;
  }

  .login--signup .login__brand {
    height: auto;
    min-height: 0;
    background: #071018;
  }

  .login--signup .login__scene,
  .login--signup .login__veil,
  .login--signup .login__brand-top,
  .login--signup .login__brand-bottom,
  .login--signup .login__tools,
  .login--signup .login__form-kicker {
    display: none;
  }

  .login--signup .login__brand-copy {
    height: auto;
    padding: 0;
  }

  .login--signup .login__signup-bar {
    display: flex;
    align-items: center;
    gap: 0.7rem;
    width: 100%;
    padding: 0.7rem 0.85rem 0.72rem;
    border-bottom: 2px solid var(--login-accent, #e39b2b);
  }

  .login--signup {
    grid-template-columns: minmax(0, 1fr);
  }

  .login--signup .login__brand-copy {
    padding: 0;
    overflow: visible;
    text-align: center;
  }

  .login--signup .login__form,
  .login--signup .login__form--signup {
    width: 100%;
    max-height: none;
    margin: 0;
    padding: 1.05rem 1.05rem 0.65rem;
    justify-content: flex-start;
  }

  .login--signup .login__form-head {
    padding-right: 0;
  }

  .login--signup .login__lead {
    font-size: 0.9rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  .login__brand-copy,
  .login__form,
  .login__scene,
  .login__tools,
  .login__error,
  .signup-done {
    animation: none;
  }

  .login__submit:hover:not(:disabled),
  .login__quiet:hover,
  .signup-plan:hover {
    transform: none;
  }
}
</style>
