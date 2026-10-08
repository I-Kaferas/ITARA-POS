<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { MODULE_CODES } from '../../../modules/registry'

type Limits = {
  users: number | null
  branches: number | null
  pos: number | null
  products: number | null
  storage_mb: number | null
  transactions: number | null
  modules: string[]
}

type Plan = {
  code: string
  name: string
  monthly_price: number
  yearly_price: number
  trial_days: number
  grace_days: number
  limits: Limits
}

const limitKeys = ['users', 'branches', 'pos', 'products', 'storage_mb', 'transactions'] as const

const { t } = useI18n()
const plans = ref<Plan[]>([])
const modules = ref<string[]>([...MODULE_CODES])
const error = ref('')
const notice = ref('')
const saving = ref<string | null>(null)

function dollars(cents: number) {
  return (cents / 100).toFixed(2)
}

function blank(value: number | null) {
  return value === null || value === undefined ? '' : String(value)
}

onMounted(load)

async function load() {
  error.value = ''
  try {
    const response = await api.get<{ data: Plan[]; modules?: string[] }>('/platform/plans')
    plans.value = response.data
    if (response.modules?.length) modules.value = response.modules
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

function toggleModule(plan: Plan, code: string) {
  const current = plan.limits.modules
  plan.limits.modules = current.includes(code)
    ? current.filter(item => item !== code)
    : [...current, code]
}

async function save(plan: Plan, event: Event) {
  const form = event.currentTarget
  if (!(form instanceof HTMLFormElement)) return
  const data = new FormData(form)
  const limits: Record<string, number | null | string[]> = {}
  for (const key of limitKeys) {
    const raw = String(data.get(key) ?? '').trim()
    limits[key] = raw === '' ? null : Number(raw)
  }
  limits.modules = plan.limits.modules
  saving.value = plan.code
  error.value = ''
  notice.value = ''
  try {
    await api.patch(`/platform/plans/${plan.code}`, {
      monthly_price: Math.round(Number(data.get('monthly_price')) * 100),
      yearly_price: Math.round(Number(data.get('yearly_price')) * 100),
      trial_days: Number(data.get('trial_days')),
      grace_days: Number(data.get('grace_days')),
      limits,
    })
    notice.value = plan.name
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = null
  }
}
</script>

<template>
  <section class="plans">
    <header>
      <h2>{{ t('platform.billing.title') }}</h2>
      <p>{{ t('platform.billing.hint') }}</p>
    </header>
    <p v-if="error" class="plans__error" role="alert">{{ error }}</p>
    <p v-else-if="notice" class="plans__note">{{ notice }}</p>
    <div class="plans__grid">
      <form v-for="plan in plans" :key="plan.code" class="plans__card" @submit.prevent="save(plan, $event)">
        <h3>{{ plan.name }}</h3>
        <label>{{ t('platform.billing.monthly') }}<input class="field" name="monthly_price" type="number" min="0" step="0.01" :value="dollars(plan.monthly_price)" required /></label>
        <label>{{ t('platform.billing.yearly') }}<input class="field" name="yearly_price" type="number" min="0" step="0.01" :value="dollars(plan.yearly_price)" required /></label>
        <label>{{ t('platform.billing.trialDays') }}<input class="field" name="trial_days" type="number" min="0" :value="plan.trial_days" required /></label>
        <label>{{ t('platform.billing.graceDays') }}<input class="field" name="grace_days" type="number" min="0" :value="plan.grace_days" required /></label>
        <label v-for="key in limitKeys" :key="key">
          {{ t(`platform.billing.${key === 'storage_mb' ? 'storage' : key}`) }}
          <input class="field" :name="key" type="number" min="0" :placeholder="t('subscriptionPage.unlimited')" :value="blank(plan.limits[key])" />
        </label>
        <div class="plans__modules">
          <button
            v-for="code in modules"
            :key="code"
            type="button"
            class="plans__module"
            :class="{ 'plans__module--on': plan.limits.modules.includes(code) }"
            @click="toggleModule(plan, code)"
          >
            {{ t(`platform.moduleNames.${code}`) }}
          </button>
        </div>
        <button class="btn-primary" type="submit" :disabled="saving === plan.code || plan.limits.modules.length === 0">
          {{ t('platform.billing.save') }}
        </button>
      </form>
    </div>
  </section>
</template>

<style scoped>
.plans { display: flex; flex-direction: column; gap: 0.75rem; }
.plans header h2 { margin: 0; font-size: 1.05rem; }
.plans header p, .plans__note { margin: 0.2rem 0 0; color: var(--color-text-muted); font-size: 0.8rem; }
.plans__error { margin: 0; color: var(--color-danger, #b91c1c); font-size: 0.85rem; }
.plans__grid { display: grid; gap: 0.75rem; grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); }
.plans__card {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  padding: 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 0.85rem;
  background: var(--color-surface);
}
.plans__card h3 { margin: 0 0 0.2rem; font-size: 1rem; }
.plans__card label { display: flex; flex-direction: column; gap: 0.2rem; font-size: 0.72rem; font-weight: 650; color: var(--color-text-muted); }
.plans__modules { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.plans__module {
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: transparent;
  color: var(--color-text-secondary);
  padding: 0.2rem 0.5rem;
  font-size: 0.72rem;
  cursor: pointer;
}
.plans__module--on {
  border-color: var(--color-brand-600);
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-700));
}
</style>
