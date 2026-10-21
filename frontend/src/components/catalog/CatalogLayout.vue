<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../layout/PageFrame.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

const productArea = computed(() => route.path.startsWith('/admin/catalog/prices'))

const productTabs = computed(() => [
  {
    to: '/admin/products',
    label: t('nav.products'),
    icon: 'products',
    active: route.path.startsWith('/admin/products'),
  },
  {
    to: '/admin/catalog/prices',
    label: t('products.tabs.pricing'),
    icon: 'coins',
    active: route.path.startsWith('/admin/catalog/prices'),
  },
  {
    to: '/admin/catalog/gallery',
    label: t('products.gallery'),
    icon: 'catalog',
    active: route.path.startsWith('/admin/catalog/gallery'),
  },
])

const pageTitle = computed(() => {
  if (route.path.startsWith('/admin/catalog/brands')) return t('nav.brands')
  if (route.path.startsWith('/admin/catalog/units')) return t('nav.units')
  if (route.path.startsWith('/admin/catalog/attributes')) return t('nav.attributes')
  if (route.path.startsWith('/admin/catalog/categories')) return t('catalog.tabs.categories')
  if (route.path.startsWith('/admin/catalog/catalogs')) return t('catalog.tabs.catalogs')
  if (route.path.startsWith('/admin/catalog/taxes')) return t('catalog.tabs.taxes')
  if (route.path.startsWith('/admin/catalog/options')) return t('nav.productOptions')
  if (route.path.startsWith('/admin/accompaniments')) return t('nav.accompaniments')
  if (route.path.startsWith('/admin/catalog/beverages')) return t('nav.beverages')
  if (route.path.startsWith('/admin/catalog/prices')) return t('nav.priceLists')
  return t('nav.catalog')
})
</script>

<template>
  <PageFrame>
    <template #title>{{ pageTitle }}</template>
    <template #subtitle>{{ t('catalog.subtitle') }}</template>
    <SubNav v-if="productArea" :tabs="productTabs" />
    <slot />
  </PageFrame>
</template>
