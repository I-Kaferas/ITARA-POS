<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { BarChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import type { DashboardData } from '@/lib/data'
import { formatCompactCurrency, formatCurrency } from '@/lib/format'

use([CanvasRenderer, BarChart, GridComponent, TooltipComponent])

const props = defineProps<{
  data: DashboardData['categories']
  isDark: boolean
}>()

const option = computed(() => {
  const gridColor = props.isDark ? '#1e293b' : '#e2e8f0'
  const tickColor = props.isDark ? '#94a3b8' : '#64748b'
  return {
    animationDuration: 800,
    grid: { left: 48, right: 12, top: 16, bottom: 32 },
    tooltip: {
      trigger: 'axis',
      backgroundColor: 'transparent',
      borderWidth: 0,
      padding: 0,
      formatter: (params: Array<{ name: string; value: number; color: string }>) => {
        const p = params[0]
        if (!p) return ''
        return `<div style="border:1px solid ${gridColor};border-radius:8px;background:rgba(255,255,255,0.95);backdrop-filter:blur(8px);padding:8px 12px;box-shadow:0 10px 15px -3px rgba(0,0,0,.1)">
          <div style="font-size:12px;color:#64748b;margin-bottom:6px">${p.name}</div>
          <div style="display:flex;align-items:center;gap:8px;font-size:14px">
            <span style="width:8px;height:8px;border-radius:999px;background:${p.color}"></span>
            <span style="color:#64748b">Sales</span>
            <span style="margin-left:auto;font-weight:600">${formatCurrency(p.value)}</span>
          </div>
        </div>`
      },
    },
    xAxis: {
      type: 'category',
      data: props.data.map((d) => d.name),
      axisTick: { show: false },
      axisLine: { show: false },
      axisLabel: { color: tickColor, fontSize: 11 },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { type: 'dashed', color: gridColor } },
      axisLabel: {
        color: tickColor,
        fontSize: 11,
        formatter: (v: number) => formatCompactCurrency(v),
      },
    },
    series: [
      {
        type: 'bar',
        barMaxWidth: 48,
        data: props.data.map((d, i) => ({
          value: d.sales,
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
  <div class="rounded-2xl border border-border bg-surface p-5 shadow-sm lg:col-span-2">
    <h3 class="mb-4 text-base font-semibold text-ink">Sales by Category</h3>
    <VChart class="h-[280px] w-full" :option="option" autoresize />
  </div>
</template>
