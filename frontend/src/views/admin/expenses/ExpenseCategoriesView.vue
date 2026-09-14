<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import { useBackofficeStore } from '../../../stores/backoffice'

const { t } = useI18n()
const store = useBackofficeStore()
const categories = ref<Array<{ id: string; code: string; name: string }>>([])

onMounted(async () => {
  categories.value = (await store.loadExpenseCategories()) as typeof categories.value
})
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('expenses.tabs.categories') }}</template>
    <template #subtitle>{{ t('expenses.linksHint') }}</template>
    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.name') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.code') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="category in categories" :key="category.id">
            <td class="px-4 py-3 font-medium">{{ category.name }}</td>
            <td class="px-4 py-3 font-mono text-slate-500">{{ category.code }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </AdminLayout>
</template>
