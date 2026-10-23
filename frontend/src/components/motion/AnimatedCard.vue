<script setup lang="ts">
withDefaults(defineProps<{
  index?: number
  tag?: string
}>(), {
  index: 0,
  tag: 'article',
})
</script>

<template>
  <component
    :is="tag"
    class="motion-card"
    :style="{ '--motion-index': String(index) }"
  >
    <slot />
  </component>
</template>
