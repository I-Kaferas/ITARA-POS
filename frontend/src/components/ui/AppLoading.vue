<script setup lang="ts">
withDefaults(defineProps<{
  label?: string
  size?: 'sm' | 'md'
}>(), {
  size: 'md',
})
</script>

<template>
  <div class="ui-loading" role="status">
    <span class="ui-spinner" :class="{ 'ui-spinner--sm': size === 'sm' }" />
    <span v-if="label" class="ui-loading__label">{{ label }}</span>
  </div>
</template>
