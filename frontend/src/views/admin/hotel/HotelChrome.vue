<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import SubNav from '../../../components/ui/SubNav.vue'

const props = withDefaults(defineProps<{
  /** Allow the page body to grow and scroll with app-content (e.g. reservations list). */
  scrollBody?: boolean
}>(), {
  scrollBody: false,
})

const { t } = useI18n()
const route = useRoute()

function isPathActive(path: string) {
  return route.path === path || route.path.startsWith(`${path}/`)
}

const tabs = computed(() => [
  { to: '/admin/hotel/room-config', label: t('hotel.tabs.roomConfig') },
  { to: '/admin/hotel/rooms', label: t('hotel.tabs.rooms') },
  { to: '/admin/hotel/reservations', label: t('hotel.tabs.reservations') },
  { to: '/admin/hotel/stays', label: t('hotel.tabs.stays') },
  { to: '/admin/hotel/invoices', label: t('hotel.tabs.invoices') },
  { to: '/admin/hotel/guests', label: t('hotel.tabs.guests') },
  { to: '/admin/hotel/housekeeping', label: t('hotel.tabs.housekeeping') },
  { to: '/admin/hotel/calendar', label: t('hotel.tabs.calendar') },
  { to: '/admin/hotel/concierge', label: t('hotel.tabs.concierge') },
  { to: '/admin/hotel/reports', label: t('hotel.tabs.reports') },
  { to: '/admin/hotel/settings', label: t('hotel.tabs.settings') },
].map(tab => ({
  to: tab.to,
  label: tab.label,
  active: isPathActive(tab.to),
})))

const isRoomConfig = computed(() => isPathActive('/admin/hotel/room-config'))
const allowScroll = computed(() => props.scrollBody || isRoomConfig.value)

const roomConfigTabs = computed(() => [
  { to: '/admin/hotel/room-config/amenities', label: t('hotel.roomConfig.amenities') },
  { to: '/admin/hotel/room-config/room-types', label: t('hotel.roomConfig.roomTypes') },
  { to: '/admin/hotel/room-config/buildings', label: t('hotel.roomConfig.buildings') },
  { to: '/admin/hotel/room-config/wings', label: t('hotel.roomConfig.wings') },
  { to: '/admin/hotel/room-config/floors', label: t('hotel.roomConfig.floors') },
].map(tab => ({
  to: tab.to,
  label: tab.label,
  active: isPathActive(tab.to),
})))

const title = computed(() => {
  const subTab = roomConfigTabs.value.find(tab => tab.active)
  if (subTab) return subTab.label
  return tabs.value.find(tab => tab.active)?.label ?? t('nav.hotel')
})
</script>

<template>
  <AdminLayout>
    <template #title>{{ title }}</template>
    <template #subtitle>{{ t('hotel.subtitle') }}</template>

    <div class="hotel-page" :class="{ 'hotel-page--scroll': allowScroll }">
      <div class="hotel-navs">
        <SubNav :tabs="tabs" />
        <SubNav v-if="isRoomConfig" :tabs="roomConfigTabs" variant="secondary" />
      </div>
      <div class="hotel-page__body">
        <slot />
      </div>
    </div>
  </AdminLayout>
</template>

<style scoped>
.hotel-page {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  min-height: 0;
}

.hotel-navs {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  flex-shrink: 0;
}

.hotel-navs :deep(.sub-nav) {
  margin-bottom: 0;
}

.hotel-navs :deep(.sub-nav--secondary) {
  margin-top: 0;
}

.hotel-page__body {
  min-height: 0;
}

@media (min-width: 960px) {
  .hotel-page {
    height: 100%;
    overflow: hidden;
  }

  .hotel-page__body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .hotel-page__body > :deep(*) {
    flex: 1 1 0;
    min-height: 0;
  }

  .hotel-page--scroll {
    height: auto;
    min-height: 0;
    overflow: visible;
  }

  .hotel-page--scroll .hotel-page__body {
    flex: 0 0 auto;
    overflow: visible;
  }

  .hotel-page--scroll .hotel-page__body > :deep(*) {
    flex: 0 0 auto;
    min-height: auto;
  }
}
</style>
