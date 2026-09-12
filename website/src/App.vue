<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, provide, ref, watch } from 'vue'
import { RouterLink, RouterView, useRoute } from 'vue-router'
import {
  applyBranding,
  DEFAULT_SLUG,
  fetchPublicBranding,
  resolveCtaUrl,
  type TenantBranding,
} from './branding'

const route = useRoute()
const branding = ref<TenantBranding | null>(null)
const error = ref<string | null>(null)
const loading = ref(true)
const menuOpen = ref(false)

const slug = computed(() => {
  const param = route.params.slug
  if (typeof param === 'string' && param.trim()) return param.trim()
  return DEFAULT_SLUG
})

const prefix = computed(() => (slug.value === DEFAULT_SLUG ? '' : `/${slug.value}`))
const homePath = computed(() => prefix.value || '/')
const productPath = computed(() => `${prefix.value}/product`)
const featuresPath = computed(() => `${prefix.value}/features`)
const contactPath = computed(() => `${prefix.value}/contact`)

const navItems = computed(() => [
  { to: homePath.value, label: 'Accueil', key: 'home' },
  { to: productPath.value, label: 'Produit', key: 'product' },
  { to: featuresPath.value, label: 'Fonctionnalités', key: 'features' },
  { to: contactPath.value, label: 'Contact', key: 'contact' },
])

const activeNav = computed(() => String(route.meta.nav ?? ''))
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))
const initial = computed(() => (branding.value?.brand_name?.trim()?.[0] ?? 'P').toUpperCase())
const year = new Date().getFullYear()

async function load() {
  loading.value = true
  error.value = null
  try {
    const data = await fetchPublicBranding(slug.value)
    branding.value = data
    applyBranding(data)
  } catch (e) {
    branding.value = null
    error.value = e instanceof Error ? e.message : 'Erreur'
  } finally {
    loading.value = false
  }
}

watch(slug, () => { void load() }, { immediate: true })
watch(() => route.fullPath, () => { menuOpen.value = false })

provide('branding', branding)
provide('homePath', homePath)
provide('productPath', productPath)
provide('featuresPath', featuresPath)
provide('contactPath', contactPath)

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') menuOpen.value = false
}

onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <div class="shell">
    <header class="topbar">
      <RouterLink class="brand-lockup" :to="homePath">
        <img v-if="branding?.logo_url" :src="branding.logo_url" alt="" width="28" height="28" />
        <span v-else class="brand-mark">{{ initial }}</span>
        <span class="brand-lockup__name">{{ branding?.brand_name ?? 'POS' }}</span>
      </RouterLink>

      <nav v-if="branding" class="nav" aria-label="Navigation">
        <RouterLink
          v-for="item in navItems"
          :key="item.key"
          :to="item.to"
          :class="{ 'is-active': activeNav === item.key }"
        >
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="topbar__actions">
        <a v-if="branding" class="btn btn-primary topbar__cta" :href="ctaHref">Espace admin</a>
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
      <RouterLink
        v-for="item in navItems"
        :key="item.key"
        :to="item.to"
        :class="{ 'is-active': activeNav === item.key }"
      >
        {{ item.label }}
      </RouterLink>
      <a class="btn btn-primary" :href="ctaHref">Espace admin</a>
    </div>

    <main class="main">
      <div v-if="loading" class="state">Chargement…</div>
      <div v-else-if="error" class="state">
        <h2>Marque introuvable</h2>
        <p>{{ error }}</p>
      </div>
      <RouterView v-else />
    </main>

    <footer v-if="branding && !loading && !error" class="footer">
      <div class="footer__row">
        <span class="footer__brand">{{ branding.brand_name }}</span>
        <div class="footer__links">
          <RouterLink :to="productPath">Produit</RouterLink>
          <RouterLink :to="featuresPath">Fonctionnalités</RouterLink>
          <RouterLink :to="contactPath">Contact</RouterLink>
          <a :href="ctaHref">Espace admin</a>
        </div>
      </div>
      <div class="footer__copy">© {{ year }} {{ branding.brand_name }}</div>
    </footer>
  </div>
</template>
