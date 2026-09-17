<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../layout/PageFrame.vue'

const { t } = useI18n()
const route = useRoute()

const pageTitle = computed(() => {
  if (route.path.includes('/returns')) return t('sales.tabs.returns')
  return t('nav.sales')
})
</script>

<template>
  <PageFrame>
    <template #title>{{ pageTitle }}</template>
    <template #subtitle>{{ t('sales.subtitle') }}</template>
    <slot />
  </PageFrame>
</template>
