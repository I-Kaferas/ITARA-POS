<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../layout/AdminLayout.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  { to: '/admin/sales', label: t('sales.tabs.list') },
  { to: '/admin/sales/returns', label: t('sales.tabs.returns') },
])

function isActive(path: string) {
  if (path === '/admin/sales') {
    return route.path === '/admin/sales' || (route.path.startsWith('/admin/sales/') && !route.path.includes('/returns'))
  }
  if (path === '/admin/sales/returns') {
    return route.path === '/admin/sales/returns'
  }
  return route.path === path || route.path.startsWith(path + '/')
}

const navTabs = computed(() => tabs.value.map(tab => ({ ...tab, active: isActive(tab.to) })))
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.sales') }}</template>
    <template #subtitle>{{ t('sales.subtitle') }}</template>

    <SubNav :tabs="navTabs" />
    <slot />
  </AdminLayout>
</template>
