<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../api/client'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import { formatDateTime } from '../../utils/format'

type Recipe = {
  id: string
  name: string
  on_hand: number
  lines: { name: string; quantity: number; on_hand: number }[]
}
type Run = { id: string; recipe_name: string; batches: number; finished_quantity: number; produced_at?: string }

const { t } = useI18n()
const recipes = ref<Recipe[]>([])
const runs = ref<Run[]>([])
const batches = ref<Record<string, number>>({})
const error = ref('')
const loading = ref(false)

onMounted(load)

async function load() {
  loading.value = true
  error.value = ''
  try {
    const data = (await api.get<{ data: { recipes: Recipe[]; runs: Run[] } }>('/production')).data
    recipes.value = data.recipes
    runs.value = data.runs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function produce(recipe: Recipe) {
  error.value = ''
  try {
    const data = (await api.post<{ data: { recipes: Recipe[]; runs: Run[] } }>('/production/actions', {
      action: 'produce',
      recipe_id: recipe.id,
      batches: batches.value[recipe.id] || 1,
    })).data
    recipes.value = data.recipes
    runs.value = data.runs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('desk.production') }}</template>
    <template #subtitle>{{ t('desk.productionHint') }}</template>

    <div class="space-y-4">
      <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>
      <p v-if="!loading && !recipes.length" class="rounded-xl bg-white px-4 py-8 text-center text-slate-500">{{ t('desk.noRecipes') }}</p>
      <div class="grid gap-4 lg:grid-cols-2">
        <article v-for="recipe in recipes" :key="recipe.id" class="rounded-2xl border border-slate-200 bg-white p-4">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h3 class="m-0">{{ recipe.name }}</h3>
              <p class="m-0 text-sm text-slate-500">{{ t('desk.onHand') }} {{ recipe.on_hand }}</p>
            </div>
          </div>
          <ul class="mt-3 space-y-1 text-sm text-slate-600">
            <li v-for="line in recipe.lines" :key="line.name">{{ line.quantity }} × {{ line.name }} · {{ t('desk.onHand') }} {{ line.on_hand }}</li>
          </ul>
          <div class="mt-4 flex items-center gap-2">
            <input v-model.number="batches[recipe.id]" type="number" min="1" class="field w-24" :placeholder="t('desk.batches')" />
            <button class="btn-primary" @click="produce(recipe)">{{ t('desk.produce') }}</button>
          </div>
        </article>
      </div>
      <section v-if="runs.length" class="rounded-2xl border border-slate-200 bg-white">
        <h3 class="m-0 px-4 pt-4">{{ t('desk.runs') }}</h3>
        <table class="min-w-full text-sm">
          <thead><tr><th class="px-4 py-3 text-left">{{ t('desk.recipe') }}</th><th class="px-4 py-3 text-left">{{ t('desk.batches') }}</th><th class="px-4 py-3 text-left">{{ t('desk.finished') }}</th><th class="px-4 py-3 text-left">{{ t('desk.when') }}</th></tr></thead>
          <tbody>
            <tr v-for="run in runs" :key="run.id">
              <td class="px-4 py-3">{{ run.recipe_name }}</td>
              <td class="px-4 py-3">{{ run.batches }}</td>
              <td class="px-4 py-3">{{ run.finished_quantity }}</td>
              <td class="px-4 py-3">{{ formatDateTime(run.produced_at) }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </AdminLayout>
</template>
