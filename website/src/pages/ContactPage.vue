<script setup lang="ts">
import { computed, inject, type Ref } from 'vue'
import { resolveCtaUrl, type TenantBranding } from '../branding'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))
</script>

<template>
  <div class="page wrap" v-if="branding">
    <header class="page-head">
      <p class="eyebrow">Contact</p>
      <h1>Support {{ branding.brand_name }}</h1>
      <p>Coordonnées de l’enseigne et accès direct au back-office.</p>
    </header>

    <div class="contact-grid">
      <div>
        <dl v-if="branding.support_email || branding.support_phone">
          <div v-if="branding.support_email">
            <dt>Email</dt>
            <dd>
              <a :href="`mailto:${branding.support_email}`">{{ branding.support_email }}</a>
            </dd>
          </div>
          <div v-if="branding.support_phone">
            <dt>Téléphone</dt>
            <dd>
              <a :href="`tel:${branding.support_phone}`">{{ branding.support_phone }}</a>
            </dd>
          </div>
        </dl>
        <div v-else class="feature-tile">
          <h3>Coordonnées à renseigner</h3>
          <p class="muted">Renseignez email et téléphone dans Organisation → Marque du back-office.</p>
        </div>
      </div>

      <aside class="contact-side">
        <h3>Back-office</h3>
        <p>Connectez-vous au tenant <span class="mono">{{ branding.slug }}</span></p>
        <a class="btn btn-accent" :href="ctaHref">Espace admin</a>
      </aside>
    </div>
  </div>
</template>
