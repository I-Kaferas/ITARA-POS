<script setup lang="ts">
import { computed, inject, type ComputedRef, type Ref } from 'vue'
import { RouterLink } from 'vue-router'
import { resolveCtaUrl, type TenantBranding } from '../branding'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const featuresPath = inject<ComputedRef<string>>('featuresPath')!
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))
</script>

<template>
  <div class="page wrap" v-if="branding">
    <header class="page-head">
      <p class="eyebrow">Produit</p>
      <h1>{{ branding.brand_name }}</h1>
      <p>Terminal de caisse + administration web, isolés par enseigne.</p>
    </header>

    <div class="split">
      <article>
        <h3>Terminal</h3>
        <p>Flutter (Windows / Android) — encaissement local, sync, thème de marque.</p>
      </article>
      <article>
        <h3>Back-office</h3>
        <p>Admin Vue — catalogue, stocks, organisation et rapports.</p>
      </article>
    </div>

    <ul class="list">
      <li>
        <span class="list__label">Point de vente</span>
        <p>Encaissement, panier, paiements, commandes en attente.</p>
      </li>
      <li>
        <span class="list__label">Catalogue</span>
        <p>Produits, variantes, taxes, codes-barres.</p>
      </li>
      <li>
        <span class="list__label">Stocks</span>
        <p>Mouvements, transferts, inventaires, alertes.</p>
      </li>
      <li>
        <span class="list__label">Organisation</span>
        <p>Magasins, rôles, caisses, appareils.</p>
      </li>
      <li>
        <span class="list__label">Pilotage</span>
        <p>Rapports, achats, dépenses, marque marketing.</p>
      </li>
    </ul>

    <div class="actions">
      <a class="btn btn-primary" :href="ctaHref">Espace admin</a>
      <RouterLink class="btn btn-ghost" :to="featuresPath">Fonctionnalités</RouterLink>
    </div>
  </div>
</template>
