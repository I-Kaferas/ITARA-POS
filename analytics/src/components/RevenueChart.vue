<script setup lang="ts">
import { computed } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  MarkPointComponent,
} from 'echarts/components'
import VChart from 'vue-echarts'
import { formatCompact, formatDateShort, formatMoney } from '@/lib/format'
import { useDarkMode } from '@/composables/useDarkMode'

use([CanvasRenderer, LineChart, GridComponent, TooltipComponent, MarkPointComponent])

const props = defineProps<{
  series: { date: string; revenue: number }[]
}>()

const { dark } = useDarkMode()

const option = computed(() => {
  const gridColor = dark.value ? '#1e293b' : '#e2e8f0'
  const tickColor = dark.value ? '#94a3b8' : '#64748b'
  return {
    animationDuration: 800,
    grid: { left: 16, right: 12, top: 16, bottom: 8, containLabel: true },
    tooltip: {
      trigger: 'axis',
      backgroundColor: dark.value ? 'rgba(15,23,42,0.95)' : 'rgba(255,255,255,0.95)',
      borderColor: gridColor,
      borderWidth: 1,
      extraCssText: 'backdrop-filter:blur(8px);border-radius:8px;box-shadow:0 10px 15px -3px rgba(0,0,0,.1)',
      textStyle: { color: dark.value ? '#f1f5f9' : '#0f172a', fontSize: 12 },
      formatter: (params: { axisValue: string; value: number; color: string }[]) => {
        const p = params[0]
        return `<div style="font-size:12px;color:#64748b;margin-bottom:4px">${formatDateShort(p.axisValue)}</div>
          <div style="display:flex;align-items:center;gap:6px">
            <span style="width:8px;height:8px;border-radius:9999px;background:${p.color}"></span>
            <strong style="letter-spacing:-0.02em">${formatMoney(p.value)}</strong>
          </div>`
      },
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: props.series.map((d) => d.date),
      axisTick: { show: false },
      axisLine: { show: false },
      axisLabel: {
        color: tickColor,
        fontSize: 11,
        formatter: (v: string) => formatDateShort(v),
        interval: 'auto',
      },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { type: 'dashed', color: gridColor } },
      axisLabel: {
        color: tickColor,
        fontSize: 11,
        formatter: (v: number) => formatCompact(v),
      },
    },
    series: [
      {
        type: 'line',
        smooth: true,
        symbol: 'circle',
        showSymbol: false,
        symbolSize: 10,
        lineStyle: { width: 2.5, color: '#6366f1' },
        itemStyle: { color: '#6366f1', borderWidth: 0 },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(99,102,241,0.35)' },
              { offset: 1, color: 'rgba(99,102,241,0)' },
            ],
          },
        },
        data: props.series.map((d) => d.revenue),
        emphasis: { focus: 'series', itemStyle: { color: '#6366f1', borderWidth: 0 } },
      },
    ],
  }
})
</script>

<template>
  <article class="card card-pad lg:col-span-2">
    <h3 class="mb-4 text-base font-semibold text-[var(--color-ink)]">Revenue Trend</h3>
    <VChart class="h-[300px] w-full" :option="option" autoresize />
  </article>
</template>
