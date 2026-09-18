<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import ReportsLayout from './ReportsLayout.vue'
import EmptyState from '../ui/EmptyState.vue'

defineProps<{
  icon?: string
}>()

const { t } = useI18n()
</script>

<template>
  <ReportsLayout>
    <EmptyState
      :icon="icon ?? 'note'"
      :title="t('reports.comingSoonTitle')"
      :description="t('reports.comingSoonDesc')"
    />
  </ReportsLayout>
</template>
