<script setup lang="ts">
import { Calendar, ChevronDown, Filter } from 'lucide-vue-next'
import {
  DATE_RANGE_OPTIONS,
  SEGMENT_OPTIONS,
  type DateRange,
  type SegmentFilter,
} from '@/lib/data'
import { cn } from '@/lib/cn'

defineProps<{
  dateRange: DateRange
  segment: SegmentFilter
  open: boolean
}>()

const emit = defineEmits<{
  'update:dateRange': [DateRange]
  'update:segment': [SegmentFilter]
}>()
</script>

<template>
  <div
    :class="
      cn(
        'mb-6 rounded-2xl border border-border bg-surface p-4 shadow-sm',
        open ? 'block' : 'hidden sm:block',
      )
    "
  >
    <div class="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
      <div
        class="flex flex-wrap items-center gap-1 rounded-lg border border-border bg-slate-50 p-1 dark:bg-slate-800/50"
      >
        <Calendar class="ml-2 h-4 w-4 shrink-0 text-faint" />
        <button
          v-for="opt in DATE_RANGE_OPTIONS"
          :key="opt.id"
          type="button"
          :class="
            cn(
              'rounded-md px-3 py-1.5 text-xs font-medium',
              dateRange === opt.id
                ? 'bg-white text-brand-600 shadow-sm dark:bg-slate-900'
                : 'text-slate-600 dark:text-slate-300',
            )
          "
          @click="emit('update:dateRange', opt.id)"
        >
          {{ opt.label }}
        </button>
      </div>

      <div class="relative w-full sm:w-56">
        <Filter class="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-faint" />
        <select
          class="w-full appearance-none rounded-lg border border-border bg-white py-2 pr-9 pl-9 text-sm font-medium text-ink dark:bg-slate-900"
          :value="segment"
          @change="emit('update:segment', ($event.target as HTMLSelectElement).value as SegmentFilter)"
        >
          <option v-for="opt in SEGMENT_OPTIONS" :key="opt.id" :value="opt.id">
            {{ opt.label }}
          </option>
        </select>
        <ChevronDown
          class="pointer-events-none absolute top-1/2 right-3 h-4 w-4 -translate-y-1/2 text-faint"
        />
      </div>
    </div>
  </div>
</template>
