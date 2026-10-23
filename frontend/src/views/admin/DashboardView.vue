<script setup lang="ts">
import { nextTick, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../../components/ui/AppIcon.vue'
import HotelDashboardView from './hotel/HotelDashboardView.vue'
import HotelStockDashboardView from './hotel/HotelStockDashboardView.vue'

type HomeTab = 'hotel' | 'stock'

const { t } = useI18n()
const tab = ref<HomeTab>('hotel')
const tabs: HomeTab[] = ['hotel', 'stock']
const tabRefs = ref<HTMLButtonElement[]>([])

async function onTabKey(event: KeyboardEvent) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = (tabs.indexOf(tab.value) + step + tabs.length) % tabs.length
  tab.value = tabs[next]
  await nextTick()
  tabRefs.value[next]?.focus()
}
</script>

<template>
  <div class="home">
    <div class="home-switch" role="tablist" :aria-label="t('nav.dashboard')" @keydown="onTabKey">
      <button
        v-for="key in tabs"
        :id="`home-tab-${key}`"
        :key="key"
        ref="tabRefs"
        type="button"
        role="tab"
        :class="{ 'is-on': tab === key }"
        :aria-selected="tab === key"
        :tabindex="tab === key ? 0 : -1"
        aria-controls="home-panel"
        @click="tab = key"
      >
        <AppIcon :name="key === 'hotel' ? 'bed' : 'inventory'" :size="18" />
        {{ key === 'hotel' ? t('nav.hotel') : t('hotel.tabs.stock') }}
      </button>
    </div>

    <div id="home-panel" role="tabpanel" :aria-labelledby="`home-tab-${tab}`">
      <Transition name="home-fade" mode="out-in">
        <HotelDashboardView v-if="tab === 'hotel'" key="hotel" variant="home" />
        <HotelStockDashboardView v-else key="stock" variant="home" />
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.home {
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
  width: 100%;
}

.home-switch {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  width: fit-content;
  max-width: 100%;
  padding: var(--space-1);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface-muted);
  box-shadow: inset 0 1px 2px rgba(15, 23, 42, 0.04);
}

.home-switch button {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  min-height: var(--touch-min);
  padding: 0 var(--space-4);
  border: 0;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
  font-weight: 600;
  cursor: pointer;
  transition:
    background-color var(--motion-normal) var(--ease-out),
    color var(--motion-normal) var(--ease-out),
    box-shadow var(--motion-normal) var(--ease-out);
}

.home-switch button:hover:not(.is-on) {
  background: rgba(255, 255, 255, 0.7);
  color: var(--color-text-primary);
}

.home-switch button.is-on {
  background: var(--color-surface);
  color: var(--color-ink-brand);
  box-shadow:
    0 1px 2px rgba(15, 23, 42, 0.06),
    0 2px 8px -2px rgba(15, 23, 42, 0.08),
    inset 0 -2px 0 var(--color-brand-600);
}

.home-switch button:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.home-fade-enter-active,
.home-fade-leave-active {
  transition:
    opacity var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.home-fade-enter-from {
  opacity: 0;
  transform: translateY(8px);
}

.home-fade-leave-to {
  opacity: 0;
}

html[data-theme="dark"] .home-switch button:hover:not(.is-on) {
  background: rgba(255, 255, 255, 0.06);
}

@media (prefers-reduced-motion: reduce) {
  .home-fade-enter-active,
  .home-fade-leave-active {
    transition: none;
  }
}
</style>
