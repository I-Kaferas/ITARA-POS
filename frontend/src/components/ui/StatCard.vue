<script setup lang="ts">
import AppIcon from './AppIcon.vue'

defineProps<{
  label: string
  value: string | number
  icon: string
  accent: string
  iconBg: string
}>()
</script>

<template>
  <div class="stat-card">
    <div class="stat-card__accent" :style="{ background: accent }" />
    <div class="stat-card__icon" :style="{ background: iconBg, color: accent }">
      <AppIcon :name="icon" :size="20" />
    </div>
    <div class="stat-card__value">{{ value }}</div>
    <div class="stat-card__label">{{ label }}</div>
  </div>
</template>
