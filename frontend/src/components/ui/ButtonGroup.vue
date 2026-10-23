<script setup lang="ts">
withDefaults(defineProps<{
  align?: 'start' | 'end' | 'between'
}>(), {
  align: 'start',
})
</script>

<template>
  <div class="btn-group" :class="`btn-group--${align}`">
    <slot />
  </div>
</template>
