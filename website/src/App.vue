<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, provide, ref, watch } from 'vue'
import { RouterView, useRoute } from 'vue-router'
import {
  applyBranding,
  DEFAULT_SLUG,
  fetchPublicBranding,
  PRODUCT_LOGO_URL,
  PRODUCT_NAME,
  resolveAdminLoginUrl,
  resolveAdminRegisterUrl,
  resolveCtaUrl,
  type TenantBranding,
} from './branding'
import SupportBot from './components/SupportBot.vue'
import ModuleIcon from './components/ModuleIcon.vue'
import { useI18n, type Locale } from './i18n'
import { initReveal } from './reveal'

const route = useRoute()
const branding = ref<TenantBranding | null>(null)
const error = ref<string | null>(null)
const loading = ref(true)
const menuOpen = ref(false)
const botOpen = ref(false)
const activeSection = ref('branding')
const { locale, setLocale, t, locales } = useI18n()

const slug = computed(() => {
  const param = route.params.slug
  if (typeof param === 'string' && param.trim()) return param.trim()
  return DEFAULT_SLUG
})

const homePath = computed(() => (slug.value === DEFAULT_SLUG ? '/' : `/${slug.value}`))

const navItems = computed(() => {
  void locale.value
  return [
    { href: '#branding', label: t('nav.home'), key: 'branding' },
    { href: '#suite', label: t('nav.suite'), key: 'suite' },
    { href: '#modules', label: t('nav.modules'), key: 'modules' },
    { href: '#why', label: t('nav.why'), key: 'why' },
    { href: '#pricing', label: t('nav.pricing'), key: 'pricing' },
    { href: '#apps', label: t('nav.apps'), key: 'apps' },
    { href: '#contact', label: t('nav.contact'), key: 'contact' },
  ]
})

const ctaHref = computed(() => {
  void locale.value
  return branding.value ? resolveCtaUrl(branding.value) : '#'
})
const loginHref = computed(() => {
  void locale.value
  return branding.value ? resolveAdminLoginUrl(branding.value.slug) : resolveAdminLoginUrl(slug.value)
})
const registerHref = computed(() => {
  void locale.value
  return branding.value ? resolveAdminRegisterUrl(branding.value.slug) : resolveAdminRegisterUrl(slug.value)
})
const productName = computed(() => branding.value?.brand_name ?? PRODUCT_NAME)
/** Vitrine always shows the ITARA product mark (tenant logo is for admin / login). */
const logoSrc = computed(() => PRODUCT_LOGO_URL)
const logoFailed = ref(false)
const year = new Date().getFullYear()

const botContext = computed(() => ({
  product: productName.value,
  email: branding.value?.support_email,
  phone: branding.value?.support_phone,
}))

function openSupportBot() {
  botOpen.value = true
}

function onBotHandoff() {
  botOpen.value = false
  requestAnimationFrame(() => scrollToHash('#contact'))
}

watch(logoSrc, () => { logoFailed.value = false })
const localeLabels: Record<Locale, string> = { fr: 'FR', en: 'EN', sw: 'SW' }
const localeNames: Record<Locale, string> = {
  fr: 'Français',
  en: 'English',
  sw: 'Kiswahili',
}
let stopReveal: (() => void) | undefined
const BOOT_MIN_MS = 3000

async function load() {
  loading.value = true
  error.value = null
  const started = performance.now()
  try {
    const data = await fetchPublicBranding(slug.value)
    branding.value = data
    applyBranding(data)
  } catch (e) {
    branding.value = null
    error.value = e instanceof Error ? e.message : 'Erreur'
  } finally {
    const hold = BOOT_MIN_MS - (performance.now() - started)
    if (hold > 0) await new Promise((resolve) => window.setTimeout(resolve, hold))
    loading.value = false
    requestAnimationFrame(() => {
      stopReveal?.()
      stopReveal = initReveal(document)
    })
  }
}

function scrollToHash(href: string) {
  menuOpen.value = false
  const id = href.replace('#', '')
  const el = document.getElementById(id)
  if (!el) return
  el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  activeSection.value = id
  history.replaceState(null, '', href)
}

function onScroll() {
  const sections = navItems.value.map((item) => item.key)
  let current = sections[0]
  for (const id of sections) {
    const el = document.getElementById(id)
    if (!el) continue
    if (el.getBoundingClientRect().top <= 120) current = id
  }
  activeSection.value = current
}

watch(slug, () => { void load() }, { immediate: true })

provide('branding', branding)
provide('homePath', homePath)
provide('openSupportBot', openSupportBot)

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    menuOpen.value = false
    botOpen.value = false
  }
}

onMounted(() => {
  document.title = PRODUCT_NAME
  window.addEventListener('keydown', onKey)
  window.addEventListener('scroll', onScroll, { passive: true })
  if (location.hash) {
    requestAnimationFrame(() => scrollToHash(location.hash))
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKey)
  window.removeEventListener('scroll', onScroll)
  stopReveal?.()
})
</script>

<template>
  <div
    v-if="loading"
    class="boot"
    role="status"
    aria-live="polite"
    :aria-label="String(t('state', 'loading'))"
  >
    <div class="boot__mark" aria-hidden="true">
      <span class="boot__orbit" />
      <img
        v-if="!logoFailed"
        class="boot__logo"
        :src="logoSrc"
        alt=""
        width="72"
        height="72"
        @error="logoFailed = true"
      />
      <span v-else class="boot__fallback">{{ productName.trim()[0]?.toUpperCase() || 'I' }}</span>
    </div>
    <p class="boot__name">{{ productName }}</p>
    <p class="boot__status">{{ t('state', 'loading') }}</p>
    <div class="boot__track" aria-hidden="true"><span /></div>
  </div>
  <div v-else class="shell">
    <header class="topbar">
      <a class="brand-lockup" href="#branding" @click.prevent="scrollToHash('#branding')">
        <img
          v-if="!logoFailed"
          class="brand-lockup__logo"
          :src="logoSrc"
          :alt="productName"
          width="48"
          height="48"
          @error="logoFailed = true"
        />
        <span v-else class="brand-mark">{{ productName.trim()[0]?.toUpperCase() || 'I' }}</span>
        <span class="brand-lockup__name">{{ productName }}</span>
      </a>

      <nav v-if="branding" class="nav" aria-label="Navigation">
        <a
          v-for="item in navItems"
          :key="item.key"
          :href="item.href"
          :class="{ 'is-active': activeSection === item.key }"
          @click.prevent="scrollToHash(item.href)"
        >
          {{ item.label }}
        </a>
      </nav>

      <div class="topbar__actions">
        <div class="chrome-tools">
          <div
            class="lang-switch"
            role="group"
            :aria-label="String(t('actions', 'language'))"
          >
            <span class="lang-switch__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <circle cx="12" cy="12" r="9" />
                <path d="M3 12h18" />
                <path d="M12 3a14 14 0 0 1 0 18" />
                <path d="M12 3a14 14 0 0 0 0 18" />
              </svg>
            </span>
            <button
              v-for="code in locales"
              :key="code"
              type="button"
              class="lang-switch__btn"
              :class="{ 'is-active': locale === code }"
              :aria-pressed="locale === code"
              :title="localeNames[code]"
              @click="setLocale(code)"
            >
              {{ localeLabels[code] }}
            </button>
          </div>
        </div>
        <a v-if="branding" class="btn btn-ghost topbar__auth" :href="loginHref">{{ t('actions', 'login') }}</a>
        <a v-if="branding" class="btn btn-light topbar__auth" :href="registerHref">{{ t('actions', 'register') }}</a>
        <a v-if="branding" class="btn btn-primary topbar__cta" :href="ctaHref">{{ t('actions', 'getStarted') }}</a>
        <button
          v-if="branding"
          type="button"
          class="nav-toggle"
          :aria-expanded="menuOpen"
          aria-label="Menu"
          @click="menuOpen = !menuOpen"
        >
          <span /><span /><span />
        </button>
      </div>
    </header>

    <div v-if="branding && menuOpen" class="mobile-nav">
      <a
        v-for="item in navItems"
        :key="item.key"
        :href="item.href"
        :class="{ 'is-active': activeSection === item.key }"
        @click.prevent="scrollToHash(item.href)"
      >
        {{ item.label }}
      </a>
      <div class="mobile-nav__tools">
        <div
          class="lang-switch lang-switch--mobile"
          role="group"
          :aria-label="String(t('actions', 'language'))"
        >
          <span class="lang-switch__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
              <circle cx="12" cy="12" r="9" />
              <path d="M3 12h18" />
              <path d="M12 3a14 14 0 0 1 0 18" />
              <path d="M12 3a14 14 0 0 0 0 18" />
            </svg>
          </span>
          <button
            v-for="code in locales"
            :key="code"
            type="button"
            class="lang-switch__btn"
            :class="{ 'is-active': locale === code }"
            :aria-pressed="locale === code"
            :title="localeNames[code]"
            @click="setLocale(code)"
          >
            <strong>{{ localeLabels[code] }}</strong>
            <span>{{ localeNames[code] }}</span>
          </button>
        </div>
      </div>
      <a class="btn btn-ghost" :href="loginHref">{{ t('actions', 'login') }}</a>
      <a class="btn btn-light" :href="registerHref">{{ t('actions', 'register') }}</a>
      <a class="btn btn-primary" :href="ctaHref">{{ t('actions', 'getStarted') }}</a>
    </div>

    <main class="main">
      <div v-if="error" class="state">
        <h2>{{ t('state', 'notFound') }}</h2>
        <p>{{ error }}</p>
      </div>
      <RouterView v-else />
    </main>

    <footer v-if="branding && !error" class="footer">
      <div class="footer__grid">
        <div>
          <div class="footer__brand">
            <img
              v-if="!logoFailed"
              class="footer__logo"
              :src="logoSrc"
              :alt="productName"
              width="48"
              height="48"
              @error="logoFailed = true"
            />
            <span>{{ productName }}</span>
          </div>
          <p class="footer__blurb">
            {{ t('footer.blurb') }}
          </p>
        </div>
        <div class="footer__col">
          <h4>{{ t('footer', 'quickLinks') }}</h4>
          <a href="#suite" @click.prevent="scrollToHash('#suite')">{{ t('nav', 'suite') }}</a>
          <a href="#modules" @click.prevent="scrollToHash('#modules')">{{ t('nav', 'modules') }}</a>
          <a href="#pricing" @click.prevent="scrollToHash('#pricing')">{{ t('nav', 'pricing') }}</a>
          <a href="#apps" @click.prevent="scrollToHash('#apps')">{{ t('nav', 'apps') }}</a>
          <a href="#contact" @click.prevent="scrollToHash('#contact')">{{ t('nav', 'contact') }}</a>
        </div>
        <div class="footer__col">
          <h4>{{ t('footer', 'contact') }}</h4>
          <a v-if="branding.support_email" :href="`mailto:${branding.support_email}`">{{ branding.support_email }}</a>
          <a v-if="branding.support_phone" :href="`tel:${branding.support_phone}`">{{ branding.support_phone }}</a>
          <a :href="loginHref">{{ t('actions', 'login') }}</a>
          <a :href="registerHref">{{ t('actions', 'register') }}</a>
          <a :href="ctaHref">{{ t('footer', 'admin') }}</a>
          <span class="mono" style="opacity: 0.55">{{ branding.slug }}</span>
        </div>
      </div>
      <div class="footer__copy">© {{ year }} {{ productName }}. {{ t('footer', 'rights') }}</div>
    </footer>

    <button
      v-if="branding && !error"
      type="button"
      class="bot-fab"
      :aria-label="t('bot.open')"
      :title="t('bot.open')"
      @click="openSupportBot"
    >
      <ModuleIcon name="SUP" />
      <span>{{ t('contact.response') }}</span>
    </button>

    <SupportBot
      v-model:open="botOpen"
      :context="botContext"
      @handoff="onBotHandoff"
    />
  </div>
</template>
