<script setup lang="ts">
defineProps<{
  title: string
  subtitle?: string
}>()
</script>

<template>
  <header class="page-header-bar">
    <div class="page-header-bar__copy">
      <h1 class="page-header-bar__title">{{ title }}</h1>
      <p v-if="subtitle" class="page-header-bar__subtitle">{{ subtitle }}</p>
      <slot name="meta" />
    </div>
    <div v-if="$slots.actions" class="page-header-bar__actions">
      <slot name="actions" />
    </div>
  </header>
</template>
