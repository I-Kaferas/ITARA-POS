<script setup lang="ts">
import { computed, ref } from 'vue'
import AppHeader from '@/components/AppHeader.vue'
import FiltersBar from '@/components/FiltersBar.vue'
import KpiCards from '@/components/KpiCards.vue'
import RevenueChart from '@/components/RevenueChart.vue'
import PaymentsChart from '@/components/PaymentsChart.vue'
import CategoriesChart from '@/components/CategoriesChart.vue'
import SidebarStats from '@/components/SidebarStats.vue'
import TransactionsTable from '@/components/TransactionsTable.vue'
import { useDarkMode } from '@/composables/useDarkMode'
import { generateDashboard, type DateRange, type SegmentFilter } from '@/lib/data'

const { isDark, toggle } = useDarkMode()
const dateRange = ref<DateRange>('30d')
const segment = ref<SegmentFilter>('all')
const filtersOpen = ref(false)

const dashboard = computed(() => generateDashboard(dateRange.value, segment.value))
</script>

<template>
  <div class="min-h-screen bg-page text-ink">
    <AppHeader
      :is-dark="isDark"
      :filters-open="filtersOpen"
      @toggle-dark="toggle"
      @toggle-filters="filtersOpen = !filtersOpen"
    />

    <main class="mx-auto max-w-[1600px] px-4 py-6 sm:px-6 lg:px-8">
      <div class="mb-6">
        <h2 class="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Analytics Overview</h2>
        <p class="mt-1 text-sm text-muted">
          Unified commerce performance across retail, restaurants, hospitality, and e-commerce.
        </p>
      </div>

      <FiltersBar
        v-model:date-range="dateRange"
        v-model:segment="segment"
        :open="filtersOpen"
      />

      <KpiCards :kpis="dashboard.kpis" />

      <div class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <RevenueChart :data="dashboard.revenueTrend" :is-dark="isDark" />
        <PaymentsChart :data="dashboard.payments" />
      </div>

      <div class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <CategoriesChart :data="dashboard.categories" :is-dark="isDark" />
        <SidebarStats
          :processing-volume="dashboard.processingVolume"
          :refunds="dashboard.refunds"
          :refund-rate="dashboard.refundRate"
          :locations="dashboard.locations"
        />
      </div>

      <TransactionsTable :transactions="dashboard.transactions" />

      <footer class="mt-8 border-t border-border pt-6 text-center text-xs text-muted">
        © 2026 ITARA NEXUS • Unified Commerce Platform • All data in this demo is simulated.
      </footer>
    </main>
  </div>
</template>
