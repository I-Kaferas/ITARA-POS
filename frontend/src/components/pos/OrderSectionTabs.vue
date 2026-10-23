<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import SubNav from '../ui/SubNav.vue'
import { useQrPendingCount } from '../../composables/useQrPendingCount'

const { t } = useI18n()
const route = useRoute()
const { count } = useQrPendingCount()

const onQr = computed(() => route.path.startsWith('/admin/pos/qr-orders'))

const tabs = computed(() => [
  {
    to: '/admin/pos/orders',
    label: t('nav.posOrders'),
    active: !onQr.value,
  },
  {
    to: '/admin/pos/qr-orders',
    label: t('nav.posQrOrders'),
    active: onQr.value,
    badge: count.value > 0 ? count.value : undefined,
  },
])
</script>

<template>
  <div class="order-tabs">
    <SubNav :tabs="tabs" />
  </div>
</template>

<style>
.order-tabs .sub-nav {
  width: fit-content;
  max-width: 100%;
  overflow: visible;
}

html:not([data-theme="dark"]) .app-content .order-tabs .sub-nav__link--active,
html:not([data-theme="dark"]) .app-content .order-tabs .sub-nav__link--active:hover {
  background-color: var(--color-brand-600);
  color: #fff;
  box-shadow: none;
}
</style>
