<script lang="ts">
const modalStack: Array<() => void> = []
let bodyLocks = 0

function lockBody() {
  bodyLocks += 1
  document.body.style.overflow = 'hidden'
}

function unlockBody() {
  bodyLocks = Math.max(0, bodyLocks - 1)
  if (bodyLocks === 0) document.body.style.overflow = ''
}
</script>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, useId, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import AppIcon from './AppIcon.vue'
import { useConfirm } from '../../composables/useConfirm'

const props = withDefaults(defineProps<{
  open: boolean
  title: string
  subtitle?: string
  size?: 'sm' | 'md' | 'lg' | 'xl' | 'full'
  closeOnBackdrop?: boolean
  icon?: string
  tone?: 'brand' | 'danger' | 'warning' | 'success' | 'accent' | 'info'
  presentation?: 'auto' | 'dialog' | 'drawer'
  dirty?: boolean
  loading?: boolean
  error?: string
  elevated?: boolean
}>(), {
  subtitle: '',
  size: 'lg',
  closeOnBackdrop: true,
  icon: 'layers',
  tone: 'brand',
  presentation: 'auto',
  dirty: false,
  loading: false,
  error: '',
  elevated: false,
})

const emit = defineEmits<{
  close: []
  retry: []
}>()

const { t } = useI18n()
const route = useRoute()
const { confirm } = useConfirm()
const panel = ref<HTMLElement | null>(null)
const sheet = ref(false)
const titleId = useId()
const descId = useId()
const toneClass = computed(() => `app-modal--${props.tone}`)

const FOCUSABLE = 'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'

let previouslyFocused: HTMLElement | null = null
let held = false

const isDrawer = computed(() => {
  if (props.presentation === 'drawer') return true
  if (props.presentation === 'dialog') return false
  const admin = route.path.startsWith('/admin') && !route.path.startsWith('/admin/pos')
  if (!admin || props.size === 'sm' || props.size === 'md' || props.size === 'lg') return false
  return true
})

watch(
  () => [props.open, props.size] as const,
  async ([open]) => {
    sheet.value = props.size === 'xl' || props.size === 'full'
    if (!open) return
    await nextTick()
    const form = panel.value?.querySelector('form')
    if (!form) return
    const dense = Boolean(form.querySelector('.line-row, table, .choice-grid, .choice-row, .device-panel'))
    if (dense) sheet.value = true
  },
  { immediate: true },
)

function focusables(): HTMLElement[] {
  if (!panel.value) return []
  return Array.from(panel.value.querySelectorAll<HTMLElement>(FOCUSABLE))
    .filter((el) => el.getClientRects().length > 0)
}

function onKey(event: KeyboardEvent) {
  if (modalStack[modalStack.length - 1] !== requestClose) return
  if (event.key === 'Escape') {
    event.preventDefault()
    void requestClose()
    return
  }
  if (event.key !== 'Tab') return
  const nodes = focusables()
  if (!nodes.length) {
    event.preventDefault()
    panel.value?.focus()
    return
  }
  const first = nodes[0]
  const last = nodes[nodes.length - 1]
  const active = document.activeElement
  if (event.shiftKey && (active === first || active === panel.value)) {
    event.preventDefault()
    last?.focus()
  } else if (!event.shiftKey && active === last) {
    event.preventDefault()
    first?.focus()
  }
}

async function requestClose() {
  if (props.dirty) {
    const discard = await confirm(t('common.unsavedMessage'), {
      title: t('common.unsavedTitle'),
      confirmLabel: t('common.discard'),
      cancelLabel: t('common.keepEditing'),
      danger: true,
    })
    if (!discard) return
  }
  emit('close')
}

function onBackdrop() {
  if (props.closeOnBackdrop) void requestClose()
}

function release() {
  if (!held) return
  held = false
  document.removeEventListener('keydown', onKey)
  const index = modalStack.lastIndexOf(requestClose)
  if (index !== -1) modalStack.splice(index, 1)
  unlockBody()
  previouslyFocused?.focus()
  previouslyFocused = null
}

watch(() => props.open, async (open, wasOpen) => {
  if (open) {
    if (held) return
    held = true
    previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null
    modalStack.push(requestClose)
    lockBody()
    document.addEventListener('keydown', onKey)
    await nextTick()
    panel.value?.focus()
    return
  }
  if (wasOpen) release()
}, { immediate: true })

onBeforeUnmount(() => {
  if (!props.open) return
  release()
})
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="open"
        class="app-modal-backdrop"
        :class="{ 'app-modal-backdrop--drawer': isDrawer, 'app-modal-backdrop--top': elevated }"
        @mousedown.self="onBackdrop"
      >
        <div
          ref="panel"
          class="app-modal"
          :class="[
            `app-modal--${size}`,
            toneClass,
            {
              'app-modal--sheet': sheet,
              'app-modal--drawer': isDrawer,
              'app-modal--dialog': !isDrawer,
            },
          ]"
          role="dialog"
          aria-modal="true"
          :aria-labelledby="titleId"
          :aria-describedby="subtitle ? descId : undefined"
          tabindex="-1"
          @mousedown.stop
        >
          <div class="app-modal__header">
            <div class="app-modal__heading">
              <span class="app-modal__mark">
                <AppIcon :name="icon" :size="18" />
              </span>
              <div class="app-modal__titles">
                <h3 :id="titleId" class="app-modal__title">{{ title }}</h3>
                <p v-if="subtitle" :id="descId" class="app-modal__subtitle">{{ subtitle }}</p>
              </div>
            </div>
            <button
              type="button"
              class="app-modal__close"
              :aria-label="t('common.close')"
              @click="requestClose"
            >
              ×
            </button>
          </div>

          <div class="app-modal__body">
            <div v-if="loading" class="app-modal__state" role="status">
              <span class="sr-only">{{ t('common.loading') }}</span>
              <span class="ui-skeleton ui-skeleton--md" style="width: 72%" />
              <span class="ui-skeleton ui-skeleton--sm" style="width: 100%" />
              <span class="ui-skeleton ui-skeleton--sm" style="width: 88%" />
              <span class="ui-skeleton ui-skeleton--md" style="width: 46%" />
            </div>
            <div v-else-if="error" class="app-modal__state">
              <p>{{ error }}</p>
              <button type="button" class="btn-secondary" @click="emit('retry')">
                {{ t('common.retry') }}
              </button>
            </div>
            <slot v-else />
          </div>

          <div v-if="$slots.footer && !loading && !error" class="app-modal__footer">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
