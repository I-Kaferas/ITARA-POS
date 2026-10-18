<script setup lang="ts">
import { computed } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { BarChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import VChart from 'vue-echarts'
import { formatCompact, formatMoney } from '@/lib/format'
import { useDarkMode } from '@/composables/useDarkMode'

use([CanvasRenderer, BarChart, GridComponent, TooltipComponent])

const props = defineProps<{
  categories: { name: string; sales: number }[]
}>()

const { dark } = useDarkMode()

const option = computed(() => {
  const gridColor = dark.value ? '#1e293b' : '#e2e8f0'
  const tickColor = dark.value ? '#94a3b8' : '#64748b'
  return {
    animationDuration: 800,
    grid: { left: 8, right: 8, top: 16, bottom: 8, containLabel: true },
    tooltip: {
      trigger: 'axis',
      backgroundColor: dark.value ? 'rgba(15,23,42,0.95)' : 'rgba(255,255,255,0.95)',
      borderColor: gridColor,
      borderWidth: 1,
      extraCssText: 'backdrop-filter:blur(8px);border-radius:8px;box-shadow:0 10px 15px -3px rgba(0,0,0,.1)',
      textStyle: { color: dark.value ? '#f1f5f9' : '#0f172a', fontSize: 12 },
      formatter: (params: { name: string; value: number; color: string }[]) => {
        const p = params[0]
        return `<div style="font-size:12px;color:#64748b;margin-bottom:4px">${p.name}</div>
          <div style="display:flex;align-items:center;gap:6px">
            <span style="width:8px;height:8px;border-radius:9999px;background:${p.color}"></span>
            <strong style="letter-spacing:-0.02em">${formatMoney(p.value)}</strong>
          </div>`
      },
    },
    xAxis: {
      type: 'category',
      data: props.categories.map((c) => c.name),
      axisTick: { show: false },
      axisLine: { show: false },
      axisLabel: { color: tickColor, fontSize: 11 },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { show: true, lineStyle: { type: 'dashed', color: gridColor } },
      axisLabel: {
        color: tickColor,
        fontSize: 11,
        formatter: (v: number) => formatCompact(v),
      },
    },
    series: [
      {
        type: 'bar',
        barMaxWidth: 48,
        data: props.categories.map((c, i) => ({
          value: c.sales,
          itemStyle: {
            color: i % 2 === 0 ? '#6366f1' : '#06b6d4',
            borderRadius: [8, 8, 0, 0],
          },
        })),
      },
    ],
  }
})
</script>

<template>
  <article class="card card-pad lg:col-span-2">
    <h3 class="mb-4 text-base font-semibold text-[var(--color-ink)]">Sales by Category</h3>
    <VChart class="h-[280px] w-full" :option="option" autoresize />
  </article>
</template>
