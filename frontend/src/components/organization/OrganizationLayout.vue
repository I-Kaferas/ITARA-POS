<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import PageFrame from '../layout/PageFrame.vue'

const { t } = useI18n()
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.organization') }}</template>
    <template #subtitle>{{ t('org.subtitle') }}</template>
    <slot />
  </PageFrame>
</template>
