<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../../components/ui/AppIcon.vue'
import HotelDashboardView from './hotel/HotelDashboardView.vue'
import HotelStockDashboardView from './hotel/HotelStockDashboardView.vue'

const { t } = useI18n()
const tab = ref<'hotel' | 'stock'>('hotel')
</script>

<template>
  <div class="home">
    <div class="home-switch" role="tablist">
      <button
        type="button"
        role="tab"
        :class="{ 'is-on': tab === 'hotel' }"
        :aria-selected="tab === 'hotel'"
        @click="tab = 'hotel'"
      >
        <AppIcon name="bed" :size="16" />
        {{ t('nav.hotel') }}
      </button>
      <button
        type="button"
        role="tab"
        :class="{ 'is-on': tab === 'stock' }"
        :aria-selected="tab === 'stock'"
        @click="tab = 'stock'"
      >
        <AppIcon name="inventory" :size="16" />
        {{ t('hotel.tabs.stock') }}
      </button>
    </div>

    <HotelDashboardView v-if="tab === 'hotel'" variant="home" />
    <HotelStockDashboardView v-else variant="home" />
  </div>
</template>

<style scoped>
.home {
  display: flex;
  flex-direction: column;
  gap: 1.15rem;
  width: 100%;
}

.home-switch {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  width: fit-content;
  padding: 0.28rem;
  border-radius: 14px;
  background: #eef2f7;
}

.home-switch button {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  height: 36px;
  padding: 0 0.9rem;
  border: 0;
  border-radius: 11px;
  background: transparent;
  color: #64748b;
  font-size: 0.92rem;
  font-weight: 700;
  cursor: pointer;
}

.home-switch button.is-on {
  background: #fff;
  color: #2563eb;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
}
</style>
