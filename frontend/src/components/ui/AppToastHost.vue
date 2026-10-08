<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import AppIcon from './AppIcon.vue'
import { useToast, type ToastTone } from '../../composables/useToast'

const { t } = useI18n()
const { toasts, dismiss } = useToast()

function icon(tone: ToastTone) {
  if (tone === 'success') return 'check'
  if (tone === 'warning' || tone === 'danger') return 'alert'
  return 'info'
}
</script>

<template>
  <Teleport to="body">
    <div class="ui-toast-host" aria-live="polite" aria-relevant="additions">
      <TransitionGroup name="toast">
        <div
          v-for="toast in toasts"
          :key="toast.id"
          class="ui-toast"
          :class="`ui-toast--${toast.tone}`"
          role="status"
        >
          <AppIcon :name="icon(toast.tone)" :size="18" />
          <div class="ui-toast__copy">
            <p v-if="toast.title" class="ui-toast__title">{{ toast.title }}</p>
            <p class="ui-toast__message">{{ toast.message }}</p>
          </div>
          <button
            type="button"
            class="ui-toast__close"
            :aria-label="t('common.close')"
            @click="dismiss(toast.id)"
          >
            ×
          </button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>
