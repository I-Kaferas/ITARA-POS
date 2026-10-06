<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import { api, extractApiErrorMessage } from '../../api/client'
import LoadingBlock from '../../components/ui/LoadingBlock.vue'

interface PublicQr {
  id: string
  label: string
  type: string
  service: string
  company_name?: string | null
  table?: {
    name: string
    code?: string
    zone?: string | null
    status?: string
  } | null
  redirect_url?: string | null
}

const { t } = useI18n()
const route = useRoute()
const loading = ref(true)
const error = ref('')
const qr = ref<PublicQr | null>(null)

const id = computed(() => String(route.params.id || ''))

async function load() {
  loading.value = true
  error.value = ''
  qr.value = null
  try {
    const res = await api.get<{ data: PublicQr }>(`/public/merchant-qr/${id.value}`)
    qr.value = res.data
    if (res.data.redirect_url && (res.data.type === 'pdf_menu' || res.data.type === 'external_link')) {
      window.location.replace(res.data.redirect_url)
    }
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('merchantQrPage.public.missing'))
  } finally {
    loading.value = false
  }
}

watch(id, () => {
  void load()
})

onMounted(() => {
  void load()
})
</script>

<template>
  <main class="public-qr">
    <LoadingBlock v-if="loading" :label="t('common.loading')" />
    <section v-else-if="error || !qr" class="public-qr__card">
      <h1>{{ t('nav.settingsItems.merchantQr') }}</h1>
      <p>{{ error || t('merchantQrPage.public.missing') }}</p>
    </section>
    <section v-else-if="qr.service === 'mobile'" class="public-qr__card">
      <p class="public-qr__company">{{ qr.company_name }}</p>
      <h1>{{ qr.label }}</h1>
      <p>{{ t('merchantQrPage.public.appRequired') }}</p>
    </section>
    <section v-else class="public-qr__card">
      <p class="public-qr__company">{{ qr.company_name }}</p>
      <h1>{{ qr.table?.name || qr.label }}</h1>
      <p>{{ t('merchantQrPage.public.tableLead') }}</p>
      <p v-if="qr.table?.zone">{{ t('merchantQrPage.public.zone') }}: {{ qr.table.zone }}</p>
    </section>
  </main>
</template>

<style scoped>
.public-qr {
  min-height: 100dvh;
  display: grid;
  place-items: center;
  padding: var(--space-6);
  background: var(--color-canvas);
}

.public-qr__card {
  width: min(28rem, 100%);
  padding: var(--space-6);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  text-align: center;
}

.public-qr__company {
  margin: 0 0 var(--space-2);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

.public-qr__card h1 {
  margin: 0 0 var(--space-3);
  font-size: var(--text-xl);
}

.public-qr__card p {
  margin: 0;
  color: var(--color-text-secondary);
}
</style>
