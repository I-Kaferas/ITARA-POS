<script setup lang="ts">
import { Calendar, ChevronDown, Filter } from 'lucide-vue-next'
import {
  DATE_RANGE_OPTIONS,
  SEGMENT_OPTIONS,
  type DateRange,
  type Segment,
} from '@/lib/data'
import { cn } from '@/lib/cn'

defineProps<{
  dateRange: DateRange
  segment: Segment
  visible: boolean
}>()

const emit = defineEmits<{
  'update:dateRange': [DateRange]
  'update:segment': [Segment]
}>()
</script>

<template>
  <section
    :class="
      cn(
        'card mb-6 p-4',
        visible ? 'flex' : 'hidden',
        'flex-col gap-4 sm:flex sm:flex-row sm:items-center sm:justify-between',
      )
    "
  >
    <div
      class="flex flex-wrap items-center gap-1 rounded-lg border border-slate-200 bg-slate-50 p-1 dark:border-slate-700 dark:bg-slate-800/50"
    >
      <Calendar :size="16" class="ml-2 shrink-0 text-slate-400" />
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
      <Filter
        :size="16"
        class="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-slate-400"
      />
      <select
        class="w-full appearance-none rounded-lg border border-slate-200 bg-white py-2 pr-9 pl-9 text-sm font-medium text-[var(--color-ink)] dark:border-slate-700 dark:bg-slate-900"
        :value="segment"
        @change="emit('update:segment', ($event.target as HTMLSelectElement).value as Segment)"
      >
        <option v-for="opt in SEGMENT_OPTIONS" :key="opt.id" :value="opt.id">
          {{ opt.label }}
        </option>
      </select>
      <ChevronDown
        :size="16"
        class="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-slate-400"
      />
    </div>
  </section>
</template>
