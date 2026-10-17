<script setup lang="ts">
import { computed, inject, type Ref } from 'vue'
import { resolveCtaUrl, type TenantBranding } from '../branding'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))

const features = [
  {
    icon: '1',
    title: 'Point de vente',
    text: 'Panier, paiements mixtes, tickets thermiques, mise en attente et reprise.',
  },
  {
    icon: '2',
    title: 'Catalogue',
    text: 'Produits, variantes, taxes, images et listes de prix par magasin.',
  },
  {
    icon: '3',
    title: 'Stocks',
    text: 'Mouvements, transferts, inventaires et synchronisation Master ↔ cloud.',
  },
  {
    icon: '4',
    title: 'Organisation',
    text: 'Entreprises, magasins, rôles, caisses et appareils appairés.',
  },
  {
    icon: '5',
    title: 'Pilotage',
    text: 'Rapports, dépenses, achats et identité marketing de l’enseigne.',
  },
  {
    icon: '6',
    title: 'Sécurité caisse',
    text: 'Verrouillage PIN, rôles caissier et session isolée par terminal.',
  },
]
</script>

<template>
  <div class="page wrap" v-if="branding">
    <header class="page-head">
      <p class="eyebrow">Fonctionnalités</p>
      <h1>Tout ce que pilote le back-office</h1>
      <p>Modules alignés sur l’admin {{ branding.brand_name }} — de la caisse au siège.</p>
    </header>

    <div class="feature-grid">
      <article v-for="item in features" :key="item.title" class="feature-tile">
        <div class="feature-tile__icon" aria-hidden="true">{{ item.icon }}</div>
        <h3>{{ item.title }}</h3>
        <p>{{ item.text }}</p>
      </article>
    </div>

    <div class="actions">
      <a class="btn btn-primary" :href="ctaHref">Espace admin</a>
    </div>
  </div>
</template>
