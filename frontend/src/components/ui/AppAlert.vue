<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from './AppIcon.vue'

const props = withDefaults(defineProps<{
  tone?: 'info' | 'success' | 'warning' | 'danger'
  title?: string
  dismissible?: boolean
}>(), {
  tone: 'info',
  dismissible: false,
})

const emit = defineEmits<{ dismiss: [] }>()
const { t } = useI18n()

const icon = computed(() => {
  if (props.tone === 'success') return 'check'
  if (props.tone === 'warning' || props.tone === 'danger') return 'alert'
  return 'info'
})
</script>

<template>
  <div
    class="ui-alert"
    :class="`ui-alert--${tone}`"
    :role="tone === 'danger' || tone === 'warning' ? 'alert' : 'status'"
  >
    <AppIcon :name="icon" :size="18" />
    <div class="ui-alert__copy">
      <p v-if="title" class="ui-alert__title">{{ title }}</p>
      <div class="ui-alert__body">
        <slot />
      </div>
    </div>
    <button
      v-if="dismissible"
      type="button"
      class="ui-alert__close"
      :aria-label="t('common.close')"
      @click="emit('dismiss')"
    >
      ×
    </button>
  </div>
</template>
