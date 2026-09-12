<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../layout/AdminLayout.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  { to: '/admin/reports/sales', label: t('reports.tabs.sales') },
  { to: '/admin/reports/inventory', label: t('reports.tabs.inventory') },
  { to: '/admin/reports/financial', label: t('reports.tabs.financial') },
])

function isActive(path: string) {
  return route.path === path || route.path.startsWith(path + '/')
}

const navTabs = computed(() => tabs.value.map(tab => ({ ...tab, active: isActive(tab.to) })))
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.reports') }}</template>
    <template #subtitle>{{ t('reports.subtitle') }}</template>
    <SubNav :tabs="navTabs" />
    <slot />
  </AdminLayout>
</template>
