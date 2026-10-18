<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Search,
} from 'lucide-vue-next'
import type { Transaction, TxStatus } from '@/lib/data'
import { formatDateTime, formatMoney } from '@/lib/format'
import { cn } from '@/lib/cn'

const props = defineProps<{
  transactions: Transaction[]
}>()

type SortKey = 'id' | 'date' | 'merchant' | 'segment' | 'amount' | 'items' | 'payment' | 'status'

const query = ref('')
const status = ref<'all' | TxStatus>('all')
const sortKey = ref<SortKey>('date')
const sortDir = ref<'asc' | 'desc'>('desc')

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  let rows = props.transactions
  if (status.value !== 'all') {
    rows = rows.filter((t) => t.status === status.value)
  }
  if (q) {
    rows = rows.filter(
      (t) =>
        t.id.toLowerCase().includes(q) ||
        t.merchant.toLowerCase().includes(q) ||
        t.city.toLowerCase().includes(q) ||
        t.segment.toLowerCase().includes(q) ||
        t.payment.toLowerCase().includes(q),
    )
  }
  const dir = sortDir.value === 'asc' ? 1 : -1
  return [...rows].sort((a, b) => {
    const av = a[sortKey.value]
    const bv = b[sortKey.value]
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir
    return String(av).localeCompare(String(bv)) * dir
  })
})

const visible = computed(() => filtered.value.slice(0, 15))

function toggleSort(key: SortKey) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = key
    sortDir.value = key === 'amount' || key === 'date' || key === 'items' ? 'desc' : 'asc'
  }
}

const columns: { key: SortKey; label: string; align?: 'right' }[] = [
  { key: 'id', label: 'ID' },
  { key: 'date', label: 'Date' },
  { key: 'merchant', label: 'Merchant' },
  { key: 'segment', label: 'Segment' },
  { key: 'amount', label: 'Amount', align: 'right' },
  { key: 'items', label: 'Items', align: 'right' },
  { key: 'payment', label: 'Payment' },
  { key: 'status', label: 'Status' },
]

const statusStyles: Record<TxStatus, string> = {
  completed: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400',
  pending: 'bg-amber-50 text-amber-700 dark:bg-amber-500/10 dark:text-amber-400',
  refunded: 'bg-rose-50 text-rose-700 dark:bg-rose-500/10 dark:text-rose-400',
}

const statusDot: Record<TxStatus, string> = {
  completed: 'bg-emerald-500',
  pending: 'bg-amber-500',
  refunded: 'bg-rose-500',
}

function segmentLabel(s: string) {
  if (s === 'ecommerce') return 'E-Commerce'
  return s.charAt(0).toUpperCase() + s.slice(1)
}
</script>

<template>
  <section class="card mb-6 overflow-hidden">
    <div
      class="flex flex-col gap-4 border-b border-slate-200 p-5 sm:flex-row sm:items-center sm:justify-between dark:border-slate-800"
    >
      <div>
        <h3 class="text-base font-semibold text-[var(--color-ink)]">Recent Transactions</h3>
        <p class="text-sm text-slate-500 dark:text-slate-400">
          {{ filtered.length }} results · Live-updating
        </p>
      </div>
      <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
        <div class="relative">
          <Search
            :size="16"
            class="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-slate-400"
          />
          <input
            v-model="query"
            type="search"
            placeholder="Search transactions…"
            class="w-full rounded-lg border border-slate-200 bg-white py-2 pr-3 pl-9 text-sm dark:border-slate-700 dark:bg-slate-900 sm:w-64"
          />
        </div>
        <select
          v-model="status"
          class="rounded-lg border border-slate-200 bg-white py-2 pr-8 pl-3 text-sm font-medium dark:border-slate-700 dark:bg-slate-900"
        >
          <option value="all">All statuses</option>
          <option value="completed">Completed</option>
          <option value="pending">Pending</option>
          <option value="refunded">Refunded</option>
        </select>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="border-b border-slate-200 dark:border-slate-800">
          <tr>
            <th
              v-for="col in columns"
              :key="col.key"
              class="px-5 py-3 text-xs font-semibold tracking-wider text-slate-500 uppercase"
              :class="col.align === 'right' ? 'text-right' : 'text-left'"
            >
              <button
                type="button"
                class="inline-flex items-center gap-1"
                :class="
                  sortKey === col.key
                    ? 'text-brand-600'
                    : 'text-slate-500'
                "
                @click="toggleSort(col.key)"
              >
                {{ col.label }}
                <ArrowUp v-if="sortKey === col.key && sortDir === 'asc'" :size="12" />
                <ArrowDown v-else-if="sortKey === col.key && sortDir === 'desc'" :size="12" />
                <ArrowUpDown v-else :size="12" class="opacity-40" />
              </button>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
          <tr v-if="visible.length === 0">
            <td colspan="8" class="px-5 py-10 text-center text-sm text-slate-500">
              No transactions match your filters.
            </td>
          </tr>
          <tr
            v-for="tx in visible"
            :key="tx.id"
            class="transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/40"
          >
            <td class="px-5 py-3 font-mono text-xs font-semibold text-brand-600">{{ tx.id }}</td>
            <td class="px-5 py-3 text-slate-600 dark:text-slate-300">{{ formatDateTime(tx.date) }}</td>
            <td class="px-5 py-3">
              <div class="font-semibold text-[var(--color-ink)]">{{ tx.merchant }}</div>
              <div class="text-xs text-slate-500">{{ tx.city }}</div>
            </td>
            <td class="px-5 py-3">
              <span
                class="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-medium capitalize dark:bg-slate-800"
              >
                {{ segmentLabel(tx.segment) }}
              </span>
            </td>
            <td class="px-5 py-3 text-right font-semibold tracking-tight">
              {{ formatMoney(tx.amount, true) }}
            </td>
            <td class="px-5 py-3 text-right tracking-tight">{{ tx.items }}</td>
            <td class="px-5 py-3">{{ tx.payment }}</td>
            <td class="px-5 py-3">
              <span
                :class="
                  cn(
                    'inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium capitalize',
                    statusStyles[tx.status],
                  )
                "
              >
                <span class="h-1.5 w-1.5 rounded-full" :class="statusDot[tx.status]" />
                {{ tx.status }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      class="flex items-center justify-between border-t border-slate-200 px-5 py-3 dark:border-slate-800"
    >
      <p class="text-xs text-slate-500">
        Showing up to 15 of {{ filtered.length }} results
      </p>
      <p class="flex items-center gap-2 text-xs text-slate-500">
        <span class="h-2 w-2 animate-pulse rounded-full bg-emerald-500" />
        Live data
      </p>
    </div>
  </section>
</template>
