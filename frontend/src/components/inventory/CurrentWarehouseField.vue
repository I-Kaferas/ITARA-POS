<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import FieldLabel from '../ui/FieldLabel.vue'
import type { Warehouse } from '../../types'

defineProps<{
  warehouse: Warehouse | null
}>()

const { t } = useI18n()
</script>

<template>
  <div>
    <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
    <input class="field" :value="warehouse?.name || '—'" readonly tabindex="-1">
    <p v-if="warehouse" class="mt-1 text-xs text-slate-500">{{ t('inventory.countStoreFixed') }}</p>
    <p v-else class="mt-1 text-xs text-red-600">{{ t('inventory.countNoStore') }}</p>
  </div>
</template>
