<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../layout/PageFrame.vue'
import SubNav from '../ui/SubNav.vue'

const { t } = useI18n()
const route = useRoute()

function isActive(path: string) {
  if (path === '/admin/pos/terminal') {
    return route.path === '/admin/pos/terminal' || route.path === '/admin/pos'
  }
  if (path === '/admin/pos/orders') {
    return route.path.startsWith('/admin/pos/orders')
      || (route.path.startsWith('/admin/sales') && !route.path.startsWith('/admin/sales/returns'))
  }
  return route.path === path || route.path.startsWith(`${path}/`)
}

function tab(to: string, label: string) {
  return { to, label, active: isActive(to) }
}

const tabGroups = computed(() => [
  {
    label: t('nav.group.posOps'),
    tabs: [
      tab('/admin/pos/overview', t('nav.posOverview')),
      tab('/admin/pos/terminal', t('nav.posTerminal')),
      tab('/admin/hospitality', t('nav.restaurant')),
      tab('/admin/pos/shifts', t('nav.posShifts')),
      tab('/admin/pos/reservations', t('nav.posReservations')),
    ],
  },
  {
    label: t('nav.group.posSales'),
    tabs: [
      tab('/admin/pos/orders', t('nav.posOrders')),
      tab('/admin/sales/returns', t('sales.tabs.returns')),
      tab('/admin/customers', t('nav.customers')),
    ],
  },
])

const pageTitle = computed(() => {
  for (const group of tabGroups.value) {
    const match = group.tabs.find(item => item.active)
    if (match) return match.label
  }
  return t('nav.pos')
})
</script>

<template>
  <PageFrame>
    <template #title>{{ pageTitle }}</template>
    <template #subtitle>{{ t('pointOfSale.overview.subtitle') }}</template>
    <SubNav :groups="tabGroups" />
    <slot />
  </PageFrame>
</template>
