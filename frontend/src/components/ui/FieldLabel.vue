<script setup lang="ts">
import AppIcon from './AppIcon.vue'

defineProps<{
  icon: string
  for?: string
}>()
</script>

<template>
  <label class="field-label" :for="for">
    <span class="field-icon">
      <AppIcon :name="icon" :size="14" />
    </span>
    <span class="field-label__text"><slot /></span>
  </label>
</template>
