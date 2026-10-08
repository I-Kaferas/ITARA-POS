<script setup lang="ts">
withDefaults(defineProps<{
  width?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  circle?: boolean
  lines?: number
}>(), {
  width: '100%',
  size: 'md',
  circle: false,
  lines: 1,
})
</script>

<template>
  <div v-if="lines > 1" class="ui-skeleton-stack" aria-hidden="true">
    <span
      v-for="line in lines"
      :key="line"
      class="ui-skeleton"
      :class="`ui-skeleton--${size}`"
      :style="{ width: line === lines ? '62%' : width }"
    />
  </div>
  <span
    v-else
    class="ui-skeleton"
    :class="[circle ? 'ui-skeleton--circle' : '', `ui-skeleton--${size}`]"
    :style="circle ? { width, height: width } : { width }"
    aria-hidden="true"
  />
</template>
