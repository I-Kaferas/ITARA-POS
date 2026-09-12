<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import { useBrandingStore } from '../../../stores/branding'

const store = useBrandingStore()
const saving = ref(false)
const savedFlash = ref(false)
const localError = ref('')

const form = reactive({
  brand_name: '',
  tagline: '',
  logo_url: '',
  primary_color: '#3D5C73',
  accent_color: '#E39B2B',
  support_email: '',
  support_phone: '',
  hero_title: '',
  hero_subtitle: '',
  cta_label: '',
  cta_url: '',
})

function syncForm() {
  const b = store.branding
  if (!b) return
  form.brand_name = b.brand_name
  form.tagline = b.tagline
  form.logo_url = b.logo_url ?? ''
  form.primary_color = b.primary_color
  form.accent_color = b.accent_color
  form.support_email = b.support_email ?? ''
  form.support_phone = b.support_phone ?? ''
  form.hero_title = b.marketing.hero_title
  form.hero_subtitle = b.marketing.hero_subtitle
  form.cta_label = b.marketing.cta_label
  form.cta_url = b.marketing.cta_url
}

async function load() {
  localError.value = ''
  try {
    await store.loadCurrent()
    syncForm()
  } catch {
    localError.value = store.error ?? 'Impossible de charger la marque'
  }
}

async function save() {
  saving.value = true
  localError.value = ''
  savedFlash.value = false
  try {
    await store.save({
      brand_name: form.brand_name,
      tagline: form.tagline,
      logo_url: form.logo_url || null,
      primary_color: form.primary_color,
      accent_color: form.accent_color,
      support_email: form.support_email || null,
      support_phone: form.support_phone || null,
      marketing: {
        hero_title: form.hero_title,
        hero_subtitle: form.hero_subtitle,
        cta_label: form.cta_label,
        cta_url: form.cta_url,
      },
    })
    syncForm()
    savedFlash.value = true
    window.setTimeout(() => { savedFlash.value = false }, 2200)
  } catch {
    localError.value = store.error ?? 'Enregistrement impossible'
  } finally {
    saving.value = false
  }
}

onMounted(() => { void load() })
</script>

<template>
  <OrganizationLayout>
    <div class="card stack gap-4">
      <div>
        <h2 class="m-0 text-lg font-bold">Marque & site marketing</h2>
        <p class="m-0 mt-1 text-sm text-slate-500">
          Ces réglages alimentent le site public (<code>/{{ store.branding?.slug ?? 'slug' }}</code>),
          l’écran de connexion et le terminal.
        </p>
      </div>

      <p v-if="localError" class="m-0 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ localError }}</p>
      <p v-if="savedFlash" class="m-0 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">Enregistré</p>

      <div class="grid gap-3 md:grid-cols-2">
        <label class="stack gap-1 text-sm">
          <span>Nom de marque</span>
          <input v-model="form.brand_name" class="ui-input" />
        </label>
        <label class="stack gap-1 text-sm">
          <span>Accroche</span>
          <input v-model="form.tagline" class="ui-input" />
        </label>
        <label class="stack gap-1 text-sm md:col-span-2">
          <span>Logo URL</span>
          <input v-model="form.logo_url" class="ui-input" placeholder="https://…" />
        </label>
        <label class="stack gap-1 text-sm">
          <span>Couleur primaire</span>
          <input v-model="form.primary_color" type="color" class="ui-input h-10 p-1" />
        </label>
        <label class="stack gap-1 text-sm">
          <span>Couleur accent</span>
          <input v-model="form.accent_color" type="color" class="ui-input h-10 p-1" />
        </label>
        <label class="stack gap-1 text-sm">
          <span>Email support</span>
          <input v-model="form.support_email" class="ui-input" type="email" />
        </label>
        <label class="stack gap-1 text-sm">
          <span>Téléphone support</span>
          <input v-model="form.support_phone" class="ui-input" />
        </label>
      </div>

      <h3 class="m-0 text-base font-semibold">Marketing</h3>
      <div class="grid gap-3">
        <label class="stack gap-1 text-sm">
          <span>Titre hero</span>
          <input v-model="form.hero_title" class="ui-input" />
        </label>
        <label class="stack gap-1 text-sm">
          <span>Sous-titre hero</span>
          <textarea v-model="form.hero_subtitle" class="ui-input" rows="3" />
        </label>
        <div class="grid gap-3 md:grid-cols-2">
          <label class="stack gap-1 text-sm">
            <span>Libellé CTA</span>
            <input v-model="form.cta_label" class="ui-input" />
          </label>
          <label class="stack gap-1 text-sm">
            <span>URL CTA (optionnel)</span>
            <input v-model="form.cta_url" class="ui-input" placeholder="Laissez vide → login admin" />
          </label>
        </div>
      </div>

      <div>
        <button type="button" class="ui-btn ui-btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Enregistrement…' : 'Enregistrer la marque' }}
        </button>
      </div>
    </div>
  </OrganizationLayout>
</template>
