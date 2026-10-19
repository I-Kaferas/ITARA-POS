<script setup lang="ts">
import { onMounted, ref } from 'vue'
import AppIcon from '../ui/AppIcon.vue'

const query = defineModel<string>({ default: '' })

defineProps<{
  placeholder: string
  hint?: string
}>()

const emit = defineEmits<{
  submit: [value: string]
}>()

const input = ref<HTMLInputElement | null>(null)

function focus() {
  input.value?.focus()
  input.value?.select()
}

function onSubmit() {
  emit('submit', query.value)
}

onMounted(focus)

defineExpose({ focus })
</script>

<template>
  <form class="pos-search" @submit.prevent="onSubmit">
    <AppIcon name="search" :size="18" class="pos-search__icon" />
    <input
      ref="input"
      v-model="query"
      class="pos-search__input"
      type="search"
      autocomplete="off"
      autocapitalize="off"
      spellcheck="false"
      enterkeyhint="search"
      :placeholder="placeholder"
    />
  </form>
</template>

<style scoped>
.pos-search {
  position: relative;
  display: flex;
  align-items: center;
  min-width: 0;
  flex: 1;
}

.pos-search__icon {
  position: absolute;
  left: 0.9rem;
  color: var(--color-text-faint);
  pointer-events: none;
}

.pos-search__input {
  width: 100%;
  max-width: 22rem;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 999px;
  padding: 0.7rem 1rem 0.7rem 2.55rem;
  font-size: 0.88rem;
  background: var(--color-surface, #fff);
  color: var(--color-text-primary);
  box-shadow: 0 1px 2px rgba(18, 36, 60, 0.04);
}

.pos-search__input:focus {
  outline: 2px solid color-mix(in srgb, var(--color-accent, #e39b2b) 45%, transparent);
  border-color: var(--color-accent, #e39b2b);
}

.pos-search__input::-webkit-search-cancel-button {
  -webkit-appearance: none;
}
</style>
