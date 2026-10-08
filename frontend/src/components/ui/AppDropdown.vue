<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import AppIcon from './AppIcon.vue'

export interface MenuItem {
  id: string
  label: string
  hint?: string
  disabled?: boolean
  danger?: boolean
}

const props = defineProps<{
  label: string
  items: MenuItem[]
}>()

const emit = defineEmits<{
  select: [id: string]
}>()

const open = ref(false)
const root = ref<HTMLElement | null>(null)
const active = ref(0)

const enabled = computed(() => props.items.map((item, index) => ({ item, index })).filter(({ item }) => !item.disabled))

function move(step: number) {
  if (!enabled.value.length) return
  const current = enabled.value.findIndex(({ index }) => index === active.value)
  const next = enabled.value[(current + step + enabled.value.length) % enabled.value.length]
  if (next) active.value = next.index
}

function choose(item: MenuItem) {
  if (item.disabled) return
  emit('select', item.id)
  open.value = false
}

function onKey(event: KeyboardEvent) {
  if (!open.value && (event.key === 'ArrowDown' || event.key === 'Enter' || event.key === ' ')) {
    event.preventDefault()
    open.value = true
    return
  }
  if (!open.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    open.value = false
    return
  }
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    move(1)
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    move(-1)
  } else if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    const item = props.items[active.value]
    if (item) choose(item)
  }
}

function onPointer(event: PointerEvent) {
  if (!open.value || !root.value) return
  if (event.target instanceof Node && root.value.contains(event.target)) return
  open.value = false
}

watch(open, (isOpen) => {
  if (isOpen) {
    const first = enabled.value[0]
    active.value = first ? first.index : 0
    document.addEventListener('pointerdown', onPointer)
    return
  }
  document.removeEventListener('pointerdown', onPointer)
})

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', onPointer)
})
</script>

<template>
  <div ref="root" class="ui-dropdown" @keydown="onKey">
    <button
      type="button"
      class="ui-btn ui-btn--secondary"
      :aria-expanded="open"
      aria-haspopup="menu"
      @click="open = !open"
    >
      <span>{{ label }}</span>
      <AppIcon name="chevron-down" :size="16" />
    </button>
    <div v-if="open" class="ui-dropdown__menu" role="menu">
      <button
        v-for="(item, index) in items"
        :key="item.id"
        type="button"
        class="ui-dropdown__item"
        :class="{
          'ui-dropdown__item--active': index === active,
          'ui-dropdown__item--danger': item.danger,
        }"
        role="menuitem"
        :disabled="item.disabled"
        @mouseenter="active = index"
        @click="choose(item)"
      >
        <span>{{ item.label }}</span>
        <span v-if="item.hint" class="ui-dropdown__hint">{{ item.hint }}</span>
      </button>
    </div>
  </div>
</template>
