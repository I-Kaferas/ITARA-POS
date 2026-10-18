<script setup lang="ts">
import {
  CreditCard,
  DollarSign,
  Receipt,
  TrendingDown,
  TrendingUp,
  Users2,
  type LucideIcon,
} from 'lucide-vue-next'
import type { KpiMetric } from '@/lib/data'
import { formatCurrency, formatPercent } from '@/lib/format'
import { cn } from '@/lib/cn'

defineProps<{
  kpis: KpiMetric[]
}>()

const icons: Record<KpiMetric['icon'], LucideIcon> = {
  dollar: DollarSign,
  receipt: Receipt,
  card: CreditCard,
  users: Users2,
}

const tintBox: Record<KpiMetric['tint'], string> = {
  indigo: 'bg-brand-50 text-brand-600 dark:bg-brand-500/10',
  cyan: 'bg-cyan-50 text-cyan-600 dark:bg-cyan-500/10',
  emerald: 'bg-emerald-50 text-emerald-600 dark:bg-emerald-500/10',
  amber: 'bg-amber-50 text-amber-600 dark:bg-amber-500/10',
}

function displayValue(kpi: KpiMetric): string {
  if (kpi.format === 'currency') return formatCurrency(kpi.value)
  if (kpi.format === 'percent') return formatPercent(kpi.value)
  return new Intl.NumberFormat('en-US').format(Math.round(kpi.value))
}
</script>

<template>
  <div class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
    <article
      v-for="kpi in kpis"
      :key="kpi.label"
      class="kpi-card relative overflow-hidden rounded-2xl border border-border bg-surface p-5 shadow-sm hover:-translate-y-0.5 hover:shadow-md"
    >
      <div class="halo-kpi pointer-events-none absolute -top-6 -right-6 h-24 w-24 rounded-full opacity-60" />
      <div class="relative flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="text-sm font-medium text-muted">{{ kpi.label }}</p>
          <p class="mt-1 text-2xl font-bold tracking-tight text-ink">{{ displayValue(kpi) }}</p>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <span
              :class="
                cn(
                  'inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-semibold',
                  kpi.trend >= 0
                    ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400'
                    : 'bg-rose-50 text-rose-700 dark:bg-rose-500/10 dark:text-rose-400',
                )
              "
            >
              <TrendingUp v-if="kpi.trend >= 0" class="h-3 w-3" />
              <TrendingDown v-else class="h-3 w-3" />
              {{ formatPercent(Math.abs(kpi.trend)) }}
            </span>
            <span class="text-xs text-muted">vs previous</span>
          </div>
        </div>
        <div
          :class="cn('flex h-11 w-11 shrink-0 items-center justify-center rounded-xl', tintBox[kpi.tint])"
        >
          <component :is="icons[kpi.icon]" class="h-5 w-5" />
        </div>
      </div>
    </article>
  </div>
</template>
