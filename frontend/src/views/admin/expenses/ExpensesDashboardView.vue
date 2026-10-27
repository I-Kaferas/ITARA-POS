<script setup lang="ts">
import CountUp from '../../../components/motion/CountUp.vue'
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { emptyListFilters, listFilterParams, type ListFilters } from '../../../utils/listFilters'
import AppIcon from '../../../components/ui/AppIcon.vue'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const filters = ref<ListFilters>(emptyListFilters('month'))
const total = ref(0)
const byCategory = ref<Array<{ name: string; total: number; count: number }>>([])
const categories = ref<Array<{ id: string; name: string }>>([])

const categoryOptions = computed(() => categories.value.map(item => ({ id: item.id, name: item.name })))

onMounted(async () => {
  categories.value = (await store.loadExpenseCategories()) as Array<{ id: string; name: string }>
  await load()
})

async function load() {
  const data = await store.loadExpenseDashboard(
    listFilterParams(filters.value, { categoryKey: 'expense_category_id' }),
  ) as { total?: number; by_category?: typeof byCategory.value }
  total.value = data.total ?? 0
  byCategory.value = data.by_category ?? []
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('expenses.tabs.dashboard') }}</template>
    <template #subtitle>{{ t('expenses.linksHint') }}</template>
    <div class="expenses">
      <section class="day">
        <div>
          <p class="day__kicker">{{ t('expenses.kpi.total') }}</p>
          <p class="day__amount"><CountUp :value="Number(total ?? 0)" format="money" /></p>
        </div>
        <button class="btn-primary" type="button" @click="router.push({ name: 'expenses' })">
          <AppIcon name="plus" :size="16" /> {{ t('expenses.new') }}
        </button>
      </section>
      <ModuleFilters
        v-model="filters"
        :categories="categoryOptions"
        :show-search="false"
        show-period
        show-category
        @apply="load"
      />
      <div v-if="byCategory.length" class="rooms">
        <article v-for="row in byCategory" :key="row.name" class="room">
          <p class="room__value"><CountUp :value="Number(row.total ?? 0)" format="money" /></p>
          <p class="room__label">{{ row.name }}</p>
        </article>
      </div>
      <p v-else class="empty">{{ t('org.empty') }}</p>
    </div>
  </PageFrame>
</template>

<style scoped>
.expenses {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
.day {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.95rem 1.05rem;
  border: 1px solid var(--color-border);
  border-left: 6px solid var(--color-accent);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.day__kicker {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.day__amount {
  margin: 0.2rem 0 0;
  font-family: var(--font-display);
  font-size: clamp(1.7rem, 2.6vw, 2.15rem);
  font-weight: 680;
  letter-spacing: -0.045em;
  line-height: 1;
}
.rooms {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}
.room {
  padding: 0.7rem 0.85rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.room__value {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.room__label {
  margin: 0.2rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.8rem;
}
.empty {
  margin: 0;
  color: var(--color-text-muted);
  font-size: 0.88rem;
}
@media (max-width: 860px) {
  .rooms { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 640px) {
  .day { flex-direction: column; align-items: flex-start; }
  .rooms { grid-template-columns: 1fr; }
}
</style>
