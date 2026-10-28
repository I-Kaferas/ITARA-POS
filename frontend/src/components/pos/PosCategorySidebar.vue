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
  <div class="pos-cats">
    <div
      v-if="loading"
      class="pos-cats__row"
      role="status"
      :aria-label="t('common.loading')"
    >
      <span
        v-for="i in 5"
        :key="i"
        class="pos-cats__pill pos-cats__pill--skel ui-skeleton"
        aria-hidden="true"
      />
    </div>
    <div v-else class="pos-cats__row" role="tablist" :aria-label="t('pos.categories')">
      <button
        type="button"
        role="tab"
        class="pos-cats__pill"
        :class="{ 'is-on': selectedCategoryId === null }"
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
        class="pos-cats__pill"
        :class="{ 'is-on': selectedCategoryId === category.id }"
        :aria-selected="selectedCategoryId === category.id"
        @click="emit('select', category.id)"
      >
        {{ category.name }} ({{ counts?.[category.id] ?? 0 }})
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
  flex-wrap: wrap;
  align-items: center;
  gap: 0.55rem;
  padding: 0.1rem 0 0.2rem;
}

.pos-cats__pill {
  flex: 0 0 auto;
  border: 0;
  border-radius: 999px;
  background: #e7edf4;
  color: #3c4a5c;
  padding: 0.48rem 0.95rem;
  font-size: 0.92rem;
  font-weight: 600;
  line-height: 1.2;
  letter-spacing: -0.01em;
  white-space: nowrap;
  cursor: pointer;
  transition: background-color 160ms ease, color 160ms ease;
}

.pos-cats__pill:hover:not(.is-on) {
  background: #dde4ee;
  color: #1e293b;
}

.pos-cats__pill:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-surface, #fff), 0 0 0 4px #2f6bff;
}

.pos-cats__pill.is-on {
  background: #2f6bff;
  color: #fff;
}

.pos-cats__pill.is-on:hover {
  background: #245fe8;
}

.pos-cats__pill--skel {
  width: 7.5rem;
  height: 2.15rem;
  pointer-events: none;
}

html[data-theme="dark"] .pos-cats__pill:not(.is-on) {
  background: rgba(255, 255, 255, 0.08);
  color: var(--color-text-secondary, #cbd5e1);
}

html[data-theme="dark"] .pos-cats__pill:hover:not(.is-on) {
  background: rgba(255, 255, 255, 0.14);
  color: #fff;
}

@media (max-width: 900px) {
  .pos-cats__row {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 0.45rem;
    scrollbar-width: thin;
  }

  .pos-cats__pill {
    min-height: 2.35rem;
    padding: 0.5rem 1rem;
    font-size: 0.95rem;
  }
}
</style>
