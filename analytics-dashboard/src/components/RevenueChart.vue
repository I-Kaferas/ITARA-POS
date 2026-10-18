<script setup lang="ts">
import { computed, ref } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  type TooltipComponentFormatterCallbackParams,
} from 'echarts/components'
import type { DashboardData } from '@/lib/data'
import { formatCompactCurrency, formatCurrency, formatShortDate } from '@/lib/format'

use([CanvasRenderer, LineChart, GridComponent, TooltipComponent])

const props = defineProps<{
  data: DashboardData['revenueTrend']
  isDark: boolean
}>()

const chartRef = ref()

const option = computed(() => {
  const gridColor = props.isDark ? '#1e293b' : '#e2e8f0'
  const tickColor = props.isDark ? '#94a3b8' : '#64748b'
  return {
    animationDuration: 800,
    grid: { left: 48, right: 16, top: 24, bottom: 28 },
    tooltip: {
      trigger: 'axis',
      backgroundColor: 'transparent',
      borderWidth: 0,
      padding: 0,
      extraCssText: 'box-shadow:none;',
      formatter: (params: TooltipComponentFormatterCallbackParams) => {
        const list = Array.isArray(params) ? params : [params]
        const first = list[0]
        if (!first || typeof first !== 'object' || !('value' in first)) return ''
        const date = String(first.axisValueLabel ?? first.name ?? '')
        const value = Number(Array.isArray(first.value) ? first.value[1] : first.value)
        return `<div style="border:1px solid ${gridColor};border-radius:8px;background:rgba(255,255,255,0.95);backdrop-filter:blur(8px);padding:8px 12px;box-shadow:0 10px 15px -3px rgba(0,0,0,.1)">
          <div style="font-size:12px;color:#64748b;margin-bottom:6px">${date}</div>
          <div style="display:flex;align-items:center;gap:8px;font-size:14px">
            <span style="width:8px;height:8px;border-radius:999px;background:#6366f1"></span>
            <span style="color:#64748b">Revenue</span>
            <span style="margin-left:auto;font-weight:600;letter-spacing:-0.02em">${formatCurrency(value)}</span>
          </div>
        </div>`
      },
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: props.data.map((d) => formatShortDate(d.date)),
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
        name: 'Revenue',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 0,
        showSymbol: false,
        emphasis: { focus: 'series', itemStyle: { color: '#6366f1', borderWidth: 0 } },
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
        data: props.data.map((d) => d.revenue),
      },
    ],
  }
})
</script>

<template>
  <div class="rounded-2xl border border-border bg-surface p-5 shadow-sm lg:col-span-2">
    <h3 class="mb-4 text-base font-semibold text-ink">Revenue Trend</h3>
    <VChart ref="chartRef" class="h-[300px] w-full" :option="option" autoresize />
  </div>
</template>
