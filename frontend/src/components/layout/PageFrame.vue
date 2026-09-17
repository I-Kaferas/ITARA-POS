<script setup lang="ts">
import { onBeforeUnmount, useSlots, watchEffect } from 'vue'
import { usePageHeaderStore } from '../../stores/pageHeader'

const pageHeader = usePageHeaderStore()
const slots = useSlots()

watchEffect(() => {
  pageHeader.setSlots(slots.title ?? null, slots.subtitle ?? null)
})

onBeforeUnmount(() => {
  pageHeader.clear()
})
</script>

<template>
  <slot />
</template>
