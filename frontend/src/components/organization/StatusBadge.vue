<script setup lang="ts">
import Badge from '../ui/Badge.vue'

defineProps<{ active?: boolean }>()
</script>

<template>
  <Badge :variant="active ? 'success' : 'neutral'">
    {{ active ? 'Actif' : 'Inactif' }}
  </Badge>
</template>
