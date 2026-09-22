<script setup lang="ts">
import AppModal from '../ui/AppModal.vue'
import LoadingBlock from '../ui/LoadingBlock.vue'
import { useI18n } from 'vue-i18n'

defineProps<{
  open: boolean
  title: string
  reference?: string | null
  status?: string | null
  statusLabel?: string
  loading?: boolean
  confirmedBy?: string
  approvedBy?: string
  fields?: { label: string; value?: string | null }[]
  items?: { name: string; sku?: string | null; quantity?: number | string | null }[]
  steps?: { label: string; done: boolean; active: boolean }[]
}>()

const emit = defineEmits<{
  close: []
}>()

const { t } = useI18n()
</script>

<template>
  <AppModal :open="open" :title="reference ? `${title} · ${reference}` : title" icon="inventory" tone="info" size="lg" @close="emit('close')">
    <LoadingBlock v-if="loading" variant="list" :rows="4" :label="t('common.loading')" />
    <div v-else class="space-y-4">
      <ol v-if="steps?.length" class="grid gap-1 sm:grid-cols-4">
        <li
          v-for="step in steps"
          :key="step.label"
          class="rounded-lg px-2 py-1.5 text-xs"
          :class="step.done ? 'bg-emerald-50 text-emerald-800' : step.active ? 'bg-amber-50 font-medium text-amber-800' : 'bg-slate-100 text-slate-500'"
        >
          {{ step.label }}
        </li>
      </ol>
      <div class="flex flex-wrap items-center gap-2 text-sm">
        <span v-if="statusLabel" class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">{{ statusLabel }}</span>
      </div>

      <dl class="grid gap-3 sm:grid-cols-2">
        <div v-for="field in fields ?? []" :key="field.label" class="rounded-lg bg-slate-50 px-3 py-2">
          <dt class="text-xs uppercase tracking-wide text-slate-400">{{ field.label }}</dt>
          <dd class="mt-1 font-medium text-slate-800">{{ field.value || '—' }}</dd>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2">
          <dt class="text-xs uppercase tracking-wide text-slate-400">{{ t('inventory.confirmedBy') }}</dt>
          <dd class="mt-1 font-medium text-slate-800">{{ confirmedBy || '—' }}</dd>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2">
          <dt class="text-xs uppercase tracking-wide text-slate-400">{{ t('inventory.approvedBy') }}</dt>
          <dd class="mt-1 font-medium text-slate-800">{{ approvedBy || '—' }}</dd>
        </div>
      </dl>

      <div class="overflow-hidden rounded-xl ring-1 ring-slate-200">
        <table class="min-w-full text-sm">
          <thead class="bg-slate-50 text-left text-slate-500">
            <tr>
              <th class="px-3 py-2 font-medium">{{ t('inventory.articles') }}</th>
              <th class="px-3 py-2 text-right font-medium">{{ t('inventory.qtyShort') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, index) in items ?? []" :key="`${item.sku ?? item.name}-${index}`" class="border-t border-slate-100">
              <td class="px-3 py-2">
                <span class="block font-medium">{{ item.name }}</span>
                <span v-if="item.sku" class="text-xs text-slate-500">{{ item.sku }}</span>
              </td>
              <td class="px-3 py-2 text-right">{{ item.quantity ?? '—' }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!(items ?? []).length" class="px-3 py-4 text-center text-sm text-slate-500">{{ t('inventory.noArticles') }}</p>
      </div>

      <div class="app-modal__actions">
        <button type="button" class="btn-primary" @click="emit('close')">{{ t('common.ok') }}</button>
      </div>
    </div>
  </AppModal>
</template>
