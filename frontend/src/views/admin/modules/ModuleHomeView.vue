<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { canonicalModule, type ModuleManifest } from '../../../modules/registry'

const { t } = useI18n()
const route = useRoute()
const loading = ref(true)
const error = ref('')
const module = ref<ModuleManifest | null>(null)

const code = computed(() => canonicalModule(String(route.params.code ?? '')))

async function load() {
  loading.value = true
  error.value = ''
  module.value = null
  try {
    const response = await api.get<{ data: ModuleManifest[] }>('/modules')
    module.value = response.data.find(item => item.code === code.value) ?? null
  } catch (cause) {
    error.value = extractApiErrorMessage(cause)
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t(`modules.names.${code}`) }}</template>
    <template #subtitle>{{ t(`modules.descriptions.${code}`) }}</template>

    <p v-if="loading">{{ t('common.loading') }}</p>
    <p v-else-if="error">{{ error }}</p>
    <article v-else-if="module" class="ui-card module-home">
      <span class="module-home__icon" aria-hidden="true">
        <AppIcon :name="module.icon" :size="22" />
      </span>
      <div>
        <h2>{{ t(`modules.widgets.${code}`) }}</h2>
        <p>{{ t('modules.homeHint') }}</p>
        <RouterLink class="btn-primary" to="/admin/settings/modules">{{ t('modules.settings') }}</RouterLink>
      </div>
    </article>
    <p v-else>{{ t('modules.unavailable') }}</p>
  </PageFrame>
</template>

<style scoped>
.module-home {
  display: flex;
  gap: 1rem;
  align-items: flex-start;
  padding: 1.25rem;
}
.module-home__icon {
  display: grid;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  border-radius: 0.8rem;
  background: var(--color-surface-muted, rgba(0, 0, 0, 0.04));
  flex: none;
}
.module-home h2 {
  margin: 0 0 0.35rem;
}
.module-home p {
  margin: 0 0 1rem;
  color: var(--color-text-muted);
}
</style>
