<script setup lang="ts">
import {
  CreditCard,
  DollarSign,
  Receipt,
  TrendingDown,
  TrendingUp,
  Users2,
} from 'lucide-vue-next'
import type { Kpi } from '@/lib/data'
import { formatMoney } from '@/lib/format'
import { cn } from '@/lib/cn'

defineProps<{ kpis: Kpi[] }>()

const icons = {
  dollar: DollarSign,
  receipt: Receipt,
  card: CreditCard,
  users: Users2,
} as const

const tones = {
  indigo: 'text-brand-600 bg-brand-50 dark:bg-brand-500/10',
  cyan: 'text-cyan-600 bg-cyan-50 dark:bg-cyan-500/10',
  emerald: 'text-emerald-600 bg-emerald-50 dark:bg-emerald-500/10',
  amber: 'text-amber-600 bg-amber-50 dark:bg-amber-500/10',
} as const

function formatValue(kpi: Kpi) {
  if (kpi.format === 'money') return formatMoney(kpi.value)
  if (kpi.format === 'percent') return `${kpi.value.toFixed(1)}%`
  return Math.round(kpi.value).toLocaleString('en-US')
}
</script>

<template>
  <section class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
    <article
      v-for="kpi in kpis"
      :key="kpi.key"
      class="card card-pad group relative overflow-hidden transition-[transform,box-shadow] duration-300 hover:-translate-y-0.5 hover:shadow-md"
    >
      <div class="halo pointer-events-none absolute -top-6 -right-6 h-24 w-24 rounded-full" />
      <div class="relative flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400">{{ kpi.label }}</p>
          <p class="mt-1 text-2xl font-bold tracking-tight text-[var(--color-ink)]">
            {{ formatValue(kpi) }}
          </p>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <span
              :class="
                cn(
                  'inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-semibold',
                  kpi.change >= 0
                    ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400'
                    : 'bg-rose-50 text-rose-700 dark:bg-rose-500/10 dark:text-rose-400',
                )
              "
            >
              <TrendingUp v-if="kpi.change >= 0" :size="12" />
              <TrendingDown v-else :size="12" />
              {{ Math.abs(kpi.change).toFixed(1) }}%
            </span>
            <span class="text-xs text-slate-500 dark:text-slate-400">vs previous</span>
          </div>
        </div>
        <div
          :class="
            cn('flex h-11 w-11 shrink-0 items-center justify-center rounded-xl', tones[kpi.tone])
          "
        >
          <component :is="icons[kpi.icon]" :size="20" />
        </div>
      </div>
    </article>
  </section>
</template>
