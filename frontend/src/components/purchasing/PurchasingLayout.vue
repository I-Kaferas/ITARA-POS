<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../layout/AdminLayout.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  {
    to: '/admin/purchases/orders',
    label: `${t('purchases.tabs.orders')}`,
  },
  {
    to: '/admin/purchases/invoices',
    label: `${t('purchases.tabs.invoices')}`,
  },
  {
    to: '/admin/purchases/payments',
    label: `${t('purchases.workflow.payment')}`,
  },
])

function isActive(path: string) {
  return route.path === path || route.path.startsWith(path + '/')
}

const navTabs = computed(() => tabs.value.map(tab => ({ ...tab, active: isActive(tab.to) })))
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.purchases') }}</template>
    <template #subtitle>{{ t('purchases.subtitle') }}</template>

    <SubNav :tabs="navTabs" />
    <slot />
  </AdminLayout>
</template>
