<script setup lang="ts">
withDefaults(defineProps<{
  variant?: 'success' | 'neutral' | 'brand' | 'warning'
}>(), {
  variant: 'neutral',
})
</script>

<template>
  <span class="ui-badge" :class="`ui-badge--${variant}`">
    <slot />
  </span>
</template>
