<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import HotelAmenitiesPanel from './HotelAmenitiesPanel.vue'
import HotelChrome from './HotelChrome.vue'

const { t } = useI18n()
const route = useRoute()

const isAmenities = computed(() => route.path.startsWith('/admin/hotel/room-config/amenities'))
</script>

<template>
  <HotelChrome>
    <HotelAmenitiesPanel v-if="isAmenities" />
    <div v-else class="hotel-panel">
      <p class="hotel-panel__hint">{{ t('hotel.comingSoon') }}</p>
    </div>
  </HotelChrome>
</template>

<style scoped>
.hotel-panel {
  margin-top: 1rem;
  padding: 1.5rem;
  border: 1px solid var(--color-border, #e4e8ec);
  border-radius: 0.85rem;
  background: #fff;
}

.hotel-panel__hint {
  margin: 0;
  font-size: 0.9rem;
  color: #66727c;
}
</style>
