<script setup lang="ts">
import { useI18n } from 'vue-i18n'
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
</script>

<template>
  <div
    v-if="loading"
    class="pos-cat-tabs"
    role="status"
    :aria-label="t('common.loading')"
  >
    <span
      v-for="i in 5"
      :key="i"
      class="pos-cat-tabs__chip pos-cat-tabs__chip--skel ui-skeleton"
      :style="{ width: `${5.2 + (i % 3) * 1.1}rem` }"
      aria-hidden="true"
    />
  </div>
  <div v-else class="pos-cat-tabs" role="tablist" :aria-label="t('pos.categories')">
    <button
      type="button"
      role="tab"
      class="pos-cat-tabs__chip"
      :class="{ 'pos-cat-tabs__chip--active': selectedCategoryId === null }"
      :aria-selected="selectedCategoryId === null"
      @click="emit('select', null)"
    >
      {{ allLabel }} ({{ totalCount ?? 0 }})
    </button>
    <button
      v-for="category in categories"
      :key="category.id"
      type="button"
      role="tab"
      class="pos-cat-tabs__chip"
      :class="{ 'pos-cat-tabs__chip--active': selectedCategoryId === category.id }"
      :aria-selected="selectedCategoryId === category.id"
      @click="emit('select', category.id)"
    >
      {{ category.name }} ({{ counts?.[category.id] ?? 0 }})
    </button>
  </div>
</template>

<style scoped>
.pos-cat-tabs {
  display: flex;
  flex-wrap: nowrap;
  gap: 0.5rem;
  overflow-x: auto;
  padding: 0.15rem 0 0.35rem;
  scrollbar-width: thin;
}

.pos-cat-tabs__chip {
  flex-shrink: 0;
  border: 1px solid transparent;
  border-radius: 999px;
  background: #eef1f5;
  color: var(--color-text-secondary);
  padding: 0.45rem 0.95rem;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    background var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out);
}

.pos-cat-tabs__chip:hover {
  background: #e4e8ef;
  color: var(--color-brand-700);
}

.pos-cat-tabs__chip--skel {
  pointer-events: none;
  height: 2.15rem;
  border: 0;
}

.pos-cat-tabs__chip--active {
  background: var(--color-brand-600);
  border-color: var(--color-brand-600);
  color: #fff;
  box-shadow: 0 6px 14px color-mix(in srgb, var(--color-brand-600) 28%, transparent);
}
</style>
