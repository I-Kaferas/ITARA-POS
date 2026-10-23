<script setup lang="ts">
import { computed } from 'vue'
import AppIcon from './AppIcon.vue'
import CountUp from '../motion/CountUp.vue'

type KpiTone = 'violet' | 'amber' | 'coral' | 'pink' | 'green' | 'blue' | 'teal' | 'navy'
type KpiChart = 'area' | 'bars' | 'dots'

const props = withDefaults(defineProps<{
  label: string
  value: string | number
  icon?: string
  /** Explicit colour; wins over `tone`. Without either, the colour follows the card's grid position. */
  accent?: string
  /** Kept for API compatibility — the icon tile is now a solid accent tile. */
  iconBg?: string
  tone?: KpiTone | null
  hint?: string
  info?: string
  delta?: string | number | null
  deltaTone?: 'up' | 'down' | 'flat'
  spark?: number[]
  chart?: KpiChart
  countTo?: number | null
  countFormat?: 'integer' | 'money'
}>(), {
  icon: 'dashboard',
  accent: '',
  iconBg: '',
  tone: null,
  hint: '',
  info: '',
  delta: null,
  deltaTone: 'flat',
  spark: () => [],
  chart: 'area',
  countTo: null,
  countFormat: 'integer',
})

const W = 140
const H = 64
const PAD = 6

const style = computed(() => (props.accent ? { '--kpi-accent': props.accent } : undefined))
const toneClass = computed(() => (props.tone ? `kpi-card--${props.tone}` : ''))
const hasDelta = computed(() => props.delta != null && props.delta !== '')

const points = computed(() => {
  const values = props.spark.filter(n => Number.isFinite(n))
  if (values.length < 2) return []
  const min = Math.min(...values)
  const max = Math.max(...values)
  const span = max - min
  const step = (W - PAD * 2) / (values.length - 1)
  return values.map((v, i) => ({
    x: PAD + i * step,
    y: span === 0 ? H - PAD : PAD + (1 - (v - min) / span) * (H - PAD * 2 - 6),
    v,
  }))
})

function smooth(list: { x: number; y: number }[]) {
  if (!list.length) return ''
  let d = `M${list[0].x.toFixed(1)},${list[0].y.toFixed(1)}`
  for (let i = 0; i < list.length - 1; i += 1) {
    const p0 = list[i - 1] ?? list[i]
    const p1 = list[i]
    const p2 = list[i + 1]
    const p3 = list[i + 2] ?? p2
    const c1x = p1.x + (p2.x - p0.x) / 6
    const c1y = p1.y + (p2.y - p0.y) / 6
    const c2x = p2.x - (p3.x - p1.x) / 6
    const c2y = p2.y - (p3.y - p1.y) / 6
    d += ` C${c1x.toFixed(1)},${c1y.toFixed(1)} ${c2x.toFixed(1)},${c2y.toFixed(1)} ${p2.x.toFixed(1)},${p2.y.toFixed(1)}`
  }
  return d
}

const linePath = computed(() => smooth(points.value))
const areaPath = computed(() => {
  const list = points.value
  if (!list.length) return ''
  return `${linePath.value} L${list[list.length - 1].x.toFixed(1)},${H} L${list[0].x.toFixed(1)},${H} Z`
})

const bars = computed(() => {
  const values = props.spark.filter(n => Number.isFinite(n))
  if (values.length < 2) return []
  const max = Math.max(...values, 0)
  const avg = values.reduce((sum, n) => sum + n, 0) / values.length
  const gap = 6
  const width = Math.max(4, (W - gap * (values.length - 1)) / values.length)
  return values.map((v, i) => {
    const h = max <= 0 ? 4 : Math.max(4, (v / max) * (H - 4))
    return { x: i * (width + gap), y: H - h, w: width, h, strong: v >= avg || i === values.length - 1 }
  })
})
</script>

<template>
  <article class="kpi-card" :class="[toneClass, { 'kpi-card--custom': accent }]" :style="style">
    <header class="kpi-card__head">
      <span class="kpi-card__icon" aria-hidden="true">
        <AppIcon :name="icon" :size="20" />
      </span>
      <div class="kpi-card__titles">
        <p class="kpi-card__label">{{ label }}</p>
        <p v-if="hint" class="kpi-card__hint">{{ hint }}</p>
      </div>
      <span
        v-if="info"
        class="kpi-card__info"
        role="img"
        tabindex="0"
        :title="info"
        :aria-label="info"
      >
        <AppIcon name="info" :size="16" />
      </span>
    </header>

    <div class="kpi-card__body">
      <div class="kpi-card__figures">
        <p class="kpi-card__value">
          <CountUp v-if="countTo != null" :value="countTo" :format="countFormat" />
          <template v-else>{{ value }}</template>
        </p>
        <p v-if="hasDelta" class="kpi-card__delta" :class="`kpi-card__delta--${deltaTone}`">
          <span>{{ delta }}</span>
          <svg class="kpi-card__trend" viewBox="0 0 12 12" width="12" height="12" aria-hidden="true">
            <path
              v-if="deltaTone === 'up'"
              d="M3 9 9 3M4.5 3H9v4.5"
            />
            <path
              v-else-if="deltaTone === 'down'"
              d="M6 2.5v7M2.75 6.25 6 9.5l3.25-3.25"
            />
            <path v-else d="M2.5 6h7M6.75 3.25 9.5 6 6.75 8.75" />
          </svg>
        </p>
      </div>

      <svg
        v-if="points.length"
        class="kpi-card__chart"
        :class="`kpi-card__chart--${chart}`"
        :viewBox="`0 0 ${W} ${H}`"
        aria-hidden="true"
      >
        <template v-if="chart === 'bars'">
          <rect
            v-for="(bar, i) in bars"
            :key="i"
            class="kpi-card__bar"
            :class="{ 'is-strong': bar.strong }"
            :x="bar.x"
            :y="bar.y"
            :width="bar.w"
            :height="bar.h"
            rx="3"
          />
        </template>
        <template v-else-if="chart === 'dots'">
          <line
            v-for="(p, i) in points"
            :key="`drop-${i}`"
            class="kpi-card__drop"
            :x1="p.x"
            :x2="p.x"
            :y1="p.y + 5"
            :y2="H"
          />
          <path class="kpi-card__line" :d="linePath" />
          <circle v-for="(p, i) in points" :key="`dot-${i}`" class="kpi-card__dot" :cx="p.x" :cy="p.y" r="3.25" />
        </template>
        <template v-else>
          <path class="kpi-card__area" :d="areaPath" />
          <path class="kpi-card__line" :d="linePath" />
        </template>
      </svg>
    </div>
  </article>
</template>
