<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from './AppIcon.vue'

const open = ref(true)
const { t } = useI18n()
</script>

<template>
  <div class="filter-fold" :class="{ 'is-open': open }">
    <button type="button" class="filter-fold__toggle" :aria-expanded="open" @click="open = !open">
      <AppIcon name="filter" :size="15" />
      {{ open ? t('filters.hide') : t('filters.show') }}
    </button>
    <div class="fold-panel" :class="{ 'is-open': open }">
      <div class="fold-panel__body" :inert="!open">
        <slot />
      </div>
    </div>
  </div>
</template>

<style scoped>
.filter-fold {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.75rem;
  width: fit-content;
  max-width: 100%;
  min-width: 0;
}
.filter-fold__toggle {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  height: 2rem;
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 8px;
  padding: 0 0.75rem;
  background: var(--color-brand-50, #f4f7fb);
  color: var(--color-ink-brand, var(--color-brand-700, #1e3a5f));
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  align-self: flex-end;
}
.filter-fold :deep(.fold-panel) {
  width: 100%;
  max-width: 100%;
}
.filter-fold :deep(.fold-panel__body) {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(11.5rem, 1fr));
  align-items: end;
  gap: 0.75rem 1rem;
  width: 100%;
}
.filter-fold__body {
  width: 100%;
}
</style>
