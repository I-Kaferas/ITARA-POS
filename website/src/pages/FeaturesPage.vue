<script setup lang="ts">
import { computed, inject, type Ref } from 'vue'
import { resolveCtaUrl, type TenantBranding } from '../branding'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))
</script>

<template>
  <div class="page wrap" v-if="branding">
    <header class="page-head">
      <p class="eyebrow">Fonctionnalités</p>
      <h1>Couverture</h1>
      <p>Modules alignés sur le back-office {{ branding.brand_name }}.</p>
    </header>

    <ul class="list">
      <li>
        <span class="list__label">Point de vente</span>
        <p>Panier, paiements mixtes, tickets, impression.</p>
      </li>
      <li>
        <span class="list__label">Catalogue</span>
        <p>Produits, variantes, taxes, images, listes de prix.</p>
      </li>
      <li>
        <span class="list__label">Stocks</span>
        <p>Mouvements, transferts, inventaires, sync.</p>
      </li>
      <li>
        <span class="list__label">Organisation</span>
        <p>Entreprises, magasins, rôles, caisses.</p>
      </li>
      <li>
        <span class="list__label">Pilotage</span>
        <p>Rapports, dépenses, achats, marque.</p>
      </li>
    </ul>

    <div class="actions">
      <a class="btn btn-primary" :href="ctaHref">Espace admin</a>
    </div>
  </div>
</template>
