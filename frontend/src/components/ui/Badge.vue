<script setup lang="ts">
withDefaults(defineProps<{
  variant?: 'success' | 'neutral' | 'brand' | 'warning' | 'danger' | 'info'
}>(), {
  variant: 'neutral',
})
</script>

<template>
  <span class="ui-badge" :class="`ui-badge--${variant}`">
    <slot />
  </span>
</template>
