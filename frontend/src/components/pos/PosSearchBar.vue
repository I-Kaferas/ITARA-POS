<script setup lang="ts">
import { onMounted, ref } from 'vue'

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
    <button type="submit" class="pos-search__btn">OK</button>
    <p v-if="hint" class="pos-search__hint">{{ hint }}</p>
  </form>
</template>

<style scoped>
.pos-search {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 0.45rem;
  align-items: center;
  min-width: 0;
}
.pos-search__input {
  width: 100%;
  border: 1px solid #cbd5e1;
  border-radius: 0.65rem;
  padding: 0.7rem 0.85rem;
  font-size: 1rem;
  background: white;
}
.pos-search__input:focus {
  outline: 2px solid #4a6d86;
  border-color: #4a6d86;
}
.pos-search__btn {
  border: 0;
  border-radius: 0.65rem;
  padding: 0.7rem 1rem;
  font-weight: 700;
  color: white;
  background: #4a6d86;
}
.pos-search__hint {
  grid-column: 1 / -1;
  margin: 0;
  font-size: 0.72rem;
  color: #64748b;
}
@media (max-width: 900px) {
  .pos-search__hint {
    display: none;
  }
  .pos-search__input,
  .pos-search__btn {
    padding: 0.58rem 0.75rem;
  }
}
</style>
