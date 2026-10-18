<script setup lang="ts">
import { computed } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { PieChart } from 'echarts/charts'
import { TooltipComponent } from 'echarts/components'
import VChart from 'vue-echarts'
import type { PaymentMethod } from '@/lib/data'
import { formatMoney, formatPercent } from '@/lib/format'
import { useDarkMode } from '@/composables/useDarkMode'

use([CanvasRenderer, PieChart, TooltipComponent])

const props = defineProps<{
  payments: { name: PaymentMethod; value: number; color: string }[]
}>()

const { dark } = useDarkMode()

const total = computed(() => props.payments.reduce((a, p) => a + p.value, 0) || 1)

const legend = computed(() =>
  props.payments.map((p) => ({
    ...p,
    pct: (p.value / total.value) * 100,
  })),
)

const option = computed(() => ({
  animationDuration: 800,
  tooltip: {
    trigger: 'item',
    backgroundColor: dark.value ? 'rgba(15,23,42,0.95)' : 'rgba(255,255,255,0.95)',
    borderColor: dark.value ? '#1e293b' : '#e2e8f0',
    borderWidth: 1,
    extraCssText: 'backdrop-filter:blur(8px);border-radius:8px;box-shadow:0 10px 15px -3px rgba(0,0,0,.1)',
    textStyle: { color: dark.value ? '#f1f5f9' : '#0f172a', fontSize: 12 },
    formatter: (p: { name: string; value: number; percent: number; color: string }) =>
      `<div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">
        <span style="width:8px;height:8px;border-radius:9999px;background:${p.color}"></span>
        <span style="color:#64748b">${p.name}</span>
      </div>
      <strong style="letter-spacing:-0.02em">${formatMoney(p.value)}</strong>
      <span style="color:#64748b;margin-left:4px">(${p.percent.toFixed(1)}%)</span>`,
  },
  series: [
    {
      type: 'pie',
      radius: ['55', '85'],
      center: ['50%', '50%'],
      padAngle: 3,
      itemStyle: { borderWidth: 0 },
      label: { show: false },
      data: props.payments.map((p) => ({
        name: p.name,
        value: p.value,
        itemStyle: { color: p.color },
      })),
    },
  ],
}))
</script>

<template>
  <article class="card card-pad lg:col-span-1">
    <h3 class="mb-2 text-base font-semibold text-[var(--color-ink)]">Payment Methods</h3>
    <VChart class="h-[220px] w-full" :option="option" autoresize />
    <ul class="mt-2 space-y-2">
      <li
        v-for="row in legend.slice(0, 4)"
        :key="row.name"
        class="flex items-center justify-between gap-2 text-sm"
      >
        <span class="flex items-center gap-2 text-slate-600 dark:text-slate-300">
          <span class="inline-block h-2.5 w-2.5 rounded-full" :style="{ background: row.color }" />
          {{ row.name }}
        </span>
        <span class="font-bold tracking-tight text-[var(--color-ink)]">
          {{ formatPercent(row.pct) }}
        </span>
      </li>
    </ul>
  </article>
</template>
