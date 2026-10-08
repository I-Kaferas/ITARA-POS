<script setup lang="ts">
import { watch } from 'vue'
import { RouterView } from 'vue-router'
import { useI18n } from 'vue-i18n'
import AppToastHost from './components/ui/AppToastHost.vue'
import ConfirmDialog from './components/ui/ConfirmDialog.vue'

const { t, locale } = useI18n()

watch(locale, () => {
  document.title = t('app.name')
}, { immediate: true })
</script>

<template>
  <RouterView />
  <ConfirmDialog />
  <AppToastHost />
</template>
