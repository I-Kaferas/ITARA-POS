<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  LOCALE_META,
  SUPPORTED_LOCALES,
  persistLocale,
  type AppLocale,
} from '../../i18n/locales'
import LanguageFlag from './LanguageFlag.vue'

withDefaults(defineProps<{
  tone?: 'light' | 'glass'
}>(), {
  tone: 'light',
})

const { t, locale } = useI18n()
const open = ref(false)
const root = ref<HTMLElement | null>(null)
const activeIndex = ref(0)

const current = computed(() => (locale.value as AppLocale) in LOCALE_META ? locale.value as AppLocale : 'fr')
const currentMeta = computed(() => LOCALE_META[current.value])

function select(code: AppLocale) {
  if (code === current.value) {
    open.value = false
    return
  }
  locale.value = code
  persistLocale(code)
  open.value = false
}

function toggle() {
  open.value = !open.value
  if (open.value) activeIndex.value = SUPPORTED_LOCALES.indexOf(current.value)
}

function onWindowPointer(event: PointerEvent) {
  if (!root.value?.contains(event.target as Node)) open.value = false
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
  } else {
    window.removeEventListener('pointerdown', onWindowPointer)
    window.removeEventListener('keydown', onWindowKeydown)
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', onWindowPointer)
  window.removeEventListener('keydown', onWindowKeydown)
})
</script>

<template>
  <div ref="root" class="lang" :class="[`lang--${tone}`, { 'lang--open': open }]">
    <button
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
      <span class="lang__current">{{ currentMeta.native }}</span>
      <svg class="lang__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M7 10l5 5 5-5" />
      </svg>
    </button>

    <Transition name="lang-pop">
      <div v-if="open" class="lang__panel" role="listbox" :aria-label="t('language.label')">
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
  </div>
</template>

<style scoped>
.lang {
  position: relative;
  display: inline-flex;
}

.lang__trigger {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  height: 2.125rem;
  padding: 0 0.55rem 0 0.3rem;
  border: 1px solid #e6e8ee;
  border-radius: 999px;
  background: #fff;
  color: #1e293b;
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.9) inset,
    0 1px 2px rgba(15, 23, 42, 0.04);
  cursor: pointer;
  transition: border-color 0.16s ease, box-shadow 0.16s ease, transform 0.16s ease;
}

.lang__trigger:hover {
  border-color: #d7dbe6;
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.9) inset,
    0 6px 16px rgba(15, 23, 42, 0.06);
}

.lang__trigger:active {
  transform: translateY(0.5px);
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
  background: #fff;
}

.lang__mark {
  width: 1.55rem;
  height: 1.55rem;
  border-radius: 999px;
}

.lang__flag {
  width: 1.7rem;
  height: 1.15rem;
  border-radius: 0.22rem;
}

.lang__current {
  font-family: var(--font-display);
  font-size: 0.8125rem;
  font-weight: 600;
  letter-spacing: -0.02em;
  line-height: 1;
}

.lang__chevron {
  width: 0.85rem;
  height: 0.85rem;
  color: #94a3b8;
  transition: transform 0.18s ease;
}

.lang--open .lang__chevron {
  transform: rotate(180deg);
  color: #64748b;
}

.lang__panel {
  position: absolute;
  top: calc(100% + 0.55rem);
  right: 0;
  z-index: 50;
  width: 16.75rem;
  padding: 0.45rem;
  border: 1px solid rgba(226, 230, 239, 0.95);
  border-radius: 1rem;
  background: rgba(255, 255, 255, 0.96);
  backdrop-filter: blur(16px);
  box-shadow:
    0 0 0 1px rgba(255, 255, 255, 0.7) inset,
    0 18px 40px rgba(15, 23, 42, 0.1),
    0 4px 10px rgba(15, 23, 42, 0.04);
}

.lang__head {
  padding: 0.45rem 0.7rem 0.35rem;
}

.lang__kicker {
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #94a3b8;
}

.lang__list {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.lang__option {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  width: 100%;
  padding: 0.62rem 0.65rem;
  border: 0;
  border-radius: 0.75rem;
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: background 0.14s ease;
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
  font-family: var(--font-display);
  font-size: 0.875rem;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: #0f172a;
  line-height: 1.15;
}

.lang__meta {
  font-size: 0.6875rem;
  color: #94a3b8;
  letter-spacing: 0.01em;
}

.lang-pop-enter-active,
.lang-pop-leave-active {
  transition: opacity 0.16s ease, transform 0.16s ease;
}

.lang-pop-enter-from,
.lang-pop-leave-to {
  opacity: 0;
  transform: translateY(-4px) scale(0.98);
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
</style>
