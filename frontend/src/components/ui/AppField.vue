<script setup lang="ts">
import { useId } from 'vue'

withDefaults(defineProps<{
  modelValue?: string | number
  label?: string
  hint?: string
  error?: string
  type?: string
  placeholder?: string
  disabled?: boolean
  required?: boolean
  rows?: number
  options?: { value: string; label: string }[]
}>(), {
  modelValue: '',
  type: 'text',
  disabled: false,
  required: false,
  rows: 3,
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const fieldId = useId()
const hintId = useId()

function onInput(event: Event) {
  emit('update:modelValue', (event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement).value)
}
</script>

<template>
  <div class="ui-field">
    <label v-if="label" class="ui-label" :for="fieldId">
      {{ label }}
      <span v-if="required" class="ui-label__mark" aria-hidden="true">*</span>
    </label>

    <select
      v-if="options"
      :id="fieldId"
      class="ui-select"
      :value="modelValue"
      :disabled="disabled"
      :required="required"
      :aria-invalid="Boolean(error) || undefined"
      :aria-describedby="error || hint ? hintId : undefined"
      @change="onInput"
    >
      <option v-for="option in options" :key="option.value" :value="option.value">
        {{ option.label }}
      </option>
    </select>

    <textarea
      v-else-if="type === 'textarea'"
      :id="fieldId"
      class="ui-input"
      :class="{ 'is-invalid': error }"
      :value="modelValue"
      :rows="rows"
      :placeholder="placeholder"
      :disabled="disabled"
      :required="required"
      :aria-invalid="Boolean(error) || undefined"
      :aria-describedby="error || hint ? hintId : undefined"
      @input="onInput"
    />

    <input
      v-else
      :id="fieldId"
      class="ui-input"
      :class="{ 'is-invalid': error }"
      :type="type"
      :value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      :required="required"
      :aria-invalid="Boolean(error) || undefined"
      :aria-describedby="error || hint ? hintId : undefined"
      @input="onInput"
    >

    <p v-if="error" :id="hintId" class="field-error">{{ error }}</p>
    <p v-else-if="hint" :id="hintId" class="field-hint">{{ hint }}</p>
  </div>
</template>
