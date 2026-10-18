<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { PieChart } from 'echarts/charts'
import { TooltipComponent } from 'echarts/components'
import type { DashboardData } from '@/lib/data'
import { formatCurrency, formatPercent } from '@/lib/format'

use([CanvasRenderer, PieChart, TooltipComponent])

const props = defineProps<{
  data: DashboardData['payments']
}>()

const total = computed(() => props.data.reduce((s, p) => s + p.value, 0) || 1)

const option = computed(() => ({
  animationDuration: 800,
  tooltip: {
    trigger: 'item',
    backgroundColor: 'transparent',
    borderWidth: 0,
    padding: 0,
    formatter: (params: { name: string; value: number; percent: number; color: string }) => {
      return `<div style="border:1px solid #e2e8f0;border-radius:8px;background:rgba(255,255,255,0.95);backdrop-filter:blur(8px);padding:8px 12px;box-shadow:0 10px 15px -3px rgba(0,0,0,.1)">
        <div style="display:flex;align-items:center;gap:8px;font-size:14px">
          <span style="width:8px;height:8px;border-radius:999px;background:${params.color}"></span>
          <span style="color:#64748b">${params.name}</span>
          <span style="margin-left:auto;font-weight:600">${formatCurrency(params.value)} (${params.percent.toFixed(1)}%)</span>
        </div>
      </div>`
    },
  },
  series: [
    {
      type: 'pie',
      radius: [55, 85],
      center: ['50%', '50%'],
      padAngle: 3,
      itemStyle: { borderWidth: 0 },
      label: { show: false },
      data: props.data.map((p) => ({
        name: p.name,
        value: p.value,
        itemStyle: { color: p.color },
      })),
    },
  ],
}))
</script>

<template>
  <div class="rounded-2xl border border-border bg-surface p-5 shadow-sm">
    <h3 class="mb-4 text-base font-semibold text-ink">Payment Methods</h3>
    <VChart class="h-[220px] w-full" :option="option" autoresize />
    <ul class="mt-4 space-y-2">
      <li
        v-for="p in data"
        :key="p.name"
        class="flex items-center gap-2 text-sm"
      >
        <span class="h-2.5 w-2.5 rounded-full" :style="{ background: p.color }" />
        <span class="text-slate-600 dark:text-slate-300">{{ p.name }}</span>
        <span class="ml-auto font-bold tracking-tight text-ink">
          {{ formatPercent((p.value / total) * 100) }}
        </span>
      </li>
    </ul>
  </div>
</template>
