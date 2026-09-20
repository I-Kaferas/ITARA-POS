<script setup lang="ts">
import AppIcon from './AppIcon.vue'

withDefaults(defineProps<{
  label: string
  value: string | number
  icon?: string
  accent?: string
  iconBg?: string
  delta?: string | number | null
  deltaTone?: 'up' | 'down' | 'flat'
  spark?: number[]
}>(), {
  icon: 'dashboard',
  accent: 'var(--color-brand-600)',
  iconBg: 'var(--color-brand-50)',
  delta: null,
  deltaTone: 'flat',
  spark: () => [],
})
</script>

<template>
  <article class="kpi-card" :style="{ '--kpi-accent': accent }">
    <div class="kpi-card__top">
      <div>
        <p class="kpi-card__label">{{ label }}</p>
        <p class="kpi-card__value">{{ value }}</p>
        <span
          v-if="delta != null && delta !== ''"
          class="kpi-card__delta"
          :class="`kpi-card__delta--${deltaTone}`"
        >
          {{ delta }}
        </span>
      </div>
      <div class="kpi-card__icon" :style="{ background: iconBg, color: accent }">
        <AppIcon :name="icon" :size="20" />
      </div>
    </div>
    <div v-if="spark.length" class="kpi-card__spark" aria-hidden="true">
      <span
        v-for="(n, i) in spark"
        :key="i"
        :style="{ height: `${Math.max(12, Math.min(100, n))}%` }"
      />
    </div>
  </article>
</template>
