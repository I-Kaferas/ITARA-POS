<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute } from 'vue-router'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LanguageSwitcher from '../../../components/ui/LanguageSwitcher.vue'
import { useAuthStore } from '../../../stores/auth'
import { useBrandingStore } from '../../../stores/branding'

const ITARA_LOGO_URL = '/brand/itara-nexus-logo.png?v=2'
const PRODUCT_NAME = 'ITARA NEXUS'
const DEFAULT_SLUG = 'demo'

const { t } = useI18n()
const route = useRoute()
const auth = useAuthStore()
const brandingStore = useBrandingStore()

const email = ref('')
const sent = ref(false)
const message = ref('')
const error = ref('')
const logoFailed = ref(false)

const branding = computed(() => brandingStore.branding)

function resolveTenantSlug(): string {
  const fromQuery = typeof route.query.tenant === 'string' ? route.query.tenant.trim() : ''
  if (fromQuery) return fromQuery.toLowerCase()

  const host = window.location.hostname
  const isIp = /^\d{1,3}(\.\d{1,3}){3}$/.test(host)
  if (host === 'localhost' || host === '127.0.0.1' || isIp) return DEFAULT_SLUG

  const parts = host.split('.')
  if (parts.length >= 3 && parts[0] && parts[0] !== 'www') return parts[0].toLowerCase()
  return DEFAULT_SLUG
}

onMounted(() => {
  void brandingStore.loadPublic(resolveTenantSlug()).catch(() => undefined)
})

async function submit() {
  error.value = ''
  try {
    const res = await auth.forgotPassword(email.value.trim())
    message.value = res.message
    sent.value = true
  } catch (e) {
    error.value = e instanceof Error ? e.message : t('common.error')
  }
}

function editEmail() {
  sent.value = false
  message.value = ''
  error.value = ''
}
</script>

<template>
  <div
    class="recover"
    :style="{
      '--login-primary': branding?.primary_color || '#12243c',
      '--login-accent': branding?.accent_color || '#E39B2B',
    }"
  >
    <aside class="recover__brand">
      <img class="recover__watermark" :src="ITARA_LOGO_URL" alt="" aria-hidden="true" />
      <div class="recover__brand-inner">
        <span class="recover__rule" aria-hidden="true" />
        <h1>{{ PRODUCT_NAME }}</h1>
        <p class="recover__trade">{{ t('auth.forgotTitle') }}</p>
        <p>{{ t('auth.forgotAside') }}</p>
        <p class="recover__foot">© {{ new Date().getFullYear() }} {{ PRODUCT_NAME }}</p>
      </div>
    </aside>

    <main class="recover__panel">
      <div class="recover__tools">
        <LanguageSwitcher />
      </div>

      <section class="recover__card">
        <img
          v-if="!logoFailed"
          class="recover__logo"
          :src="ITARA_LOGO_URL"
          alt="ITARA NEXUS Business CORE"
          @error="logoFailed = true"
        />
        <span v-else class="recover__mark">I</span>

        <template v-if="!sent">
          <h2>{{ t('auth.forgotTitle') }}</h2>
          <p class="recover__lead">{{ t('auth.forgotSubtitle') }}</p>

          <form class="recover__form" @submit.prevent="submit">
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

            <p v-if="error" class="recover__error" role="alert">{{ error }}</p>

            <button class="ui-btn ui-btn--primary recover__submit" type="submit" :disabled="auth.loading">
              <AppIcon name="mail" :size="16" />
              {{ auth.loading ? t('common.loading') : t('auth.sendReset') }}
            </button>
          </form>
        </template>

        <template v-else>
          <span class="recover__sent-icon" aria-hidden="true">
            <AppIcon name="check" :size="22" />
          </span>
          <h2>{{ t('auth.forgotSentTitle') }}</h2>
          <p class="recover__lead">{{ message || t('auth.forgotSubtitle') }}</p>
          <p v-if="email" class="recover__email">{{ email }}</p>
          <RouterLink class="ui-btn ui-btn--primary recover__submit" :to="{ name: 'login' }">
            {{ t('auth.backToLogin') }}
          </RouterLink>
          <button class="recover__quiet" type="button" @click="editEmail">
            {{ t('auth.forgotChangeEmail') }}
          </button>
        </template>

        <RouterLink v-if="!sent" class="recover__back" :to="{ name: 'login' }">
          {{ t('auth.backToLogin') }}
        </RouterLink>
        <p class="recover__secure">{{ t('auth.secureNote') }}</p>
      </section>
    </main>
  </div>
</template>

<style scoped>
.recover {
  display: grid;
  grid-template-columns: minmax(0, 0.82fr) minmax(0, 1.18fr);
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: var(--color-surface);
}

.recover__brand {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 0;
  padding: clamp(1.75rem, 4vh, 3rem) clamp(1.5rem, 3vw, 2.75rem);
  overflow: hidden;
  background:
    radial-gradient(ellipse at 50% 46%, color-mix(in srgb, var(--login-accent, #e39b2b) 16%, transparent), transparent 58%),
    linear-gradient(168deg, color-mix(in srgb, var(--login-primary, #12243c) 78%, #3d5a78) 0%, var(--login-primary, #12243c) 46%, #0b1728 100%);
  color: #fff;
  isolation: isolate;
}

.recover__watermark {
  position: absolute;
  inset: 0;
  z-index: 0;
  width: 100%;
  height: 100%;
  padding: 8% 6%;
  object-fit: contain;
  opacity: 0.07;
  mix-blend-mode: screen;
  pointer-events: none;
  user-select: none;
}

.recover__brand-inner {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: min(100%, 28rem);
  text-align: center;
}

.recover__rule {
  display: block;
  width: 2.25rem;
  height: 3px;
  margin-bottom: 1.15rem;
  border-radius: 2px;
  background: var(--login-accent, #e39b2b);
}

.recover__brand-inner h1 {
  margin: 0;
  font-family: var(--font-brand);
  font-size: clamp(1.85rem, 2.6vw, 2.55rem);
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.recover__trade {
  margin: 0.55rem 0 0;
  font-size: 0.95rem;
  font-weight: 650;
  color: rgba(255, 255, 255, 0.9);
}

.recover__brand-inner p {
  margin: 0.9rem 0 0;
  max-width: 34ch;
  font-size: 0.98rem;
  line-height: 1.55;
  color: rgba(255, 255, 255, 0.78);
}

.recover__foot {
  margin-top: 2rem !important;
  font-size: 0.75rem !important;
  color: rgba(255, 255, 255, 0.46) !important;
}

.recover__panel {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 0;
  padding: clamp(4.5rem, 8vh, 5.5rem) clamp(1.75rem, 4vw, 3.25rem) clamp(2rem, 5vh, 3rem);
  background: var(--color-canvas);
}

.recover__tools {
  position: absolute;
  top: 1.25rem;
  right: 1.5rem;
  z-index: 2;
}

.recover__card {
  width: min(100%, 34rem);
  padding: 2.5rem 2.75rem 2rem;
  background: var(--color-surface);
  border: 1px solid #e3e7eb;
  border-radius: 12px;
}

.recover__logo {
  display: block;
  width: auto;
  height: 5.5rem;
  max-width: 10rem;
  margin: 0 0 1.4rem;
  object-fit: contain;
  object-position: left center;
}

.recover__mark {
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  margin-bottom: 1.15rem;
  border-radius: 8px;
  background: var(--login-primary, #12243c);
  color: #fff;
  font-family: var(--font-brand);
  font-size: 0.95rem;
  font-weight: 700;
}

.recover__card h2 {
  margin: 0;
  font-size: 2.05rem;
  font-weight: 650;
  line-height: 1.2;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.recover__lead {
  margin: 0.55rem 0 0;
  font-size: 1.05rem;
  line-height: 1.5;
  color: var(--color-text-muted);
}

.recover__form {
  display: flex;
  flex-direction: column;
  padding-top: 1.35rem;
}

.recover__form :deep(.ui-field) {
  margin-bottom: 1.15rem;
}

.recover__card :deep(.ui-input) {
  min-height: 3.25rem;
  font-size: 1.05rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border-strong, #d7e0e8);
  border-radius: var(--radius-md, 6px);
}

.recover__card :deep(.ui-input:focus) {
  border-color: var(--color-brand-600, #12243c);
  box-shadow: 0 0 0 2px var(--color-focus-ring, rgba(18, 36, 60, 0.28));
}

.recover__error {
  margin: 0 0 0.85rem;
  padding: 0.65rem 0.75rem;
  border: 1px solid #fecaca;
  border-radius: 0.7rem;
  background: var(--color-danger-bg);
  color: light-dark(#b42318, #e0a39e);
  font-size: 0.8125rem;
}

.recover__submit {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  width: 100%;
  min-height: 3.35rem;
  margin-top: 0.2rem;
  border: 0;
  border-radius: var(--radius-lg, 10px);
  font-size: 1.05rem;
  font-weight: 600;
  text-decoration: none;
  background: var(--color-brand-700, #0f1f34);
  box-shadow: 0 1px 1px rgba(15, 31, 52, 0.14);
}

.recover__submit:hover:not(:disabled) {
  background: var(--color-brand-800, #0d1a2b);
}

.recover__submit:disabled {
  opacity: 0.7;
}

.recover__sent-icon {
  display: grid;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  margin-bottom: 1rem;
  border-radius: 999px;
  background: #e8f6ef;
  color: #0f7a4d;
}

.recover__email {
  margin: 0.85rem 0 0;
  font-size: 0.95rem;
  font-weight: 650;
  color: var(--color-text-primary);
}

.recover__back,
.recover__quiet {
  display: block;
  width: 100%;
  margin-top: 0.9rem;
  padding: 0.35rem 0;
  border: 0;
  background: transparent;
  color: var(--color-ink-brand, var(--login-primary));
  font-size: 0.9rem;
  font-weight: 600;
  text-align: center;
  text-decoration: none;
  cursor: pointer;
}

.recover__back:hover,
.recover__quiet:hover {
  text-decoration: underline;
}

.recover__secure {
  margin: 1.15rem 0 0;
  font-size: 0.72rem;
  line-height: 1.45;
  color: var(--color-text-muted);
  text-align: center;
}

@media (max-width: 900px) {
  .recover {
    display: flex;
    flex-direction: column;
    height: auto;
    min-height: 100dvh;
    overflow: visible;
  }

  .recover__brand {
    padding: 1.35rem 1.25rem 1.15rem;
  }

  .recover__brand-inner h1 {
    font-size: 1.35rem;
  }

  .recover__brand-inner p,
  .recover__foot {
    display: none;
  }

  .recover__trade {
    display: block;
    margin-top: 0.35rem;
    font-size: 0.85rem;
  }

  .recover__panel {
    flex: 1;
    align-items: flex-start;
    padding: 4.5rem 1rem 1.75rem;
  }

  .recover__card {
    width: 100%;
    padding: 1.35rem 1.1rem 1.15rem;
  }

  .recover__card h2 {
    font-size: 1.55rem;
  }

  .recover__tools {
    top: 1rem;
    right: 1rem;
  }
}
</style>
