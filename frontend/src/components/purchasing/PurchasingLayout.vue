<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import PageFrame from '../layout/PageFrame.vue'

const { t } = useI18n()
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.purchases') }}</template>
    <template #subtitle>{{ t('purchases.subtitle') }}</template>
    <slot />
  </PageFrame>
</template>
