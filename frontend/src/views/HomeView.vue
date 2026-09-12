<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import LanguageSwitcher from '../components/ui/LanguageSwitcher.vue'
import { useAppStore } from '../stores/app'

const { t } = useI18n()
const appStore = useAppStore()

onMounted(() => {
  appStore.checkApiHealth()
})
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <header class="bg-white shadow">
      <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-3xl font-bold tracking-tight text-gray-900">
            {{ t('app.name') }}
          </h1>
          <LanguageSwitcher />
        </div>
      </div>
    </header>

    <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <div class="rounded-lg bg-white p-6 shadow">
        <p class="mb-6 text-lg text-gray-600">
          {{ t('app.welcome') }}
        </p>

        <div class="border-t pt-6">
          <h2 class="mb-4 text-xl font-semibold text-gray-800">
            {{ t('health.apiStatus') }}
          </h2>

          <div v-if="appStore.loading" class="text-gray-500">
            {{ t('health.checking') }}
          </div>

          <div v-else-if="appStore.apiHealth" class="rounded-md bg-green-50 p-4">
            <p class="font-medium text-green-800">
              Status: {{ appStore.apiHealth.status }}
            </p>
            <p class="text-sm text-green-700">
              Service: {{ appStore.apiHealth.service }} v{{ appStore.apiHealth.version }}
            </p>
          </div>

          <div v-else class="rounded-md bg-red-50 p-4">
            <p class="font-medium text-red-800">
              API unreachable
            </p>
            <p v-if="appStore.apiError" class="text-sm text-red-700">
              {{ appStore.apiError }}
            </p>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>
