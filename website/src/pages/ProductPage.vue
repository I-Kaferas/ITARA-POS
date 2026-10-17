<script setup lang="ts">
import { computed, inject, type ComputedRef, type Ref } from 'vue'
import { RouterLink } from 'vue-router'
import { resolveCtaUrl, type TenantBranding } from '../branding'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const featuresPath = inject<ComputedRef<string>>('featuresPath')!
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))

const modules = [
  { label: 'Point de vente', text: 'Encaissement, panier, paiements, commandes en attente.' },
  { label: 'Catalogue', text: 'Produits, variantes, taxes, codes-barres.' },
  { label: 'Stocks', text: 'Mouvements, transferts, inventaires, alertes.' },
  { label: 'Organisation', text: 'Magasins, rôles, caisses, appareils.' },
  { label: 'Pilotage', text: 'Rapports, achats, dépenses, marque marketing.' },
]
</script>

<template>
  <div class="page wrap" v-if="branding">
    <header class="page-head">
      <p class="eyebrow">Produit</p>
      <h1>{{ branding.brand_name }}</h1>
      <p>Terminal de caisse et administration web, isolés par enseigne — même langage que le back-office.</p>
    </header>

    <div class="split">
      <article>
        <h3>Terminal</h3>
        <p>Flutter (Windows / Android) — encaissement local, sync Master/Slave, thème de marque.</p>
      </article>
      <article>
        <h3>Back-office</h3>
        <p>Admin Vue — catalogue, stocks, organisation, rapports et paramétrage enseigne.</p>
      </article>
    </div>

    <div class="section-head" style="margin-bottom: 1rem">
      <p class="eyebrow">Modules</p>
      <h2>Couverture métier</h2>
    </div>

    <div class="feature-grid" style="margin-bottom: 0.5rem">
      <article v-for="item in modules" :key="item.label" class="feature-tile">
        <div class="feature-tile__icon" aria-hidden="true">•</div>
        <h3>{{ item.label }}</h3>
        <p>{{ item.text }}</p>
      </article>
    </div>

    <div class="actions">
      <a class="btn btn-primary" :href="ctaHref">Espace admin</a>
      <RouterLink class="btn btn-outline" :to="featuresPath">Fonctionnalités</RouterLink>
    </div>
  </div>
</template>
