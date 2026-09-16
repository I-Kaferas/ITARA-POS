<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import type { PosCategory } from '../../types/pos'

defineProps<{
  categories: PosCategory[]
  selectedCategoryId: string | null
  allLabel: string
  counts?: Record<string, number>
  totalCount?: number
}>()

const emit = defineEmits<{
  select: [categoryId: string | null]
}>()

const { t } = useI18n()
</script>

<template>
  <aside class="pos-categories">
    <p class="pos-categories__heading">{{ t('pos.categories') }}</p>
    <button
      class="pos-categories__item"
      :class="{ 'pos-categories__item--active': selectedCategoryId === null }"
      @click="emit('select', null)"
    >
      <span>{{ allLabel }}</span>
      <span class="pos-categories__count">{{ totalCount ?? 0 }}</span>
    </button>
    <button
      v-for="category in categories"
      :key="category.id"
      class="pos-categories__item"
      :class="{ 'pos-categories__item--active': selectedCategoryId === category.id }"
      @click="emit('select', category.id)"
    >
      <span :style="{ paddingLeft: `${(category.depth ?? 0) * 0.7}rem` }">{{ category.name }}</span>
      <span class="pos-categories__count">{{ counts?.[category.id] ?? 0 }}</span>
    </button>
  </aside>
</template>

<style scoped>
.pos-categories {
  width: 13.5rem;
  flex-shrink: 0;
  align-self: stretch;
  min-height: 0;
  overflow-y: auto;
  background: #f8fafc;
  border-right: 1px solid #e7edf3;
  padding: 0.85rem 0.65rem;
}

.pos-categories__heading {
  margin: 0 0.35rem 0.55rem;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #94a3b8;
}

.pos-categories__item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  width: 100%;
  text-align: left;
  padding: 0.55rem 0.7rem;
  margin-bottom: 0.2rem;
  border-radius: 0.7rem;
  font-size: 0.8125rem;
  color: #334155;
  border: 1px solid transparent;
  background: transparent;
  cursor: pointer;
}

.pos-categories__item span:first-child {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pos-categories__item:hover {
  background: #fff;
  border-color: #e2e8f0;
}

.pos-categories__item--active {
  background: var(--color-brand-600, #4a6d86);
  color: white;
  font-weight: 650;
  box-shadow: 0 8px 16px rgba(74, 109, 134, 0.22);
}

.pos-categories__count {
  flex-shrink: 0;
  min-width: 1.35rem;
  text-align: center;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 0.1rem 0.35rem;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
}

.pos-categories__item--active .pos-categories__count {
  background: rgba(255, 255, 255, 0.18);
}

@media (max-width: 1279px) {
  .pos-categories {
    width: 100%;
    flex: 0 0 100%;
    display: flex;
    flex-direction: row;
    flex-wrap: nowrap;
    align-items: center;
    gap: 0.3rem;
    overflow-x: auto;
    overflow-y: hidden;
    min-height: unset;
    border-right: 0;
    border-bottom: 1px solid #e7edf3;
    padding: 0.45rem 0.55rem;
    background: #fff;
  }

  .pos-categories__heading {
    display: none;
  }

  .pos-categories__item {
    flex: 0 0 auto;
    width: auto;
    margin-bottom: 0;
    white-space: nowrap;
    background: #f8fafc;
    border-color: #e7edf3;
  }

  .pos-categories__item--active {
    background: var(--color-brand-600, #4a6d86);
    color: #fff;
    border-color: var(--color-brand-600, #4a6d86);
  }
}
</style>
