<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Search,
} from 'lucide-vue-next'
import type { Transaction, TxStatus } from '@/lib/data'
import { formatCurrency, formatDate } from '@/lib/format'
import { cn } from '@/lib/cn'

const props = defineProps<{
  transactions: Transaction[]
}>()

type SortKey = 'id' | 'date' | 'merchant' | 'segment' | 'amount' | 'items' | 'payment' | 'status'

const search = ref('')
const statusFilter = ref<'all' | TxStatus>('all')
const sortKey = ref<SortKey>('date')
const sortDir = ref<'asc' | 'desc'>('desc')

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

function toggleSort(key: SortKey) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = key
    sortDir.value = key === 'amount' || key === 'date' || key === 'items' ? 'desc' : 'asc'
  }
}

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  let rows = props.transactions
  if (statusFilter.value !== 'all') {
    rows = rows.filter((t) => t.status === statusFilter.value)
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
    const ka = a[sortKey.value]
    const kb = b[sortKey.value]
    if (sortKey.value === 'date') return ( +new Date(String(ka)) - +new Date(String(kb))) * dir
    if (typeof ka === 'number' && typeof kb === 'number') return (ka - kb) * dir
    return String(ka).localeCompare(String(kb)) * dir
  })
})

const visible = computed(() => filtered.value.slice(0, 15))

const statusClass: Record<TxStatus, string> = {
  completed: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400',
  pending: 'bg-amber-50 text-amber-700 dark:bg-amber-500/10 dark:text-amber-400',
  refunded: 'bg-rose-50 text-rose-700 dark:bg-rose-500/10 dark:text-rose-400',
}

const statusDot: Record<TxStatus, string> = {
  completed: 'bg-emerald-500',
  pending: 'bg-amber-500',
  refunded: 'bg-rose-500',
}
</script>

<template>
  <section class="overflow-hidden rounded-2xl border border-border bg-surface shadow-sm">
    <div class="flex flex-col gap-4 border-b border-border p-5 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h3 class="text-base font-semibold text-ink">Recent Transactions</h3>
        <p class="text-sm text-muted">
          {{ filtered.length }} results · Live-updating
        </p>
      </div>
      <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
        <div class="relative">
          <Search class="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-faint" />
          <input
            v-model="search"
            type="search"
            placeholder="Search transactions…"
            class="w-full rounded-lg border border-border bg-white py-2 pr-3 pl-9 text-sm text-ink sm:w-64 dark:bg-slate-900"
          />
        </div>
        <select
          v-model="statusFilter"
          class="rounded-lg border border-border bg-white py-2 pr-8 pl-3 text-sm font-medium text-ink dark:bg-slate-900"
        >
          <option value="all">All</option>
          <option value="completed">Completed</option>
          <option value="pending">Pending</option>
          <option value="refunded">Refunded</option>
        </select>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="border-b border-border">
          <tr>
            <th
              v-for="col in columns"
              :key="col.key"
              class="px-5 py-3 text-xs font-semibold tracking-wider text-muted uppercase"
              :class="col.align === 'right' ? 'text-right' : 'text-left'"
            >
              <button
                type="button"
                class="inline-flex items-center gap-1"
                :class="sortKey === col.key ? 'text-brand-600' : 'text-muted'"
                @click="toggleSort(col.key)"
              >
                {{ col.label }}
                <ArrowUpDown
                  v-if="sortKey !== col.key"
                  class="h-3 w-3 opacity-40"
                />
                <ArrowUp v-else-if="sortDir === 'asc'" class="h-3 w-3" />
                <ArrowDown v-else class="h-3 w-3" />
              </button>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
          <tr
            v-for="tx in visible"
            :key="tx.id"
            class="transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/40"
          >
            <td class="px-5 py-3 font-mono text-xs font-semibold text-brand-600">{{ tx.id }}</td>
            <td class="px-5 py-3 text-ink">{{ formatDate(tx.date) }}</td>
            <td class="px-5 py-3">
              <p class="font-semibold text-ink">{{ tx.merchant }}</p>
              <p class="text-xs text-muted">{{ tx.city }}</p>
            </td>
            <td class="px-5 py-3">
              <span
                class="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-medium capitalize dark:bg-slate-800"
              >
                {{ tx.segment }}
              </span>
            </td>
            <td class="px-5 py-3 text-right font-semibold tracking-tight text-ink">
              {{ formatCurrency(tx.amount, true) }}
            </td>
            <td class="px-5 py-3 text-right text-ink">{{ tx.items }}</td>
            <td class="px-5 py-3 text-ink">{{ tx.payment }}</td>
            <td class="px-5 py-3">
              <span
                :class="
                  cn(
                    'inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium capitalize',
                    statusClass[tx.status],
                  )
                "
              >
                <span class="h-1.5 w-1.5 rounded-full" :class="statusDot[tx.status]" />
                {{ tx.status }}
              </span>
            </td>
          </tr>
          <tr v-if="visible.length === 0">
            <td colspan="8" class="px-5 py-10 text-center text-sm text-muted">
              No transactions match your filters.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="flex items-center justify-between border-t border-border px-5 py-3">
      <p class="text-xs text-muted">
        Showing up to 15 of {{ filtered.length }} results
      </p>
      <p class="inline-flex items-center gap-2 text-xs text-muted">
        <span class="h-2 w-2 animate-pulse rounded-full bg-emerald-500" />
        Live data
      </p>
    </div>
  </section>
</template>
