<script setup lang="ts">
import { computed } from 'vue'

export interface ChartPoint {
  label: string
  value: number
}

const props = withDefaults(defineProps<{
  variant?: 'bar' | 'line'
  points: ChartPoint[]
  caption?: string
  label?: string
}>(), {
  variant: 'bar',
  caption: '',
  label: '',
})

const width = 640
const height = 220
const pad = { t: 16, r: 8, b: 32, l: 8 }

const model = computed(() => {
  const points = props.points
  const count = points.length
  const max = Math.max(1, ...points.map((point) => Math.max(0, point.value)))
  const innerW = width - pad.l - pad.r
  const innerH = height - pad.t - pad.b
  const slot = count ? innerW / count : innerW
  const barW = Math.max(6, slot * 0.56)
  const baseline = pad.t + innerH

  const items = points.map((point, index) => {
    const value = Math.max(0, point.value)
    const barH = (value / max) * innerH
    const cx = pad.l + index * slot + slot / 2
    return {
      ...point,
      value,
      cx,
      x: cx - barW / 2,
      y: baseline - barH,
      h: barH,
      barW,
      last: index === count - 1,
    }
  })

  const line = items
    .map((item, index) => `${index === 0 ? 'M' : 'L'}${item.cx.toFixed(1)},${item.y.toFixed(1)}`)
    .join(' ')
  const area = items.length
    ? `${line} L${items[items.length - 1].cx.toFixed(1)},${baseline.toFixed(1)} L${items[0].cx.toFixed(1)},${baseline.toFixed(1)} Z`
    : ''
  const grid = [0.25, 0.5, 0.75].map((step) => pad.t + innerH * (1 - step))

  return { items, line, area, grid, baseline }
})

const aria = computed(() => props.label || props.caption)
</script>

<template>
  <figure class="ui-chart">
    <svg
      class="ui-chart__svg"
      :viewBox="`0 0 ${width} ${height}`"
      role="img"
      :aria-label="aria"
    >
      <line
        v-for="y in model.grid"
        :key="y"
        class="ui-chart__grid"
        :x1="pad.l"
        :x2="width - pad.r"
        :y1="y"
        :y2="y"
      />
      <template v-if="variant === 'bar'">
        <rect
          v-for="item in model.items"
          :key="item.label"
          :class="item.last ? 'ui-chart__bar ui-chart__bar--accent' : 'ui-chart__bar'"
          :x="item.x"
          :y="item.y"
          :width="item.barW"
          :height="Math.max(item.h, 1)"
          rx="3"
        >
          <title>{{ item.label }} · {{ item.value }}</title>
        </rect>
      </template>
      <template v-else>
        <path class="ui-chart__area" :d="model.area" />
        <path class="ui-chart__line" :d="model.line" />
        <circle
          v-for="item in model.items"
          :key="item.label"
          :class="item.last ? 'ui-chart__dot ui-chart__dot--accent' : 'ui-chart__dot'"
          :cx="item.cx"
          :cy="item.y"
          r="3.5"
        >
          <title>{{ item.label }} · {{ item.value }}</title>
        </circle>
      </template>
      <text
        v-for="item in model.items"
        :key="`${item.label}-label`"
        class="ui-chart__tick"
        :x="item.cx"
        :y="height - 8"
        text-anchor="middle"
      >
        {{ item.label }}
      </text>
    </svg>
    <figcaption v-if="caption" class="ui-chart__caption">{{ caption }}</figcaption>
  </figure>
</template>
