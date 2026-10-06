<script setup lang="ts">
withDefaults(defineProps<{
  variant?: 'success' | 'neutral' | 'brand' | 'warning' | 'danger' | 'info'
  dot?: boolean
}>(), {
  variant: 'neutral',
  dot: false,
})
</script>

<template>
  <span class="ui-badge" :class="`ui-badge--${variant}`">
    <span v-if="dot" class="ui-badge__dot" aria-hidden="true" />
    <slot />
  </span>
</template>
