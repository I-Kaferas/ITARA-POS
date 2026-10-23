<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  page: number
  lastPage: number
  total: number
  perPage: number
}>()

const emit = defineEmits<{
  change: [page: number]
}>()

const { t } = useI18n()

const from = computed(() => (props.total === 0 ? 0 : (props.page - 1) * props.perPage + 1))
const to = computed(() => Math.min(props.page * props.perPage, props.total))

/** First, last and the current page's neighbours; gaps collapse to an ellipsis. */
const items = computed<Array<number | 'gap'>>(() => {
  const last = props.lastPage
  const keep = new Set([1, last, props.page - 1, props.page, props.page + 1])
  const out: Array<number | 'gap'> = []
  for (let n = 1; n <= last; n++) {
    if (!keep.has(n)) continue
    const prev = out[out.length - 1]
    if (typeof prev === 'number' && n - prev === 2) out.push(n - 1)
    else if (typeof prev === 'number' && n - prev > 2) out.push('gap')
    out.push(n)
  }
  return out
})

function go(next: number) {
  if (next < 1 || next > props.lastPage || next === props.page) return
  emit('change', next)
}
</script>

<template>
  <nav v-if="lastPage > 1" class="list-pager" :aria-label="t('common.pagination')">
    <span class="list-pager__summary">{{ t('common.showing', { from, to, total }) }}</span>
    <div class="list-pager__nav">
      <button
        type="button"
        class="list-pager__btn"
        :disabled="page <= 1"
        :aria-label="t('common.previous')"
        :title="t('common.previous')"
        @click="go(page - 1)"
      >
        <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M12 5l-5 5 5 5" /></svg>
      </button>
      <template v-for="(item, i) in items" :key="item === 'gap' ? `gap-${i}` : item">
        <span v-if="item === 'gap'" class="list-pager__btn list-pager__btn--gap" aria-hidden="true">…</span>
        <button
          v-else
          type="button"
          class="list-pager__btn"
          :class="{ 'is-active': item === page }"
          :aria-current="item === page ? 'page' : undefined"
          @click="go(item)"
        >
          {{ item }}
        </button>
      </template>
      <button
        type="button"
        class="list-pager__btn"
        :disabled="page >= lastPage"
        :aria-label="t('common.next')"
        :title="t('common.next')"
        @click="go(page + 1)"
      >
        <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M8 5l5 5-5 5" /></svg>
      </button>
    </div>
  </nav>
</template>

<style scoped>
.list-pager {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.25rem 1rem 1rem;
  color: var(--color-text-muted, #667085);
  font-size: 0.8125rem;
}

.list-pager__nav {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.375rem;
}

.list-pager__btn {
  display: inline-grid;
  place-items: center;
  min-width: 2.125rem;
  height: 2.125rem;
  padding: 0 0.5rem;
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 999px;
  background: var(--color-surface, #fff);
  color: var(--color-text-secondary, #334155);
  font: inherit;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  line-height: 1;
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;
}

.list-pager__btn svg {
  width: 1rem;
  height: 1rem;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.list-pager__btn:hover:not(:disabled):not(.is-active):not(.list-pager__btn--gap) {
  border-color: var(--color-border-strong, #cbd5e1);
  background: var(--color-surface-muted, #f1f5f9);
  color: var(--color-text-primary, #0f172a);
}

.list-pager__btn.is-active {
  border-color: var(--color-brand-600, #12243c);
  background: var(--color-brand-600, #12243c);
  color: #fff;
  cursor: default;
}

.list-pager__btn:disabled {
  background: var(--color-surface-muted, #f1f5f9);
  color: var(--color-text-faint, #94a3b8);
  cursor: not-allowed;
}

.list-pager__btn--gap {
  color: var(--color-text-faint, #94a3b8);
  cursor: default;
}

html[data-theme="dark"] .list-pager__btn.is-active {
  border-color: var(--color-accent, #f5a524);
  background: var(--color-accent, #f5a524);
  color: #0f172a;
}
</style>
