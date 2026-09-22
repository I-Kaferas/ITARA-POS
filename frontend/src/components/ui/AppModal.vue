<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from './AppIcon.vue'

const props = withDefaults(defineProps<{
  open: boolean
  title: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  closeOnBackdrop?: boolean
  icon?: string
  tone?: 'brand' | 'danger' | 'warning' | 'success' | 'accent' | 'info'
}>(), {
  size: 'lg',
  closeOnBackdrop: true,
  icon: 'layers',
  tone: 'brand',
})

const emit = defineEmits<{
  close: []
}>()

const { t } = useI18n()
const panel = ref<HTMLElement | null>(null)
const sheet = ref(false)

const toneClass = computed(() => `app-modal--${props.tone}`)

watch(
  () => [props.open, props.size] as const,
  async ([open]) => {
    sheet.value = props.size === 'xl'
    if (!open) return
    await nextTick()
    const form = panel.value?.querySelector('form')
    if (!form) return
    const fields = form.querySelectorAll('input:not([type="hidden"]):not([type="radio"]):not([type="checkbox"]), select, textarea')
    const dense = Boolean(form.querySelector('.line-row, table, .choice-grid, .choice-row, .device-panel'))
    if (fields.length >= 4 || dense) sheet.value = true
  },
  { immediate: true },
)

function close() {
  emit('close')
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="app-modal-backdrop"
      @mousedown.self="closeOnBackdrop && close()"
    >
      <div
        ref="panel"
        class="app-modal"
        :class="[`app-modal--${size}`, toneClass, { 'app-modal--sheet': sheet }]"
        role="dialog"
        aria-modal="true"
        @mousedown.stop
      >
        <div class="app-modal__header">
          <div class="app-modal__heading">
            <span class="app-modal__mark">
              <AppIcon :name="icon" :size="18" />
            </span>
            <h3 class="app-modal__title">{{ title }}</h3>
          </div>
          <button
            type="button"
            class="app-modal__close"
            :aria-label="t('common.cancel')"
            @click="close"
          >
            ×
          </button>
        </div>

        <div class="app-modal__body">
          <slot />
        </div>

        <div v-if="$slots.footer" class="app-modal__footer">
          <slot name="footer" />
        </div>
      </div>
    </div>
  </Teleport>
</template>
