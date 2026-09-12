<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../layout/AdminLayout.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const tabs = computed(() => [
  { to: '/admin/catalog/catalogs', label: t('catalog.tabs.catalogs') },
  { to: '/admin/catalog/categories', label: t('catalog.tabs.categories') },
  { to: '/admin/catalog/brands', label: t('catalog.tabs.brands') },
  { to: '/admin/catalog/units', label: t('catalog.tabs.units') },
  { to: '/admin/catalog/taxes', label: t('catalog.tabs.taxes') },
  { to: '/admin/products', label: t('nav.products') },
  { to: '/admin/catalog/options', label: t('nav.productOptions') },
])

function isActive(path: string) {
  if (path === '/admin/products') return route.path.startsWith('/admin/products')
  return route.path === path || route.path.startsWith(path + '/')
}

const navTabs = computed(() => tabs.value.map(tab => ({ ...tab, active: isActive(tab.to) })))

const pageTitle = computed(() => {
  if (route.path.startsWith('/admin/catalog/brands')) return t('nav.brands')
  if (route.path.startsWith('/admin/catalog/units')) return t('nav.units')
  if (route.path.startsWith('/admin/catalog/categories')) return t('catalog.tabs.categories')
  if (route.path.startsWith('/admin/catalog/catalogs')) return t('catalog.tabs.catalogs')
  if (route.path.startsWith('/admin/catalog/taxes')) return t('catalog.tabs.taxes')
  if (route.path.startsWith('/admin/catalog/options')) return t('nav.productOptions')
  return t('nav.catalog')
})
</script>

<template>
  <AdminLayout>
    <template #title>{{ pageTitle }}</template>
    <template #subtitle>{{ t('catalog.subtitle') }}</template>

    <SubNav :tabs="navTabs" />
    <slot />
  </AdminLayout>
</template>
