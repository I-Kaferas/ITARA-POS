<script setup lang="ts">
import { RouterLink } from 'vue-router'
import AppIcon from './AppIcon.vue'

withDefaults(defineProps<{
  tabs: { to: string; label: string; active: boolean; icon?: string; color?: string; badge?: number }[]
  variant?: 'default' | 'secondary'
}>(), {
  variant: 'default',
})
</script>

<template>
  <nav class="sub-nav" :class="{ 'sub-nav--secondary': variant === 'secondary' }">
    <RouterLink
      v-for="tab in tabs"
      :key="tab.to"
      :to="tab.to"
      class="sub-nav__link"
      :class="{
        'sub-nav__link--active': tab.active,
      }"
    >
      <span v-if="tab.icon" class="sub-nav__mark" aria-hidden="true">
        <AppIcon :name="tab.icon" :size="variant === 'secondary' ? 16 : 18" />
      </span>
      <span>{{ tab.label }}</span>
      <span v-if="tab.badge" class="sub-nav__badge">{{ tab.badge > 99 ? '99+' : tab.badge }}</span>
    </RouterLink>
  </nav>
</template>
