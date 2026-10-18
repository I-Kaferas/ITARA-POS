<script setup lang="ts">
import type { DashboardData } from '@/lib/data'
import { formatCurrency, formatPercent } from '@/lib/format'

defineProps<{
  processingVolume: number
  refunds: number
  refundRate: number
  locations: DashboardData['locations']
}>()
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="gradient-processing rounded-2xl p-5 text-white shadow-sm">
      <p class="text-sm text-brand-100">Processing Volume</p>
      <p class="mt-1 text-[30px] font-bold tracking-tight">
        {{ formatCurrency(processingVolume) }}
      </p>
      <div class="mt-4 grid grid-cols-2 gap-3 border-t border-white/20 pt-4">
        <div>
          <p class="text-xs text-brand-100">Refunds</p>
          <p class="mt-0.5 text-lg font-semibold tracking-tight">{{ formatCurrency(refunds) }}</p>
        </div>
        <div>
          <p class="text-xs text-brand-100">Refund rate</p>
          <p class="mt-0.5 text-lg font-semibold tracking-tight">{{ formatPercent(refundRate) }}</p>
        </div>
      </div>
    </div>

    <div class="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <h3 class="mb-4 text-base font-semibold text-ink">Top Location</h3>
      <ul class="space-y-3">
        <li v-for="loc in locations" :key="loc.name">
          <div class="mb-1.5 flex items-center justify-between text-sm">
            <span class="font-medium text-ink">{{ loc.name }}</span>
            <span class="font-semibold tracking-tight text-ink">{{ formatPercent(loc.share) }}</span>
          </div>
          <div class="h-2 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
            <div
              class="gradient-progress h-full rounded-full"
              :style="{ width: `${Math.min(loc.share, 100)}%` }"
            />
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>
