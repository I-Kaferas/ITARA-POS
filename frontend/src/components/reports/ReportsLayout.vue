<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../layout/PageFrame.vue'

const { t } = useI18n()
const route = useRoute()

const pageTitle = computed(() => {
  if (route.path.startsWith('/admin/reports/inventory')) return t('reports.tabs.inventory')
  if (route.path.startsWith('/admin/reports/financial')) return t('reports.tabs.financial')
  return t('reports.tabs.sales')
})
</script>

<template>
  <PageFrame>
    <template #title>{{ pageTitle }}</template>
    <template #subtitle>{{ t('reports.subtitle') }}</template>
    <slot />
  </PageFrame>
</template>
