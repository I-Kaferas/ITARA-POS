<script setup lang="ts">
import EmptyState from './EmptyState.vue'
import LoadingBlock from './LoadingBlock.vue'

withDefaults(defineProps<{
  title?: string
  meta?: string
  loading?: boolean
  empty?: boolean
  emptyTitle?: string
  emptyDescription?: string
  emptyIcon?: string
  loadingLabel?: string
}>(), {
  loading: false,
  empty: false,
  emptyTitle: '',
  emptyDescription: '',
  emptyIcon: 'package',
})
</script>

<template>
  <section class="ui-table-wrap">
    <div v-if="title || meta || $slots.toolbar" class="ui-table-wrap__header">
      <div>
        <h3 v-if="title" class="ui-table-wrap__title">{{ title }}</h3>
        <p v-if="meta" class="ui-table-wrap__meta m-0 mt-0.5">{{ meta }}</p>
      </div>
      <div v-if="$slots.toolbar" class="flex flex-wrap items-center gap-2">
        <slot name="toolbar" />
      </div>
    </div>

    <LoadingBlock v-if="loading" :label="loadingLabel" />

    <EmptyState
      v-else-if="empty"
      :icon="emptyIcon"
      :title="emptyTitle || '—'"
      :description="emptyDescription"
    >
      <div v-if="$slots.emptyActions" class="empty-state__actions">
        <slot name="emptyActions" />
      </div>
    </EmptyState>

    <div v-else class="overflow-x-auto">
      <slot />
    </div>
  </section>
</template>
