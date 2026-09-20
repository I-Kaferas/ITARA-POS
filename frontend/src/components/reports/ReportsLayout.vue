<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../layout/PageFrame.vue'

const { t } = useI18n()
const route = useRoute()

const pageTitle = computed(() => {
  if (route.path.startsWith('/admin/reports/dashboard')) return t('reports.tabs.dashboard')
  if (route.path.startsWith('/admin/reports/store-stock')) return t('reports.tabs.storeStock')
  if (route.path.startsWith('/admin/reports/inventory')) return t('reports.tabs.inventory')
  if (route.path.startsWith('/admin/reports/purchases')) return t('reports.explore.purchases.title')
  if (route.path.startsWith('/admin/reports/forecasts')) return t('reports.explore.forecasts.title')
  if (route.path.startsWith('/admin/reports/financial')) return t('reports.explore.financial.title')
  if (route.path.startsWith('/admin/reports/revenue')) return t('reports.explore.revenue.title')
  if (route.path.startsWith('/admin/reports/condensed')) return t('reports.tabs.condensed')
  if (route.path.startsWith('/admin/reports/daily')) return t('reports.tabs.daily')
  if (route.path.startsWith('/admin/reports/user-performance')) return t('reports.userPerformanceAnalytics.title')
  if (route.path.startsWith('/admin/reports/sales')) return t('reports.explore.sales.title')
  return t('nav.reports')
})

const pageSubtitle = computed(() => {
  if (route.path.startsWith('/admin/reports/dashboard')) return t('reports.analytics.subtitle')
  if (route.path.startsWith('/admin/reports/sales')) return t('reports.salesAnalytics.subtitle')
  if (route.path.startsWith('/admin/reports/store-stock')) return t('reports.storeStock.subtitle')
  if (route.path.startsWith('/admin/reports/inventory')) return t('reports.inventoryAnalytics.subtitle')
  if (route.path.startsWith('/admin/reports/purchases')) return t('reports.purchaseAnalytics.subtitle')
  if (route.path.startsWith('/admin/reports/forecasts')) return t('reports.forecastAnalytics.subtitle')
  if (route.path.startsWith('/admin/reports/revenue')) return t('reports.explore.revenue.desc')
  if (route.path.startsWith('/admin/reports/condensed')) return t('reports.explore.condensed.desc')
  if (route.path.startsWith('/admin/reports/daily')) return t('reports.dailyAnalytics.calendarHint')
  if (route.path.startsWith('/admin/reports/user-performance')) return t('reports.userPerformanceAnalytics.subtitle')
  return t('reports.subtitle')
})
</script>

<template>
  <PageFrame>
    <template #title>{{ pageTitle }}</template>
    <template #subtitle>{{ pageSubtitle }}</template>
    <slot />
  </PageFrame>
</template>
