<script setup lang="ts">
import AppModal from './AppModal.vue'

withDefaults(defineProps<{
  open: boolean
  title: string
  subtitle?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  icon?: string
  dirty?: boolean
  loading?: boolean
  error?: string
}>(), {
  subtitle: '',
  size: 'md',
  icon: 'layers',
  dirty: false,
  loading: false,
  error: '',
})

defineEmits<{
  close: []
  retry: []
}>()
</script>

<template>
  <AppModal
    :open="open"
    :title="title"
    :subtitle="subtitle"
    :size="size"
    :icon="icon"
    presentation="drawer"
    :dirty="dirty"
    :loading="loading"
    :error="error"
    @close="$emit('close')"
    @retry="$emit('retry')"
  >
    <slot />
    <template v-if="$slots.footer" #footer>
      <slot name="footer" />
    </template>
  </AppModal>
</template>
