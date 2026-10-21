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

function go(next: number) {
  if (next < 1 || next > props.lastPage || next === props.page) return
  emit('change', next)
}
</script>

<template>
  <nav v-if="lastPage > 1" class="list-pager" :aria-label="t('common.pagination')">
    <span>{{ t('common.showing', { from, to, total }) }}</span>
    <div class="list-pager__nav">
      <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" :disabled="page <= 1" @click="go(page - 1)">
        {{ t('common.previous') }}
      </button>
      <span class="list-pager__index">{{ page }} / {{ lastPage }}</span>
      <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" :disabled="page >= lastPage" @click="go(page + 1)">
        {{ t('common.next') }}
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
  margin-top: 0.75rem;
  padding: 0.65rem 0.15rem 0.15rem;
  color: var(--color-text-muted, #667085);
  font-size: 0.8rem;
}

.list-pager :deep(.ui-btn--sm) {
  min-height: 2rem;
  padding: 0.3rem 0.7rem;
  font-size: 0.75rem;
}
.list-pager__nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.list-pager__index {
  min-width: 3.5rem;
  text-align: center;
  font-weight: 600;
  color: var(--color-text-primary, #12243c);
}
</style>
