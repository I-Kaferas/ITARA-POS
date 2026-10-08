<script setup lang="ts">
import { useId } from 'vue'

export interface TabItem {
  id: string
  label: string
}

const props = defineProps<{
  tabs: TabItem[]
  modelValue: string
  label: string
}>()

const emit = defineEmits<{
  'update:modelValue': [id: string]
}>()

const baseId = useId()

function select(id: string) {
  emit('update:modelValue', id)
}

function onKey(event: KeyboardEvent) {
  const ids = props.tabs.map((tab) => tab.id)
  const index = ids.indexOf(props.modelValue)
  if (index < 0) return
  if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft' && event.key !== 'Home' && event.key !== 'End') return
  event.preventDefault()
  let next = index
  if (event.key === 'ArrowRight') next = (index + 1) % ids.length
  if (event.key === 'ArrowLeft') next = (index - 1 + ids.length) % ids.length
  if (event.key === 'Home') next = 0
  if (event.key === 'End') next = ids.length - 1
  const id = ids[next]
  if (!id) return
  select(id)
  document.getElementById(`${baseId}-${id}`)?.focus()
}
</script>

<template>
  <div class="ui-tabs">
    <div class="ui-tabs__list" role="tablist" :aria-label="label" @keydown="onKey">
      <button
        v-for="tab in tabs"
        :id="`${baseId}-${tab.id}`"
        :key="tab.id"
        type="button"
        class="ui-tabs__tab"
        :class="{ 'ui-tabs__tab--active': tab.id === modelValue }"
        role="tab"
        :aria-selected="tab.id === modelValue"
        :tabindex="tab.id === modelValue ? 0 : -1"
        @click="select(tab.id)"
      >
        {{ tab.label }}
      </button>
    </div>
    <div class="ui-tabs__panel" role="tabpanel">
      <slot />
    </div>
  </div>
</template>
