<script setup lang="ts">
import { RouterLink } from 'vue-router'

defineProps<{
  tabs: { to: string; label: string; active: boolean }[]
}>()
</script>

<template>
  <nav class="sub-nav">
    <RouterLink
      v-for="tab in tabs"
      :key="tab.to"
      :to="tab.to"
      class="sub-nav__link"
      :class="{ 'sub-nav__link--active': tab.active }"
    >
      {{ tab.label }}
    </RouterLink>
  </nav>
</template>
