<script setup lang="ts">
import type { AppLocale } from '../../i18n/locales'

defineProps<{
  locale: AppLocale
}>()
</script>

<template>
  <span class="lang-flag" aria-hidden="true">{{ locale.toUpperCase() }}</span>
</template>

<style scoped>
.lang-flag {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.6rem;
  height: 1.15rem;
  padding: 0 0.25rem;
  border-radius: 0.25rem;
  background: #e8eef3;
  color: #334155;
  font-size: 0.62rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}
</style>
