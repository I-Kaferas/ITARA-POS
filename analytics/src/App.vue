<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppHeader from '@/components/AppHeader.vue'
import FilterBar from '@/components/FilterBar.vue'
import KpiCards from '@/components/KpiCards.vue'
import RevenueChart from '@/components/RevenueChart.vue'
import PaymentDonut from '@/components/PaymentDonut.vue'
import CategoryBars from '@/components/CategoryBars.vue'
import SidebarStats from '@/components/SidebarStats.vue'
import TransactionsTable from '@/components/TransactionsTable.vue'
import AppFooter from '@/components/AppFooter.vue'
import { generateDashboard, type DateRange, type Segment } from '@/lib/data'
import { useDarkMode } from '@/composables/useDarkMode'

const { dark, toggle } = useDarkMode()
const dateRange = ref<DateRange>('30d')
const segment = ref<Segment>('all')
const filtersOpen = ref(false)
const isSmUp = ref(true)

function syncViewport() {
  isSmUp.value = window.matchMedia('(min-width: 640px)').matches
  if (isSmUp.value) filtersOpen.value = true
}

onMounted(() => {
  syncViewport()
  window.addEventListener('resize', syncViewport)
  if (!isSmUp.value) filtersOpen.value = false
  else filtersOpen.value = true
})

const data = computed(() => generateDashboard(dateRange.value, segment.value))

const filtersVisible = computed(() => isSmUp.value || filtersOpen.value)
</script>

<template>
  <div class="min-h-screen bg-[var(--color-page)] text-[var(--color-ink)]">
    <AppHeader
      :dark="dark"
      :filters-open="filtersOpen"
      @toggle-dark="toggle"
      @toggle-filters="filtersOpen = !filtersOpen"
    />

    <main class="mx-auto max-w-[1600px] px-4 py-6 sm:px-6 lg:px-8">
      <div class="mb-6">
        <h2 class="text-2xl font-bold tracking-tight text-[var(--color-ink)] sm:text-3xl">
          Analytics Overview
        </h2>
        <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Multi-segment commerce performance across retail, restaurants, hospitality, and
          e-commerce.
        </p>
      </div>

      <FilterBar
        v-model:date-range="dateRange"
        v-model:segment="segment"
        :visible="filtersVisible"
      />

      <KpiCards :kpis="data.kpis" />

      <section class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <RevenueChart :series="data.revenueTrend" />
        <PaymentDonut :payments="data.payments" />
      </section>

      <section class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <CategoryBars :categories="data.categories" />
        <SidebarStats
          :processing-volume="data.processingVolume"
          :refunds="data.refunds"
          :refund-rate="data.refundRate"
          :locations="data.locations"
        />
      </section>

      <TransactionsTable :transactions="data.transactions" />
      <AppFooter />
    </main>
  </div>
</template>
