<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import LanguageSwitcher from '../../components/ui/LanguageSwitcher.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'
import type { Company } from '../../types'

const DEMO_EMAIL = 'admin@pos.local'
const DEMO_PASSWORD = 'password'
const DEFAULT_SLUG = 'demo'
const WELCOME_DURATION_MS = 4800
const WELCOME_EXIT_MS = 380
const ITARA_LOGO_URL = '/brand/itara-nexus-logo.png?v=2'
const LOGIN_BACKGROUND_URL = '/brand/login-background.png'

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
const welcomeLogoFailed = ref(false)
const showWelcome = ref(false)
const welcomeLeaving = ref(false)
const company = ref<Company | null>(null)
let welcomeTimer: ReturnType<typeof setTimeout> | null = null
let welcomeExitTimer: ReturnType<typeof setTimeout> | null = null

const branding = computed(() => brandingStore.branding)
const brandName = computed(() =>
  company.value?.trade_name?.trim()
  || company.value?.name?.trim()
  || branding.value?.brand_name?.trim()
  || 'ITARA NEXUS SUITE Business',
)
const tenantSlug = computed(() => branding.value?.slug || resolveTenantSlug())
const loginLogoUrl = computed(() =>
  ITARA_LOGO_URL,
)
const welcomeLogoUrl = computed(() =>
  welcomeLogoFailed.value ? '' : ITARA_LOGO_URL,
)
const initial = computed(() => 'I')
const userName = computed(() => auth.user?.name?.trim() || '')
const welcomeFirstName = computed(() => {
  const parts = userName.value.split(/\s+/).filter(Boolean)
  return parts[0] || userName.value
})

/** Prefer curated product copy on login; branding marketing only if it is specific. */
const panelHeadline = computed(() => {
  const title = branding.value?.marketing.hero_title?.trim() || ''
  if (
    title
    && title.toLowerCase() !== brandName.value.toLowerCase()
    && title.toLowerCase() !== 'itara nexus'
  ) {
    return title
  }
  return t('auth.brandTitle')
})

const panelLede = computed(() => {
  const sub = branding.value?.marketing.hero_subtitle?.trim() || ''
  const generic = [
    'point de vente professionnel',
    'vendez plus vite',
    'suivez vos stocks',
  ]
  const isGeneric = !sub || generic.some(part => sub.toLowerCase().includes(part))
  if (sub && !isGeneric) return sub
  return t('auth.brandSubtitle')
})

const welcomeMessage = computed(() => t('auth.welcomeModalMessage'))

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
  const parts = host.split('.')
  if (parts.length >= 3 && parts[0] && parts[0] !== 'www' && parts[0] !== 'localhost') {
    return parts[0].toLowerCase()
  }

  return DEFAULT_SLUG
}

onMounted(() => {
  void brandingStore.loadPublic(resolveTenantSlug()).catch(() => undefined)
})

onBeforeUnmount(() => {
  if (welcomeTimer) clearTimeout(welcomeTimer)
  if (welcomeExitTimer) clearTimeout(welcomeExitTimer)
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

async function prepareWelcome() {
  welcomeLogoFailed.value = false
  showWelcome.value = true
  welcomeLeaving.value = false
  if (welcomeTimer) clearTimeout(welcomeTimer)
  if (welcomeExitTimer) clearTimeout(welcomeExitTimer)
  welcomeTimer = setTimeout(() => {
    void enterApplication()
  }, WELCOME_DURATION_MS)

  // Warm company/store context in the background; never block the welcome splash.
  void (async () => {
    try {
      await context.loadStores()
    } catch {
      // ignore
    }
    try {
      await brandingStore.loadCurrent()
    } catch {
      // ignore
    }
    try {
      company.value = await resolveCompany()
    } catch {
      // ignore
    }
  })()
}

async function enterApplication() {
  if (welcomeLeaving.value) return
  welcomeLeaving.value = true
  if (welcomeTimer) {
    clearTimeout(welcomeTimer)
    welcomeTimer = null
  }
  await new Promise<void>((resolve) => {
    welcomeExitTimer = setTimeout(() => resolve(), WELCOME_EXIT_MS)
  })
  welcomeExitTimer = null
  showWelcome.value = false
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
    :style="{
      '--login-primary': branding?.primary_color || '#3D5C73',
      '--login-accent': branding?.accent_color || '#E39B2B',
    }"
  >
    <aside class="login__brand">
      <div class="login__brand-bg" aria-hidden="true">
        <img
          class="login__brand-photo"
          :src="LOGIN_BACKGROUND_URL"
          alt=""
        />
      </div>

      <div class="login__brand-top">
        <div class="login__lockup">
          <img
            v-if="loginLogoUrl && !logoFailed"
            class="login__logo login__logo--wordmark"
            :src="loginLogoUrl"
            alt="ITARA NEXUS SUITE Business"
            @error="logoFailed = true"
          />
          <template v-else>
            <span class="login__mark">{{ initial }}</span>
            <span class="login__name">{{ brandName }}</span>
          </template>
        </div>
        <p class="login__tenant">{{ tenantSlug }}</p>
      </div>

      <div class="login__brand-mid">
        <h1>{{ panelHeadline }}</h1>
        <p>{{ panelLede }}</p>
      </div>

      <ul class="login__points">
        <li>{{ t('auth.featureCatalog') }}</li>
        <li>{{ t('auth.featureStores') }}</li>
        <li>{{ t('auth.featureSaas') }}</li>
      </ul>

      <p class="login__foot">© {{ new Date().getFullYear() }} {{ brandName }}</p>
    </aside>

    <main class="login__panel">
      <div class="login__tools">
        <LanguageSwitcher />
      </div>

      <form class="login__form" @submit.prevent="submit">
        <div class="login__form-accent" aria-hidden="true" />

        <div class="login__form-head">
          <p class="login__eyebrow">{{ t('auth.eyebrow') }}</p>
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
            {{ auth.loading ? t('common.loading') : showTwoFactor ? t('auth.verify') : t('auth.login') }}
          </button>
        </div>

        <div class="login__form-foot">
          <p class="login__secure">{{ t('auth.secureNote') }}</p>
          <button v-if="showTwoFactor" class="login__quiet" type="button" @click="useAnotherAccount">
            {{ t('auth.changeAccount') }}
          </button>
          <button v-else class="login__quiet" type="button" @click="fillDemo">
            {{ t('auth.useDemo') }}
          </button>
        </div>
      </form>
    </main>

    <Teleport to="body">
      <div
        v-if="showWelcome"
        class="login-welcome"
        :class="{ 'login-welcome--leaving': welcomeLeaving }"
        :style="{
          '--login-primary': branding?.primary_color || '#3D5C73',
          '--login-accent': branding?.accent_color || '#E39B2B',
          '--welcome-duration': `${WELCOME_DURATION_MS}ms`,
        }"
        role="dialog"
        aria-modal="true"
        aria-labelledby="login-welcome-title"
      >
        <div class="login-welcome__bg" aria-hidden="true">
          <span class="login-welcome__orb login-welcome__orb--a" />
          <span class="login-welcome__orb login-welcome__orb--b" />
        </div>

        <div class="login-welcome__frame">
          <div class="login-welcome__logo-block login-welcome__anim" style="--d: 40ms">
            <img
              v-if="welcomeLogoUrl"
              class="login-welcome__logo"
              :src="welcomeLogoUrl"
              alt="ITARA NEXUS SUITE Business"
              @error="welcomeLogoFailed = true"
            />
            <span v-else class="login-welcome__mark">{{ initial }}</span>
          </div>

          <p
            v-if="welcomeFirstName"
            class="login-welcome__hello login-welcome__anim"
            style="--d: 220ms"
          >
            {{ t('auth.welcomeModalHello', { name: welcomeFirstName }) }}
          </p>

          <h2
            id="login-welcome-title"
            class="login-welcome__title login-welcome__anim"
            style="--d: 320ms"
          >
            {{ t('auth.welcomeModalTitle') }}
          </h2>

          <p class="login-welcome__message login-welcome__anim" style="--d: 420ms">
            {{ welcomeMessage }}
          </p>

          <p class="login-welcome__slogan login-welcome__anim" style="--d: 500ms">
            {{ t('auth.welcomeSlogan') }}
          </p>

          <div class="login-welcome__meter login-welcome__anim" style="--d: 580ms" aria-hidden="true">
            <span class="login-welcome__meter-bar" />
          </div>

          <button
            type="button"
            class="login-welcome__cta login-welcome__anim"
            style="--d: 680ms"
            :disabled="welcomeLeaving"
            @click="enterApplication"
          >
            <span>{{ t('auth.welcomeContinue') }}</span>
            <span class="login-welcome__cta-arrow" aria-hidden="true">→</span>
          </button>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.login {
  display: grid;
  grid-template-columns: 1fr 1fr;
  width: 100%;
  height: 100vh;
  height: 100dvh;
  overflow: hidden;
  background: #fff;
}

.login__brand {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: center;
  gap: 2rem;
  min-height: 0;
  padding: 2rem 2.25rem 1.75rem;
  background: #12181e;
  color: #fff;
  overflow: hidden;
  text-align: center;
}

.login__brand-photo {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  user-select: none;
}

.login__brand-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 0;
}

.login__brand-bg::after {
  content: '';
  position: absolute;
  inset: 0;
  background:
    linear-gradient(180deg, rgba(10, 14, 20, 0.55) 0%, rgba(10, 14, 20, 0.35) 42%, rgba(10, 14, 20, 0.78) 100%);
}

.login__brand-top,
.login__brand-mid,
.login__points,
.login__foot {
  position: relative;
  z-index: 1;
  width: 100%;
}

.login__brand-top {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
}

.login__lockup {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.7rem;
  min-width: 0;
}

.login__logo,
.login__mark {
  width: 2.15rem;
  height: 2.15rem;
  border-radius: 0.45rem;
  flex-shrink: 0;
}

.login__logo {
  object-fit: contain;
  background: transparent;
  border-radius: 0;
}

.login__logo--wordmark {
  width: auto;
  height: 2.6rem;
  max-width: 9.5rem;
}

.login__mark {
  display: grid;
  place-items: center;
  background: var(--login-primary);
  color: #fff;
  font-family: var(--font-brand);
  font-size: 0.85rem;
  font-weight: 700;
}

.login__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--font-brand);
  font-size: 0.82rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.login__tenant {
  margin: 0;
  font-family: var(--font-mono);
  font-size: 0.7rem;
  color: rgba(255, 255, 255, 0.38);
  text-align: center;
}

.login__brand-mid {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 1;
  max-width: 26rem;
  margin: 0 auto;
}

.login__brand-mid h1 {
  margin: 0;
  max-width: 18ch;
  font-family: var(--font-brand);
  font-size: clamp(1.55rem, 2.2vw, 2rem);
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1.25;
  text-align: center;
}

.login__brand-mid p {
  margin: 0.95rem 0 0;
  max-width: 28rem;
  font-size: 0.925rem;
  line-height: 1.55;
  color: rgba(255, 255, 255, 0.58);
  text-align: center;
}

.login__points {
  margin: 0 auto;
  padding: 0;
  list-style: none;
  width: 100%;
  max-width: 22rem;
}

.login__points li {
  position: relative;
  padding: 0.65rem 0.5rem;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  font-size: 0.8125rem;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.72);
  text-align: center;
}

.login__points li:last-child {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.login__points li::before {
  content: "";
  display: block;
  width: 0.35rem;
  height: 0.35rem;
  margin: 0 auto 0.4rem;
  border-radius: 50%;
  background: var(--login-accent);
}

.login__foot {
  margin: 0;
  font-size: 0.72rem;
  color: rgba(255, 255, 255, 0.32);
  text-align: center;
}

.login__panel {
  position: relative;
  display: flex;
  min-width: 0;
  min-height: 0;
  align-items: stretch;
  justify-content: stretch;
  padding: 0;
  background: #fff;
}

.login__tools {
  position: absolute;
  top: 1.25rem;
  right: 1.5rem;
  z-index: 2;
}

.login__form {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-height: 100%;
  overflow: auto;
  padding: 0;
  background:
    radial-gradient(circle at 92% 8%, color-mix(in srgb, var(--login-accent) 9%, #fff), transparent 26%),
    radial-gradient(circle at 6% 94%, color-mix(in srgb, var(--login-primary) 8%, #fff), transparent 28%),
    linear-gradient(180deg, #ffffff 0%, #f7f9fb 100%);
  border: 0;
  border-radius: 0;
  box-shadow: none;
}

.login__form-accent {
  flex-shrink: 0;
  height: 5px;
  background: linear-gradient(
    90deg,
    var(--login-primary),
    var(--login-accent)
  );
}

.login__form-head {
  flex-shrink: 0;
  padding: 4.5rem clamp(1.75rem, 4.5vw, 4rem) 0;
}

.login__form-body {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 1.75rem clamp(1.75rem, 4.5vw, 4rem) 2rem;
}

.login__form-foot {
  flex-shrink: 0;
  margin-top: auto;
  padding: 1.25rem clamp(1.75rem, 4.5vw, 4rem) 1.75rem;
  border-top: 1px solid #edf1f5;
  background: #fbfcfd;
}

.login__eyebrow {
  display: inline-flex;
  align-items: center;
  margin: 0 0 0.55rem;
  padding: 0.28rem 0.55rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--login-primary) 10%, #fff);
  font-size: 0.68rem;
  font-weight: 700;
  line-height: 1;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--login-primary);
}

.login__form h2 {
  margin: 0;
  font-family: var(--font-sans);
  font-size: 2rem;
  font-weight: 650;
  line-height: 1.15;
  letter-spacing: -0.035em;
  color: #132029;
}

.login__lead {
  margin: 0.55rem 0 0;
  font-size: 0.98rem;
  line-height: 1.5;
  color: #62727e;
}

.login__form :deep(.ui-field) {
  margin-bottom: 1.15rem;
}

.login__form :deep(.ui-field + .ui-field) {
  margin-top: 0;
}

.login__form :deep(.ui-input) {
  min-height: 3.05rem;
  font-size: 0.98rem;
  background: #f8fafc;
  border: 1px solid #d7e0e8;
  border-radius: 0.85rem;
  transition: border-color 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
}

.login__form :deep(.ui-input:hover) {
  border-color: #c3d0db;
  background: #fff;
}

.login__form :deep(.ui-input:focus) {
  background: #fff;
  border-color: var(--login-primary);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--login-primary) 18%, transparent);
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
  font-size: var(--text-xs);
  font-weight: 600;
  line-height: var(--line-xs);
  color: var(--login-primary);
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
  color: #8b97a1;
  cursor: pointer;
}

.login__secret button:hover {
  color: var(--login-primary);
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
  padding: 0.65rem 0.75rem;
  border-radius: 0.7rem;
  border: 1px solid #fecaca;
  background: #fef2f2;
  color: #b42318;
  font-size: 0.8125rem;
}

.login__submit {
  width: 100%;
  margin-top: 0.35rem;
  min-height: 3.15rem;
  border: 0;
  border-radius: 0.9rem;
  font-size: 1rem;
  font-weight: 650;
  letter-spacing: 0.01em;
  background: linear-gradient(
    135deg,
    var(--login-primary) 0%,
    color-mix(in srgb, var(--login-primary) 78%, #1a2833) 100%
  );
  box-shadow: 0 12px 24px color-mix(in srgb, var(--login-primary) 26%, transparent);
  transition: transform 0.15s ease, filter 0.15s ease;
}

.login__submit:hover:not(:disabled) {
  filter: brightness(1.05);
  transform: translateY(-1px);
}

.login__submit:disabled {
  opacity: 0.7;
  transform: none;
}

.login__secure {
  margin: 0;
  font-size: 0.72rem;
  line-height: 1.45;
  color: #7d8c98;
  text-align: center;
}

.login__quiet {
  display: block;
  width: 100%;
  margin-top: 0.7rem;
  padding: 0.45rem 0;
  border: 0;
  background: transparent;
  color: #6d7d8a;
  font-size: 0.78rem;
  font-weight: 550;
  cursor: pointer;
  text-align: center;
}

.login__quiet:hover {
  color: var(--login-primary);
}

.login-welcome {
  position: fixed;
  inset: 0;
  z-index: 80;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100vw;
  height: 100vh;
  height: 100dvh;
  padding: 1.5rem;
  overflow: hidden;
  background: #0c1218;
  color: #fff;
  text-align: center;
  animation: login-welcome-fade 0.45s ease both;
}

.login-welcome--leaving {
  animation: login-welcome-fade-out 0.38s ease both;
  pointer-events: none;
}

.login-welcome__bg {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(ellipse 60% 45% at 50% 38%, color-mix(in srgb, var(--login-primary) 14%, transparent), transparent 72%),
    linear-gradient(180deg, #0e141b 0%, #0c1218 55%, #0a0f14 100%);
}

.login-welcome__orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(56px);
  pointer-events: none;
  opacity: 0.35;
}

.login-welcome__orb--a {
  left: 50%;
  top: 42%;
  width: min(22rem, 58vw);
  height: min(22rem, 58vw);
  transform: translate(-50%, -50%);
  background: color-mix(in srgb, var(--login-accent) 10%, transparent);
  animation: login-welcome-orb 4.8s ease-in-out both;
}

.login-welcome__orb--b {
  left: 50%;
  top: 58%;
  width: min(14rem, 40vw);
  height: min(14rem, 40vw);
  transform: translate(-50%, -50%);
  background: color-mix(in srgb, var(--login-primary) 12%, transparent);
  animation: login-welcome-orb 4.8s ease-in-out both;
  animation-delay: 0.15s;
}

.login-welcome__frame {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: min(100%, 26rem);
  margin: 0 auto;
}

.login-welcome__anim {
  animation: login-welcome-pop 0.65s cubic-bezier(0.22, 1, 0.36, 1) both;
  animation-delay: var(--d, 0ms);
}

.login-welcome__logo-block {
  display: flex;
  justify-content: center;
  margin-bottom: 1.35rem;
}

.login-welcome__logo {
  display: block;
  width: min(72vw, 18rem);
  height: auto;
  max-height: 12.5rem;
  object-fit: contain;
  filter: drop-shadow(0 10px 22px rgba(0, 0, 0, 0.28));
  animation: login-welcome-pulse 4.8s ease-in-out both;
}

.login-welcome__mark {
  display: grid;
  place-items: center;
  width: 6.5rem;
  height: 6.5rem;
  border-radius: 1.1rem;
  background: var(--login-primary);
  color: #fff;
  font-family: var(--font-brand);
  font-size: 2.1rem;
  font-weight: 700;
}

.login-welcome__hello {
  margin: 0 0 0.45rem;
  font-size: 0.78rem;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--login-accent);
}

.login-welcome__title {
  margin: 0;
  font-family: var(--font-brand);
  font-size: clamp(2.1rem, 5vw, 2.7rem);
  font-weight: 600;
  letter-spacing: -0.045em;
  line-height: 1.05;
  color: #fff;
}

.login-welcome__message {
  margin: 0.7rem 0 0;
  max-width: 22rem;
  font-size: 0.98rem;
  font-weight: 500;
  line-height: 1.45;
  color: rgba(255, 255, 255, 0.78);
}

.login-welcome__slogan {
  margin: 0.85rem 0 0;
  max-width: 22rem;
  font-family: var(--font-brand);
  font-size: 0.82rem;
  font-weight: 600;
  font-style: italic;
  letter-spacing: 0.04em;
  line-height: 1.4;
  color: color-mix(in srgb, var(--login-accent) 78%, #fff);
}

.login-welcome__meter {
  width: min(100%, 12.5rem);
  height: 2px;
  margin: 1.55rem auto 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.12);
  overflow: hidden;
}

.login-welcome__meter-bar {
  display: block;
  height: 100%;
  width: 0;
  border-radius: inherit;
  background: linear-gradient(
    90deg,
    color-mix(in srgb, var(--login-primary) 75%, #1a2833),
    color-mix(in srgb, var(--login-accent) 70%, #8a6a2e)
  );
  animation: login-welcome-progress var(--welcome-duration, 4.8s) linear both;
}

.login-welcome__cta {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.55rem;
  min-height: 2.7rem;
  margin-top: 1.25rem;
  padding: 0.7rem 1.45rem;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.07);
  color: #fff;
  font-size: 0.86rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s ease, border-color 0.2s ease, transform 0.2s ease;
}

.login-welcome__cta:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.14);
  border-color: rgba(255, 255, 255, 0.34);
  transform: translateY(-1px);
}

.login-welcome__cta:disabled {
  opacity: 0.55;
  cursor: default;
}

.login-welcome__cta-arrow {
  transition: transform 0.2s ease;
}

.login-welcome__cta:hover:not(:disabled) .login-welcome__cta-arrow {
  transform: translateX(3px);
}

@keyframes login-welcome-fade {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes login-welcome-fade-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes login-welcome-pop {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes login-welcome-pulse {
  0% { transform: scale(0.96); opacity: 0.92; }
  30% { transform: scale(1.01); opacity: 1; }
  100% { transform: scale(1); opacity: 1; }
}

@keyframes login-welcome-orb {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.92); }
  40% { opacity: 0.45; transform: translate(-50%, -50%) scale(1); }
  100% { opacity: 0.22; transform: translate(-50%, -50%) scale(1.04); }
}

@keyframes login-welcome-progress {
  from { width: 0%; }
  to { width: 100%; }
}

@media (max-width: 640px) {
  .login-welcome__logo {
    width: min(78vw, 14rem);
    max-height: 10rem;
  }

  .login-welcome__title {
    font-size: 1.9rem;
  }
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
    gap: 1.25rem;
    padding: 1.25rem 1.25rem 1.35rem;
  }

  .login__points,
  .login__foot,
  .login__brand-mid p {
    display: none;
  }

  .login__brand-mid h1 {
    font-size: 1.3rem;
  }

  .login__panel {
    flex: 1;
    min-height: 28rem;
    align-items: stretch;
    padding: 0;
  }

  .login__brand-logo {
    width: min(70%, 12rem);
    opacity: 0.12;
  }

  .login__form {
    width: 100%;
    height: 100%;
    min-height: 100%;
    border-radius: 0;
  }

  .login__form-head {
    padding: 3.5rem 1.25rem 0;
  }

  .login__form-body {
    padding: 1.25rem 1.25rem 1.5rem;
  }

  .login__form-foot {
    padding: 1rem 1.25rem 1.35rem;
  }

  .login__tools {
    top: 1rem;
    right: 1rem;
  }
}
</style>
