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
      <h1>Support</h1>
      <p>Coordonnées {{ branding.brand_name }} et accès back-office.</p>
    </header>

    <div class="contact-grid">
      <div>
        <template v-if="branding.support_email || branding.support_phone">
          <dl>
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
        </template>
        <p v-else class="muted">Coordonnées non renseignées (Organisation → Marque).</p>
      </div>

      <aside class="contact-side">
        <h3>Back-office</h3>
        <p class="muted">Tenant <span class="mono">{{ branding.slug }}</span></p>
        <a class="btn btn-primary" :href="ctaHref">Espace admin</a>
      </aside>
    </div>
  </div>
</template>
