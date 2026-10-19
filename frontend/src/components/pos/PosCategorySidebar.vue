<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import type { PosCategory } from '../../types/pos'

defineProps<{
  categories: PosCategory[]
  selectedCategoryId: string | null
  allLabel: string
  counts?: Record<string, number>
  totalCount?: number
  loading?: boolean
}>()

const emit = defineEmits<{
  select: [categoryId: string | null]
}>()

const { t } = useI18n()

const CATEGORY_ICONS = [
  'products',
  'coffee',
  'catering',
  'package',
  'layers',
  'fridge',
  'sparkles',
  'tag',
  'inventory',
  'coins',
] as const

function iconFor(index: number) {
  return CATEGORY_ICONS[index % CATEGORY_ICONS.length]
}
</script>

<template>
  <div class="pos-cats">
    <div
      v-if="loading"
      class="pos-cats__row"
      role="status"
      :aria-label="t('common.loading')"
    >
      <span
        v-for="i in 6"
        :key="i"
        class="pos-cats__tile pos-cats__tile--skel ui-skeleton"
        aria-hidden="true"
      />
    </div>
    <div v-else class="pos-cats__row" role="tablist" :aria-label="t('pos.categories')">
      <button
        type="button"
        role="tab"
        class="pos-cats__tile"
        :class="{ 'pos-cats__tile--active': selectedCategoryId === null }"
        :aria-selected="selectedCategoryId === null"
        @click="emit('select', null)"
      >
        <span class="pos-cats__icon">
          <AppIcon name="menu" :size="20" />
        </span>
        <span class="pos-cats__label">{{ allLabel }}</span>
        <span class="pos-cats__count">{{ totalCount ?? 0 }}</span>
      </button>
      <button
        v-for="(category, index) in categories"
        :key="category.id"
        type="button"
        role="tab"
        class="pos-cats__tile"
        :class="{ 'pos-cats__tile--active': selectedCategoryId === category.id }"
        :aria-selected="selectedCategoryId === category.id"
        @click="emit('select', category.id)"
      >
        <span class="pos-cats__icon">
          <AppIcon :name="iconFor(index)" :size="20" />
        </span>
        <span class="pos-cats__label">{{ category.name }}</span>
        <span class="pos-cats__count">{{ counts?.[category.id] ?? 0 }}</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.pos-cats {
  min-width: 0;
}

.pos-cats__row {
  display: flex;
  flex-wrap: nowrap;
  gap: 0.65rem;
  overflow-x: auto;
  padding: 0.15rem 0.1rem 0.35rem;
  scrollbar-width: thin;
}

.pos-cats__tile {
  flex: 0 0 auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.4rem;
  min-width: 4.6rem;
  max-width: 5.6rem;
  padding: 0.7rem 0.55rem 0.55rem;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 14px;
  background: var(--color-surface, #fff);
  color: var(--color-text-secondary);
  cursor: pointer;
  box-shadow: 0 1px 2px rgba(18, 36, 60, 0.04);
  transition:
    background 160ms ease,
    border-color 160ms ease,
    color 160ms ease,
    transform 160ms ease;
}

.pos-cats__tile:hover {
  border-color: color-mix(in srgb, var(--color-brand-600, #12243c) 28%, var(--color-border));
  color: var(--color-text-primary);
  transform: translateY(-1px);
}

.pos-cats__tile:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-surface), 0 0 0 4px var(--color-focus-ring, #e39b2b);
}

.pos-cats__tile--skel {
  width: 4.8rem;
  height: 5.1rem;
  pointer-events: none;
  border: 0;
}

.pos-cats__tile--active {
  background: var(--color-brand-600, #12243c);
  border-color: var(--color-brand-600, #12243c);
  color: #fff;
  box-shadow: 0 8px 18px rgba(18, 36, 60, 0.18);
}

.pos-cats__icon {
  display: grid;
  place-items: center;
  width: 2.35rem;
  height: 2.35rem;
  border-radius: 11px;
  background: color-mix(in srgb, var(--color-brand-600, #12243c) 8%, var(--color-canvas, #eef1f5));
  color: var(--color-brand-600, #12243c);
}

.pos-cats__tile--active .pos-cats__icon {
  background: color-mix(in srgb, #fff 18%, transparent);
  color: #fff;
}

.pos-cats__label {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  line-height: 1.2;
  text-align: center;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.pos-cats__count {
  font-size: 0.65rem;
  font-weight: 600;
  opacity: 0.7;
}
</style>
