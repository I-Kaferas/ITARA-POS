<script setup lang="ts">
withDefaults(defineProps<{
  rows?: number
  label?: string
  variant?: 'list' | 'table' | 'cards' | 'detail'
}>(), {
  rows: 6,
  variant: 'list',
})
</script>

<template>
  <div
    class="ui-skeleton-block"
    :class="`ui-skeleton-block--${variant}`"
    role="status"
    aria-live="polite"
  >
    <span v-if="label" class="sr-only">{{ label }}</span>

    <div v-if="variant === 'list'" class="ui-skeleton-stack">
      <div
        v-for="i in rows"
        :key="i"
        class="ui-skeleton-line"
      >
        <span class="ui-skeleton ui-skeleton--circle" style="width: 28px; height: 28px" />
        <div class="ui-skeleton-line__text">
          <span class="ui-skeleton ui-skeleton--md" :style="{ width: `${58 + (i % 3) * 12}%` }" />
          <span class="ui-skeleton ui-skeleton--sm" :style="{ width: `${38 + (i % 4) * 10}%` }" />
        </div>
      </div>
    </div>

    <div v-else-if="variant === 'table'" class="ui-skeleton-table">
      <div class="ui-skeleton-table__head">
        <span v-for="i in 6" :key="i" class="ui-skeleton ui-skeleton--sm" :style="{ width: `${10 + (i % 3) * 6}%` }" />
      </div>
      <div
        v-for="i in rows"
        :key="i"
        class="ui-skeleton-table__row"
      >
        <span class="ui-skeleton ui-skeleton--circle" style="width: 32px; height: 32px" />
        <span class="ui-skeleton ui-skeleton--md" :style="{ width: `${22 + (i % 4) * 4}%` }" />
        <span class="ui-skeleton ui-skeleton--sm" :style="{ width: `${14 + (i % 3) * 3}%` }" />
        <span class="ui-skeleton ui-skeleton--sm" :style="{ width: `${10 + (i % 5) * 2}%` }" />
        <span class="ui-skeleton ui-skeleton--md" style="width: 12%; margin-left: auto" />
      </div>
    </div>

    <div v-else-if="variant === 'cards'" class="ui-skeleton-cards">
      <div
        v-for="i in rows"
        :key="i"
        class="ui-skeleton-card"
      >
        <span class="ui-skeleton ui-skeleton--thumb" />
        <span class="ui-skeleton ui-skeleton--md" :style="{ width: `${62 + (i % 3) * 10}%` }" />
        <span class="ui-skeleton ui-skeleton--sm" :style="{ width: `${36 + (i % 4) * 8}%` }" />
      </div>
    </div>

    <div v-else class="ui-skeleton-detail">
      <span class="ui-skeleton ui-skeleton--xl" style="width: 42%" />
      <span class="ui-skeleton ui-skeleton--sm" style="width: 28%" />
      <div class="ui-skeleton-detail__grid">
        <span v-for="i in 6" :key="i" class="ui-skeleton ui-skeleton--lg" />
      </div>
      <span
        v-for="i in rows"
        :key="`d-${i}`"
        class="ui-skeleton ui-skeleton--md"
        :style="{ width: `${70 - (i % 4) * 8}%` }"
      />
    </div>
  </div>
</template>

<style scoped>
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.ui-skeleton-block {
  width: 100%;
}

.ui-skeleton-stack {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  padding: 0.35rem 0;
}

.ui-skeleton-line {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.ui-skeleton-line__text {
  min-width: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.ui-skeleton-table {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  padding: 0.5rem 0;
}

.ui-skeleton-table__head,
.ui-skeleton-table__row {
  display: flex;
  align-items: center;
  gap: 0.85rem;
}

.ui-skeleton-table__head {
  padding-bottom: 0.4rem;
  border-bottom: 1px solid var(--color-border, #e7edf3);
  opacity: 0.7;
}

.ui-skeleton-table__row {
  min-height: 2.4rem;
}

.ui-skeleton-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(11.5rem, 1fr));
  gap: 0.85rem;
}

.ui-skeleton-card {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  padding: 0.75rem;
  border: 1px solid var(--color-border, #e7edf3);
  border-radius: 0.85rem;
  background: #fff;
}

.ui-skeleton-detail {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 0.5rem 0 1rem;
}

.ui-skeleton-detail__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(8rem, 1fr));
  gap: 0.75rem;
  margin: 0.5rem 0 0.75rem;
}
</style>
