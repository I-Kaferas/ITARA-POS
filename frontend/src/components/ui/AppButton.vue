<script setup lang="ts">
withDefaults(defineProps<{
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'link'
  size?: 'sm' | 'md' | 'lg'
  type?: 'button' | 'submit' | 'reset'
  disabled?: boolean
  loading?: boolean
  icon?: boolean
}>(), {
  variant: 'primary',
  size: 'md',
  type: 'button',
  disabled: false,
  loading: false,
  icon: false,
})
</script>

<template>
  <button
    :type="type"
    class="ui-btn"
    :class="[
      `ui-btn--${variant}`,
      {
        'ui-btn--sm': size === 'sm',
        'ui-btn--lg': size === 'lg',
        'ui-btn--icon': icon,
        'ui-btn--loading': loading,
      },
    ]"
    :disabled="disabled || loading"
  >
    <slot />
  </button>
</template>
