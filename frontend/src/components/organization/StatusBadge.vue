<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import Badge from '../ui/Badge.vue'

const props = defineProps<{
  active?: boolean
  label?: string
  variant?: 'success' | 'neutral' | 'brand' | 'warning'
}>()

const { t } = useI18n()

const resolvedVariant = computed(() => {
  if (props.variant) return props.variant
  return props.active ? 'success' : 'neutral'
})

const resolvedLabel = computed(() => {
  if (props.label) return props.label
  return props.active ? t('products.active') : t('products.inactive')
})
</script>

<template>
  <Badge :variant="resolvedVariant">
    {{ resolvedLabel }}
  </Badge>
</template>
