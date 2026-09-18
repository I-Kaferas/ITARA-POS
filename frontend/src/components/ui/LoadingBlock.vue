<script setup lang="ts">
withDefaults(defineProps<{
  rows?: number
  label?: string
}>(), {
  rows: 5,
})
</script>

<template>
  <div class="ui-skeleton-stack" role="status" aria-live="polite">
    <span v-if="label" class="sr-only">{{ label }}</span>
    <div
      v-for="i in rows"
      :key="i"
      class="flex items-center gap-3"
    >
      <span class="ui-skeleton ui-skeleton--circle" style="width: 28px; height: 28px" />
      <div class="min-w-0 flex-1 space-y-2">
        <span class="ui-skeleton ui-skeleton--md block" :style="{ width: `${58 + (i % 3) * 12}%` }" />
        <span class="ui-skeleton ui-skeleton--sm block" :style="{ width: `${38 + (i % 4) * 10}%` }" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
.space-y-2 > * + * { margin-top: 0.5rem; }
</style>
