<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../layout/AdminLayout.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  { to: '/admin/organization/company', label: t('org.tabs.company') },
  { to: '/admin/organization/branding', label: t('org.tabs.branding') },
  { to: '/admin/organization/currencies', label: t('org.tabs.currencies') },
  { to: '/admin/organization/payment-methods', label: t('org.tabs.paymentMethods') },
  { to: '/admin/organization/branches', label: t('org.tabs.branches') },
  { to: '/admin/organization/stores', label: t('org.tabs.stores') },
  { to: '/admin/organization/warehouses', label: t('org.tabs.warehouses') },
  { to: '/admin/organization/terminals', label: t('org.tabs.terminals') },
  { to: '/admin/organization/devices', label: t('org.tabs.devices') },
  { to: '/admin/organization/registers', label: t('org.tabs.registers') },
  { to: '/admin/organization/users', label: t('org.tabs.users') },
  { to: '/admin/organization/roles', label: t('org.tabs.roles') },
  { to: '/admin/organization/permissions', label: t('org.tabs.permissions') },
])

function isActive(path: string) {
  return route.path === path || route.path.startsWith(path + '/')
}

const navTabs = computed(() => tabs.value.map(tab => ({ ...tab, active: isActive(tab.to) })))
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.organization') }}</template>
    <template #subtitle>{{ t('org.subtitle') }}</template>

    <SubNav :tabs="navTabs" />
    <slot />
  </AdminLayout>
</template>
