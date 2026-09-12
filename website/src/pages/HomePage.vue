<script setup lang="ts">
import { computed, inject, type ComputedRef, type Ref } from 'vue'
import { RouterLink } from 'vue-router'
import PosPreview from '../components/PosPreview.vue'
import { resolveCtaUrl, type TenantBranding } from '../branding'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const productPath = inject<ComputedRef<string>>('productPath')!

const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))

const headline = computed(() => {
  const b = branding.value
  if (!b) return ''
  const title = b.marketing.hero_title.trim()
  if (title && title.toLowerCase() !== b.brand_name.trim().toLowerCase()) return title
  return b.tagline
})

const lede = computed(() => branding.value?.marketing.hero_subtitle ?? '')
</script>

<template>
  <template v-if="branding">
    <section class="hero">
      <div class="hero__panel">
        <p class="hero__brand">{{ branding.brand_name }}</p>
        <div class="hero__copy">
          <h1>{{ headline }}</h1>
          <p>{{ lede }}</p>
        </div>
        <div class="hero__actions">
          <a class="btn btn-light" :href="ctaHref">Espace admin</a>
          <RouterLink class="btn btn-ghost" :to="productPath">Produit</RouterLink>
        </div>
      </div>
      <div class="hero__stage">
        <PosPreview :title="branding.brand_name" />
      </div>
    </section>

    <section class="section wrap">
      <h2>Capacités</h2>
      <p class="lede">
        {{ branding.brand_name }} relie le terminal de vente à l’administration du magasin.
      </p>
      <ul class="list">
        <li>
          <span class="list__label">Encaissement</span>
          <p>Panier, paiements, tickets et commandes en attente.</p>
        </li>
        <li>
          <span class="list__label">Catalogue & stock</span>
          <p>Produits, variantes, mouvements et alertes par magasin.</p>
        </li>
        <li>
          <span class="list__label">Pilotage</span>
          <p>Back-office web et terminal local — même tenant.</p>
        </li>
      </ul>
    </section>

    <div class="wrap">
      <div class="cta-bar">
        <div>
          <h2>Espace {{ branding.brand_name }}</h2>
          <p>Back-office · tenant <span class="mono">{{ branding.slug }}</span></p>
        </div>
        <a class="btn btn-light" :href="ctaHref">Espace admin</a>
      </div>
    </div>
  </template>
</template>
