<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import LanguageSwitcher from '../../components/ui/LanguageSwitcher.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { useAuthStore } from '../../stores/auth'
import { useBrandingStore } from '../../stores/branding'
import { useContextStore } from '../../stores/context'

const DEMO_EMAIL = 'admin@pos.local'
const DEMO_PASSWORD = 'password'
const DEFAULT_SLUG = 'demo'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const brandingStore = useBrandingStore()
const context = useContextStore()

const email = ref('')
const password = ref('')
const twoFactorCode = ref('')
const showTwoFactor = ref(false)
const showPassword = ref(false)
const logoFailed = ref(false)

const branding = computed(() => brandingStore.branding)
const brandName = computed(() => branding.value?.brand_name?.trim() || 'ITARA NEXUS')
const tenantSlug = computed(() => branding.value?.slug || resolveTenantSlug())
const logoUrl = computed(() => branding.value?.logo_url?.trim() || '')
const initial = computed(() => brandName.value[0]?.toUpperCase() || 'P')

/** Headline: avoid repeating brand name when API defaults hero_title to brand_name. */
const panelHeadline = computed(() => {
  const title = branding.value?.marketing.hero_title?.trim() || ''
  if (title && title.toLowerCase() !== brandName.value.toLowerCase()) return title
  return branding.value?.tagline?.trim() || t('auth.brandTitle')
})

const panelLede = computed(() => {
  const sub = branding.value?.marketing.hero_subtitle?.trim()
  if (sub) return sub
  return branding.value?.tagline?.trim() && panelHeadline.value !== branding.value.tagline
    ? branding.value.tagline
    : t('auth.brandSubtitle')
})

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

function fillDemo() {
  email.value = DEMO_EMAIL
  password.value = DEMO_PASSWORD
}

function useAnotherAccount() {
  showTwoFactor.value = false
  twoFactorCode.value = ''
  auth.error = null
}

async function submit() {
  try {
    if (showTwoFactor.value) {
      await auth.verifyTwoFactor(twoFactorCode.value)
      await context.loadStores()
      void brandingStore.loadCurrent().catch(() => undefined)
      router.push({ name: 'dashboard' })
      return
    }

    const result = await auth.login(email.value, password.value)
    if (result.requiresTwoFactor) {
      showTwoFactor.value = true
      return
    }

    await context.loadStores()
    void brandingStore.loadCurrent().catch(() => undefined)
    router.push({ name: 'dashboard' })
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
      <div class="login__brand-top">
        <div class="login__lockup">
          <img
            v-if="logoUrl && !logoFailed"
            class="login__logo"
            :src="logoUrl"
            alt=""
            @error="logoFailed = true"
          />
          <span v-else class="login__mark">{{ initial }}</span>
          <span class="login__name">{{ brandName }}</span>
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
        <p class="login__eyebrow">{{ t('auth.eyebrow') }}</p>
        <h2>{{ showTwoFactor ? t('auth.twoFactorTitle') : t('auth.login') }}</h2>
        <p class="login__lead">
          {{ showTwoFactor ? t('auth.twoFactorSubtitle') : t('auth.loginSubtitle') }}
        </p>

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

        <p class="login__secure">{{ t('auth.secureNote') }}</p>

        <button v-if="showTwoFactor" class="login__quiet" type="button" @click="useAnotherAccount">
          {{ t('auth.changeAccount') }}
        </button>
        <button v-else class="login__quiet" type="button" @click="fillDemo">
          {{ t('auth.useDemo') }}
        </button>
      </form>
    </main>
  </div>
</template>

<style scoped>
.login {
  display: grid;
  grid-template-columns: minmax(20rem, 40%) 1fr;
  width: 100%;
  height: 100vh;
  height: 100dvh;
  overflow: hidden;
  background: #fff;
}

.login__brand {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 2rem;
  min-height: 0;
  padding: 2rem 2.25rem 1.75rem;
  background: #12181e;
  color: #fff;
}

.login__brand-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.login__lockup {
  display: flex;
  align-items: center;
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
  object-fit: cover;
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
}

.login__brand-mid h1 {
  margin: 0;
  font-family: var(--font-brand);
  font-size: clamp(1.55rem, 2.2vw, 2rem);
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1.2;
}

.login__brand-mid p {
  margin: 0.85rem 0 0;
  max-width: 22rem;
  font-size: 0.925rem;
  line-height: 1.55;
  color: rgba(255, 255, 255, 0.58);
}

.login__points {
  margin: 0;
  padding: 0;
  list-style: none;
}

.login__points li {
  position: relative;
  padding: 0.55rem 0 0.55rem 1rem;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  font-size: 0.8125rem;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.72);
}

.login__points li:last-child {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.login__points li::before {
  content: "";
  position: absolute;
  left: 0;
  top: 50%;
  width: 0.35rem;
  height: 0.35rem;
  border-radius: 50%;
  background: var(--login-accent);
  transform: translateY(-50%);
}

.login__foot {
  margin: 0;
  font-size: 0.72rem;
  color: rgba(255, 255, 255, 0.32);
}

.login__panel {
  position: relative;
  display: flex;
  min-width: 0;
  min-height: 0;
  align-items: center;
  justify-content: center;
  padding: 4.5rem 2rem 2.5rem;
  background: #f4f6f8;
}

.login__tools {
  position: absolute;
  top: 1.1rem;
  right: 1.25rem;
}

.login__form {
  width: min(100%, 23.5rem);
  padding: 1.75rem 1.65rem 1.5rem;
  background: #fff;
  border: 1px solid #e4e8ec;
  border-radius: 0.85rem;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
}

.login__eyebrow {
  margin: 0 0 0.35rem;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--login-primary);
}

.login__form h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.45rem;
  font-weight: 600;
  letter-spacing: -0.03em;
  color: #1c2830;
}

.login__lead {
  margin: 0.35rem 0 1.35rem;
  font-size: 0.875rem;
  line-height: 1.5;
  color: #66727c;
}

.login__form :deep(.ui-field + .ui-field) {
  margin-top: 0.9rem;
}

.login__label-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
}

.login__label-row .ui-label,
.login__label-row .field-label {
  margin-bottom: 0.375rem;
}

.login__label-row a {
  margin-bottom: 0.375rem;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-brand-600);
  text-decoration: none;
}

.login__label-row a:hover {
  color: var(--color-brand-700);
}

.login__secret {
  position: relative;
}

.login__secret .ui-input {
  padding-right: 2.6rem;
}

.login__secret button {
  position: absolute;
  top: 0;
  right: 0.15rem;
  display: flex;
  width: 2.4rem;
  height: 100%;
  align-items: center;
  justify-content: center;
  border: 0;
  background: transparent;
  color: #8b97a1;
  cursor: pointer;
}

.login__secret button:hover {
  color: #1c2830;
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
  margin: 0.85rem 0 0;
  padding: 0.55rem 0.7rem;
  border-radius: 0.5rem;
  background: var(--color-danger-bg);
  color: #b42318;
  font-size: 0.8125rem;
}

.login__submit {
  width: 100%;
  margin-top: 1.15rem;
  min-height: 2.55rem;
}

.login__secure {
  margin: 0.85rem 0 0;
  font-size: 0.72rem;
  line-height: 1.4;
  color: #94a3b8;
  text-align: center;
}

.login__quiet {
  display: block;
  width: 100%;
  margin-top: 0.85rem;
  padding: 0;
  border: 0;
  background: transparent;
  color: #8b97a1;
  font-size: 0.75rem;
  cursor: pointer;
  text-align: center;
}

.login__quiet:hover {
  color: var(--login-primary);
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
    align-items: flex-start;
    padding: 1.5rem 1.15rem 2rem;
  }

  .login__form {
    width: 100%;
    border-radius: 0.75rem;
  }

  .login__tools {
    top: 1rem;
    right: 1rem;
  }
}
</style>
