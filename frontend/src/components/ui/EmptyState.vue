<script setup lang="ts">
import AppIcon from './AppIcon.vue'

defineProps<{
  icon?: string
  title: string
  description?: string
}>()
</script>

<template>
  <div class="empty-state">
    <div class="empty-state__icon">
      <AppIcon :name="icon ?? 'package'" :size="24" />
    </div>
    <p class="empty-state__title">{{ title }}</p>
    <p v-if="description" class="empty-state__desc">{{ description }}</p>
    <slot />
  </div>
</template>
