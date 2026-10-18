<script setup lang="ts">
import { formatMoney, formatPercent } from '@/lib/format'

defineProps<{
  processingVolume: number
  refunds: number
  refundRate: number
  locations: { name: string; share: number }[]
}>()
</script>

<template>
  <div class="flex flex-col gap-4 lg:col-span-1">
    <article class="gradient-cta rounded-2xl p-5 text-white shadow-sm">
      <p class="text-sm text-brand-100">Processing Volume</p>
      <p class="mt-1 text-[30px] font-bold tracking-tight">
        {{ formatMoney(processingVolume) }}
      </p>
      <div class="mt-4 grid grid-cols-2 gap-3 border-t border-white/20 pt-4">
        <div>
          <p class="text-sm text-brand-100">Refunds</p>
          <p class="mt-0.5 text-lg font-semibold tracking-tight">{{ formatMoney(refunds) }}</p>
        </div>
        <div>
          <p class="text-sm text-brand-100">Refund rate</p>
          <p class="mt-0.5 text-lg font-semibold tracking-tight">
            {{ formatPercent(refundRate) }}
          </p>
        </div>
      </div>
    </article>

    <article class="card card-pad">
      <h3 class="mb-4 text-base font-semibold text-[var(--color-ink)]">Top Location</h3>
      <ul class="space-y-4">
        <li v-for="loc in locations" :key="loc.name">
          <div class="mb-1.5 flex items-center justify-between text-sm">
            <span class="font-medium text-[var(--color-ink)]">{{ loc.name }}</span>
            <span class="font-semibold tracking-tight text-slate-500 dark:text-slate-400">
              {{ formatPercent(loc.share) }}
            </span>
          </div>
          <div class="h-2 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
            <div
              class="gradient-progress h-full rounded-full"
              :style="{ width: `${Math.min(loc.share, 100)}%` }"
            />
          </div>
        </li>
      </ul>
    </article>
  </div>
</template>
