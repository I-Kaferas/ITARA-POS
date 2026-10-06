<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'

const { t } = useI18n()
const route = useRoute()
const title = computed(() => t(String(route.meta.titleKey ?? 'nav.settingsHub')))
</script>

<template>
  <PageFrame>
    <template #title>{{ title }}</template>
    <EmptyState icon="layers" :title="t('org.empty')" />
  </PageFrame>
</template>
