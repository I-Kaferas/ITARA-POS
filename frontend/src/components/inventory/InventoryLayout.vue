<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../layout/AdminLayout.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  { to: '/admin/inventory/stock', label: t('inventory.tabs.stock') },
  { to: '/admin/inventory/supplies', label: t('inventory.tabs.supplies') },
  { to: '/admin/inventory/transfers', label: t('inventory.tabs.transfers') },
  { to: '/admin/inventory/adjustments', label: t('inventory.tabs.adjustments') },
  { to: '/admin/inventory/issues', label: t('inventory.tabs.issues') },
  { to: '/admin/inventory/counts', label: t('inventory.tabs.inventories') },
  { to: '/admin/inventory/verifications', label: t('inventory.tabs.verifications') },
  { to: '/admin/inventory/batches', label: t('inventory.tabs.batches') },
  { to: '/admin/inventory/serials', label: t('inventory.tabs.serials') },
  { to: '/admin/inventory/alerts', label: t('inventory.tabs.alerts') },
])

function isActive(path: string) {
  return route.path === path || route.path.startsWith(path + '/')
}

const navTabs = computed(() => tabs.value.map(tab => ({ ...tab, active: isActive(tab.to) })))
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.inventory') }}</template>
    <template #subtitle>{{ t('inventory.subtitle') }}</template>

    <SubNav :tabs="navTabs" />
    <slot />
  </AdminLayout>
</template>
