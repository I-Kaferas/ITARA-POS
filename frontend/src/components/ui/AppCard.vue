<script setup lang="ts">
withDefaults(defineProps<{
  title?: string
  description?: string
  elevated?: boolean
  compact?: boolean
}>(), {
  elevated: false,
  compact: false,
})
</script>

<template>
  <section
    class="ui-card"
    :class="{ 'ui-card--elevated': elevated, 'ui-card--compact': compact && !$slots.header && !title }"
  >
    <header v-if="title || $slots.actions" class="ui-card__header">
      <div>
        <h3 v-if="title" class="ui-card__title">{{ title }}</h3>
        <p v-if="description" class="ui-card__desc">{{ description }}</p>
      </div>
      <div v-if="$slots.actions" class="ui-cluster">
        <slot name="actions" />
      </div>
    </header>
    <div class="ui-card__body">
      <slot />
    </div>
  </section>
</template>
