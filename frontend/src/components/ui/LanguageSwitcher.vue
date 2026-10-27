<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { setAppLocale } from '../../i18n'
import {
  LOCALE_META,
  SUPPORTED_LOCALES,
  type AppLocale,
} from '../../i18n/locales'
import LanguageFlag from './LanguageFlag.vue'

withDefaults(defineProps<{
  tone?: 'light' | 'glass'
  compact?: boolean
}>(), {
  tone: 'light',
  compact: false,
})

const { t, locale } = useI18n()
const open = ref(false)
const root = ref<HTMLElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)
const panel = ref<HTMLElement | null>(null)
const activeIndex = ref(0)
const panelStyle = ref<Record<string, string>>({})

function place() {
  const triggerEl = trigger.value
  const panelEl = panel.value
  if (!triggerEl || !panelEl) return

  const pad = 12
  const gap = 8
  const triggerRect = triggerEl.getBoundingClientRect()
  const width = panelEl.offsetWidth
  const height = panelEl.offsetHeight
  const viewWidth = window.innerWidth
  const viewHeight = window.innerHeight

  let top = triggerRect.bottom + gap
  if (top + height > viewHeight - pad) {
    const above = triggerRect.top - gap - height
    top = above >= pad ? above : Math.max(pad, viewHeight - height - pad)
  }

  let left = triggerRect.right - width
  left = Math.min(Math.max(pad, left), Math.max(pad, viewWidth - width - pad))

  panelStyle.value = {
    top: `${top}px`,
    left: `${left}px`,
    right: 'auto',
  }
}

const current = computed(() => (locale.value as AppLocale) in LOCALE_META ? locale.value as AppLocale : 'fr')
const currentMeta = computed(() => LOCALE_META[current.value])

async function select(code: AppLocale) {
  if (code === current.value) {
    open.value = false
    return
  }
  await setAppLocale(code)
  open.value = false
}

function toggle() {
  if (!open.value) {
    place()
    activeIndex.value = SUPPORTED_LOCALES.indexOf(current.value)
  }
  open.value = !open.value
}

function onWindowPointer(event: PointerEvent) {
  const target = event.target as Node
  if (root.value?.contains(target) || panel.value?.contains(target)) return
  open.value = false
}

function onWindowKeydown(event: KeyboardEvent) {
  if (!open.value) return

  if (event.key === 'Escape' || event.key === 'Tab') {
    open.value = false
    return
  }

  if (event.key === 'ArrowDown') {
    event.preventDefault()
    activeIndex.value = (activeIndex.value + 1) % SUPPORTED_LOCALES.length
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    activeIndex.value = (activeIndex.value - 1 + SUPPORTED_LOCALES.length) % SUPPORTED_LOCALES.length
  } else if (event.key === 'Enter') {
    event.preventDefault()
    const code = SUPPORTED_LOCALES[activeIndex.value]
    if (code) select(code)
  }
}

watch(open, (value) => {
  if (value) {
    window.addEventListener('pointerdown', onWindowPointer)
    window.addEventListener('keydown', onWindowKeydown)
    window.addEventListener('resize', place)
    window.addEventListener('scroll', place, true)
    void nextTick(() => {
      place()
      requestAnimationFrame(place)
    })
  } else {
    window.removeEventListener('pointerdown', onWindowPointer)
    window.removeEventListener('keydown', onWindowKeydown)
    window.removeEventListener('resize', place)
    window.removeEventListener('scroll', place, true)
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', onWindowPointer)
  window.removeEventListener('keydown', onWindowKeydown)
  window.removeEventListener('resize', place)
  window.removeEventListener('scroll', place, true)
})
</script>

<template>
  <div ref="root" class="lang" :class="[`lang--${tone}`, { 'lang--open': open }]">
    <button
      ref="trigger"
      type="button"
      class="lang__trigger"
      :aria-label="t('language.label')"
      :aria-expanded="open"
      aria-haspopup="listbox"
      @click="toggle"
    >
      <span class="lang__mark" aria-hidden="true">
        <LanguageFlag :locale="current" />
      </span>
      <span class="lang__current">{{ compact ? currentMeta.code : currentMeta.native }}</span>
      <svg class="lang__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M7 10l5 5 5-5" />
      </svg>
    </button>

    <Teleport to="body">
    <Transition name="lang-pop">
      <div v-if="open" ref="panel" class="lang__panel" :style="panelStyle" role="listbox" :aria-label="t('language.label')">
        <div class="lang__head">
          <span class="lang__kicker">{{ t('language.hint') }}</span>
        </div>
        <div class="lang__list">
          <button
            v-for="(code, index) in SUPPORTED_LOCALES"
            :key="code"
            type="button"
            class="lang__option"
            :class="{
              'lang__option--active': code === current,
              'lang__option--focus': index === activeIndex,
            }"
            role="option"
            :aria-selected="code === current"
            @mouseenter="activeIndex = index"
            @click="select(code)"
          >
            <span class="lang__flag" aria-hidden="true">
              <LanguageFlag :locale="code" />
            </span>
            <span class="lang__copy">
              <span class="lang__name">{{ LOCALE_META[code].native }}</span>
              <span class="lang__meta">{{ LOCALE_META[code].region }}</span>
            </span>
          </button>
        </div>
      </div>
    </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.lang {
  position: relative;
  display: inline-flex;
  min-width: 0;
  max-width: 100%;
  flex: 0 1 auto;
}

.lang__trigger {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  height: var(--control-md);
  min-width: 0;
  max-width: 100%;
  padding: 0 var(--space-3) 0 var(--space-1);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-primary);
  cursor: pointer;}

.lang__trigger:hover {
  border-color: #d7dbe6;
}

.lang--open .lang__trigger,
.lang__trigger:focus-visible {
  outline: none;
  border-color: color-mix(in srgb, var(--color-brand-500) 38%, #e6e8ee);
  box-shadow:
    0 0 0 3px rgba(74, 109, 134, 0.14),
    0 1px 0 rgba(255, 255, 255, 0.9) inset;
}

.lang__mark,
.lang__flag {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  flex-shrink: 0;
  border: 1px solid rgba(15, 23, 42, 0.12);
  background: var(--color-surface);}

.lang__mark {
  width: var(--control-sm);
  height: var(--control-sm);
  border-radius: var(--radius-sm);
}

.lang__flag {
  width: 1.7rem;
  height: 1.15rem;
  border-radius: 0.22rem;
}

.lang__current {
  min-width: 0;
  overflow: hidden;
  font-family: var(--font-sans);
  font-size: var(--text-md);
  font-weight: 500;
  letter-spacing: 0;
  line-height: var(--line-sm);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lang__chevron {
  width: 0.85rem;
  height: 0.85rem;
  color: var(--color-text-faint);
  transition: transform 0.18s ease;}

.lang--open .lang__chevron {
  transform: rotate(180deg);
  color: var(--color-text-muted);}

.lang__panel {
  position: fixed;
  z-index: 500;
  width: 16.75rem;
  padding: var(--overlay-pad);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);}

.lang__head {
  padding: var(--space-2) var(--space-3) var(--space-1);
}

.lang__kicker {
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-faint);}

.lang__list {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.lang__option {
  display: flex;
  align-items: center;
  gap: var(--nav-icon-gap);
  width: 100%;
  height: auto;
  min-height: var(--control-md);
  padding: var(--overlay-item-pad-y) var(--overlay-item-pad-x);
  border: 0;
  border-radius: var(--radius-sm);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.lang__option:hover,
.lang__option--focus {
  background: #f5f6fa;
}

.lang__option--active {
  background: #e4edf2;
}

.lang__copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.15rem;
}

.lang__name {
  font-family: var(--font-sans);
  font-size: var(--text-md);
  font-weight: 500;
  letter-spacing: 0;
  color: var(--color-text-primary);
  line-height: var(--line-sm);}

.lang__meta {
  font-size: var(--text-xs);
  line-height: var(--line-xs);
  color: var(--color-text-faint);}

.lang-pop-enter-active,
.lang-pop-leave-active {
  transition:
    opacity 220ms cubic-bezier(0.22, 1, 0.36, 1),
    transform 280ms cubic-bezier(0.22, 1, 0.36, 1);
}

.lang-pop-enter-from,
.lang-pop-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

.lang--glass .lang__trigger {
  border-color: rgba(255, 255, 255, 0.18);
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
}

.lang--glass .lang__trigger:hover {
  background: rgba(255, 255, 255, 0.14);
  border-color: rgba(255, 255, 255, 0.28);
}

.lang--glass .lang__mark {
  border-color: rgba(255, 255, 255, 0.28);
  box-shadow: none;
}

.lang--glass .lang__chevron {
  color: rgba(255, 255, 255, 0.7);
}

.lang--glass.lang--open .lang__trigger,
.lang--glass .lang__trigger:focus-visible {
  border-color: rgba(255, 255, 255, 0.42);
  box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.1);
}

@media (max-width: 767px) {
  .lang__current {
    display: none;
  }
}
</style>
