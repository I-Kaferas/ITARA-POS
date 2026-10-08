<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { intlLocale } from '../../../i18n/locales'
import { useAuthStore } from '../../../stores/auth'
import type { User } from '../../../types'

type PlanCode = 'starter' | 'professional' | 'business' | 'enterprise'
type BillingCycle = 'monthly' | 'yearly'
type LimitKey = 'users' | 'branches' | 'pos' | 'products' | 'storage_mb' | 'transactions'

type Limits = Record<LimitKey, number | null> & { modules: string[] }

type CatalogPlan = {
  code: PlanCode
  name: string
  rank: number
  monthly_price: number
  yearly_price: number
  currency: string
  limits: Limits
}

type Invoice = {
  id: string
  number: string
  kind: string
  status: string
  amount: number
  currency: string
  due_on?: string | null
  payments: { id: string; status: string; reference?: string | null }[]
}

type SubscriptionPayload = NonNullable<User['subscription']> & {
  pending_plan?: string | null
  pending_billing_cycle?: string | null
  limits?: Limits
  usage?: Record<LimitKey, number>
  amount?: number
  currency?: string
  invoices?: Invoice[]
  events?: { id: string; type: string; created_at?: string | null }[]
}

const LIMITS: LimitKey[] = ['users', 'branches', 'pos', 'products', 'storage_mb', 'transactions']
const ICONS: Record<PlanCode, string> = {
  starter: 'sparkles',
  professional: 'layers',
  business: 'building',
  enterprise: 'coins',
}

const { t, locale } = useI18n()
const auth = useAuthStore()
const plans = ref<CatalogPlan[]>([])
const subscription = ref<SubscriptionPayload | null>(null)
const actionError = ref('')
const busy = ref(false)
const reference = ref('')

const currentPlan = computed(() => subscription.value?.plan ?? 'starter')
const currentCycle = computed<BillingCycle>(() => subscription.value?.billing_cycle ?? 'yearly')
const currentDef = computed(() => plans.value.find(plan => plan.code === currentPlan.value) ?? plans.value[0])

const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

function money(cents: number) {
  return usd.format(cents / 100)
}

const statusLabel = computed(() => {
  const status = subscription.value?.status ?? 'active'
  if (status === 'trial') return t('subscriptionPage.statusTrial')
  if (status === 'past_due') return t('subscriptionPage.statusPastDue')
  if (status === 'cancelled') return t('subscriptionPage.statusCancelled')
  if (status === 'suspended') return t('subscriptionPage.statusSuspended')
  return t('subscriptionPage.active')
})

const statusVariant = computed(() => {
  const status = subscription.value?.status ?? 'active'
  if (status === 'past_due') return 'warning' as const
  if (status === 'cancelled' || status === 'suspended') return 'danger' as const
  if (status === 'trial') return 'info' as const
  return 'success' as const
})

const renewsLabel = computed(() => {
  const status = subscription.value?.status
  const trial = subscription.value?.trial_ends_on
  const grace = subscription.value?.grace_ends_on
  const renews = subscription.value?.renews_on
  if (status === 'trial' && trial) return t('subscriptionPage.trialUntil', { date: formatDate(trial) })
  if (status === 'past_due' && grace) return t('subscriptionPage.graceUntil', { date: formatDate(grace) })
  if (renews) return t('subscriptionPage.nextBilling', { date: formatDate(renews) })
  return ''
})

const currentAmount = computed(() => {
  const amount = subscription.value?.amount
  if (amount === undefined) return ''
  return t(currentCycle.value === 'yearly' ? 'subscriptionPage.perYear' : 'subscriptionPage.perMonth', {
    amount: money(amount),
  })
})

const pendingLabel = computed(() => {
  const plan = subscription.value?.pending_plan
  const date = subscription.value?.renews_on
  if (!plan || !date) return ''
  return t('subscriptionPage.scheduled', { plan: planName(plan), date: formatDate(date) })
})

onMounted(load)

async function load() {
  actionError.value = ''
  try {
    const response = await api.get<{ data: SubscriptionPayload; plans: CatalogPlan[] }>('/tenant/subscription')
    subscription.value = response.data
    plans.value = response.plans
    if (auth.user) {
      auth.user = {
        ...auth.user,
        subscription: {
          plan: response.data.plan,
          status: response.data.status,
          billing_cycle: response.data.billing_cycle,
          renews_on: response.data.renews_on,
          trial_ends_on: response.data.trial_ends_on,
          grace_ends_on: response.data.grace_ends_on,
        },
      }
    }
  } catch (error) {
    actionError.value = extractApiErrorMessage(error)
  }
}

function formatDate(value: string) {
  const [year, month, day] = value.split('-').map(Number)
  if (!year || !month || !day) return value
  return new Intl.DateTimeFormat(locale.value === 'en' ? 'en-US' : intlLocale(locale.value), {
    day: 'numeric',
    month: 'numeric',
    year: 'numeric',
  }).format(new Date(year, month - 1, day))
}

function planName(code: string) {
  return t(`subscriptionPage.plans.${code}.name`)
}

function relation(plan: CatalogPlan) {
  const current = plans.value.find(item => item.code === currentPlan.value)
  return Math.sign(plan.rank - (current?.rank ?? 0)) as -1 | 0 | 1
}

function limitText(plan: CatalogPlan, key: LimitKey) {
  const value = plan.limits[key]
  if (value === null || value === undefined) return t('subscriptionPage.unlimited')
  if (key === 'storage_mb') {
    const gb = value / 1024
    return t('subscriptionPage.limits.storage', { count: Number.isInteger(gb) ? String(gb) : gb.toFixed(1) })
  }
  return t(`subscriptionPage.limits.${key}`, {
    count: value,
    n: value.toLocaleString(locale.value),
  })
}

function moduleText(plan: CatalogPlan) {
  return plan.limits.modules.map(code => t(`platform.moduleNames.${code}`)).join(', ')
}

function usageWidth(key: LimitKey) {
  const used = subscription.value?.usage?.[key] ?? 0
  const limit = subscription.value?.limits?.[key]
  if (limit === null || limit === undefined || limit <= 0) return used > 0 ? '100%' : '0%'
  return `${Math.min(100, Math.round((used / limit) * 100))}%`
}

async function run(action: () => Promise<void>) {
  if (busy.value) return
  actionError.value = ''
  busy.value = true
  try {
    await action()
    await load()
  } catch (error) {
    actionError.value = extractApiErrorMessage(error)
  } finally {
    busy.value = false
  }
}

function upgrade(code: PlanCode) {
  return run(async () => {
    await api.patch('/tenant/subscription', { plan: code })
  })
}

function subscribe(code: PlanCode) {
  return run(async () => {
    await api.post('/tenant/subscription/subscribe', { plan: code, billing_cycle: currentCycle.value })
  })
}

function changeCycle() {
  return run(async () => {
    await api.patch('/tenant/subscription', { billing_cycle: currentCycle.value === 'yearly' ? 'monthly' : 'yearly' })
  })
}

function declare(invoiceId: string) {
  return run(async () => {
    await api.post('/tenant/subscription/payments', {
      invoice_id: invoiceId,
      method: 'transfer',
      reference: reference.value.trim() || undefined,
    })
    reference.value = ''
  })
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('subscriptionPage.title') }}</template>
    <template #subtitle>{{ t('subscriptionPage.subtitle') }}</template>

    <div class="sub">
      <p v-if="subscription?.status === 'suspended'" class="sub__error" role="alert">{{ t('subscriptionPage.suspendedNotice') }}</p>
      <p v-if="actionError" class="sub__error" role="alert">{{ actionError }}</p>

      <section v-if="currentDef" class="sub__hero" aria-labelledby="subscription-current">
        <div class="sub__hero-copy">
          <p class="sub__eyebrow">{{ t('subscriptionPage.currentTitle') }}</p>
          <div class="sub__hero-title">
            <span class="sub__mark sub__mark--hero" aria-hidden="true">
              <AppIcon :name="ICONS[currentPlan]" :size="22" />
            </span>
            <h2 id="subscription-current">{{ planName(currentPlan) }}</h2>
          </div>
          <p class="sub__hero-tagline">{{ t(`subscriptionPage.plans.${currentPlan}.tagline`) }}</p>
          <p class="sub__hero-price">{{ currentAmount }}</p>
          <p v-if="renewsLabel" class="sub__renewal">
            <AppIcon name="calendar" :size="15" />
            <span>{{ renewsLabel }}</span>
          </p>
          <p v-if="pendingLabel" class="sub__renewal">{{ pendingLabel }}</p>
        </div>

        <dl class="sub__facts">
          <div>
            <dt>{{ t('subscriptionPage.status') }}</dt>
            <dd><Badge :variant="statusVariant" dot>{{ statusLabel }}</Badge></dd>
          </div>
          <div>
            <dt>{{ t('subscriptionPage.plan') }}</dt>
            <dd>{{ planName(currentPlan) }}</dd>
          </div>
          <div>
            <dt>{{ t('subscriptionPage.cycle') }}</dt>
            <dd>{{ t(currentCycle === 'yearly' ? 'subscriptionPage.yearly' : 'subscriptionPage.monthly') }}</dd>
          </div>
          <div>
            <dt>{{ t('subscriptionPage.amount') }}</dt>
            <dd class="sub__amount">{{ currentAmount }}</dd>
          </div>
        </dl>
      </section>

      <section v-if="subscription?.usage" class="sub__usage" aria-labelledby="subscription-usage">
        <h2 id="subscription-usage">{{ t('subscriptionPage.usageTitle') }}</h2>
        <div class="sub__meters">
          <div v-for="key in LIMITS" :key="key">
            <div class="sub__meter-label">
              <span>{{ t(`platform.billing.${key === 'storage_mb' ? 'storage' : key}`) }}</span>
              <span>{{ subscription.usage[key] }} / {{ subscription.limits?.[key] ?? t('subscriptionPage.unlimited') }}</span>
            </div>
            <div class="sub__meter"><span :style="{ width: usageWidth(key) }" /></div>
          </div>
        </div>
      </section>

      <section class="sub__upgrades" aria-labelledby="subscription-upgrades">
        <div class="sub__section-head">
          <h2 id="subscription-upgrades">{{ t('subscriptionPage.upgradesTitle') }}</h2>
          <p class="sub__hint">{{ t('subscriptionPage.upgradesHint') }}</p>
        </div>
        <div class="sub__plans">
          <article
            v-for="plan in plans"
            :key="plan.code"
            class="sub__plan"
            :class="[`sub__plan--${plan.code}`, { 'sub__plan--current': plan.code === currentPlan, 'sub__plan--popular': plan.code === 'professional' }]"
          >
            <div class="sub__plan-top">
              <span class="sub__mark" aria-hidden="true"><AppIcon :name="ICONS[plan.code]" :size="18" /></span>
              <p v-if="plan.code === 'professional'" class="sub__flag">{{ t('subscriptionPage.mostPopular') }}</p>
              <Badge v-else-if="plan.code === currentPlan" :variant="statusVariant" dot>{{ statusLabel }}</Badge>
            </div>
            <h3>{{ plan.name }}</h3>
            <p class="sub__tagline">{{ t(`subscriptionPage.plans.${plan.code}.tagline`) }}</p>
            <p class="sub__price">
              <span class="sub__price-lead">{{ money(plan.monthly_price) }}</span>
              <span class="sub__price-unit">{{ t('subscriptionPage.monthly') }}</span>
            </p>
            <p class="sub__price-alt">{{ t('subscriptionPage.orYearly', { amount: money(plan.yearly_price) }) }}</p>
            <ul>
              <li v-for="key in LIMITS" :key="key"><span>{{ limitText(plan, key) }}</span></li>
              <li><span>{{ moduleText(plan) }}</span></li>
            </ul>
            <div class="sub__foot">
              <button v-if="plan.code === currentPlan" type="button" class="btn-secondary sub__cycle" :disabled="busy" @click="changeCycle">
                {{ t('subscriptionPage.changeCycle') }}
              </button>
              <button v-else-if="relation(plan) > 0" type="button" class="btn-primary sub__cycle" :disabled="busy" @click="upgrade(plan.code)">
                {{ t('subscriptionPage.upgrade') }}
              </button>
              <button v-else type="button" class="btn-secondary sub__cycle" :disabled="busy" @click="upgrade(plan.code)">
                {{ t('subscriptionPage.downgrade') }}
              </button>
              <button
                v-if="plan.code === currentPlan && subscription?.status !== 'active'"
                type="button"
                class="btn-primary sub__cycle"
                :disabled="busy"
                @click="subscribe(plan.code)"
              >
                {{ t('subscriptionPage.subscribe') }}
              </button>
            </div>
          </article>
        </div>
      </section>

      <section v-if="subscription?.invoices?.length" class="sub__usage">
        <h2>{{ t('subscriptionPage.invoicesTitle') }}</h2>
        <table class="ui-table min-w-full">
          <thead>
            <tr>
              <th>{{ t('subscriptionPage.plan') }}</th>
              <th>{{ t('subscriptionPage.amount') }}</th>
              <th>{{ t('subscriptionPage.status') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="invoice in subscription.invoices" :key="invoice.id">
              <td>{{ invoice.number }}</td>
              <td>{{ money(invoice.amount) }}</td>
              <td>{{ invoice.status === 'paid' ? t('subscriptionPage.invoicePaid') : t('subscriptionPage.invoiceOpen') }}</td>
              <td>
                <form v-if="invoice.status === 'open'" class="sub__pay" @submit.prevent="declare(invoice.id)">
                  <input v-model="reference" class="field" type="text" :placeholder="t('subscriptionPage.paymentReference')" />
                  <button class="btn-secondary" type="submit" :disabled="busy">{{ t('subscriptionPage.declarePayment') }}</button>
                </form>
                <span v-else-if="invoice.payments.some(payment => payment.status === 'pending')">{{ t('subscriptionPage.invoicePending') }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.sub { display: flex; flex-direction: column; gap: var(--space-8); max-width: 90rem; }
.sub__hero {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(16rem, 0.85fr);
  gap: var(--space-7);
  align-items: center;
  padding: var(--space-7) var(--space-8);
  border: 1px solid var(--color-border);
  border-radius: 22px;
  background: var(--color-surface);
  box-shadow: var(--shadow-sm);
}
.sub__eyebrow { margin: 0; font-size: 0.72rem; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: var(--color-text-muted); }
.sub__hero-title { display: flex; align-items: center; gap: var(--space-3); margin-top: var(--space-3); }
.sub__hero h2, .sub__section-head h2, .sub__usage h2 { margin: 0; font-weight: 680; letter-spacing: -0.03em; }
.sub__hero h2 { font-size: clamp(1.8rem, 2.4vw, 2.35rem); }
.sub__hero-tagline { margin: var(--space-2) 0 0; max-width: 28rem; font-size: var(--text-sm); color: var(--color-text-muted); }
.sub__hero-price { margin: var(--space-5) 0 0; font-size: clamp(1.6rem, 2vw, 2rem); font-weight: 720; font-variant-numeric: tabular-nums; }
.sub__renewal { display: inline-flex; align-items: center; gap: 0.4rem; margin: var(--space-3) 0 0; font-size: var(--text-sm); color: var(--color-text-secondary); }
.sub__facts { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-3); margin: 0; }
.sub__facts div { display: flex; flex-direction: column; gap: 0.35rem; padding: 0.9rem 1rem; border-radius: 14px; background: var(--color-canvas); border: 1px solid var(--color-border); }
.sub__facts dt { margin: 0; font-size: 0.72rem; font-weight: 650; letter-spacing: 0.06em; text-transform: uppercase; color: var(--color-text-muted); }
.sub__facts dd { margin: 0; font-size: var(--text-sm); font-weight: 650; }
.sub__error { margin: 0; padding: 0.75rem 0.9rem; border-radius: 12px; border: 1px solid color-mix(in srgb, var(--color-danger) 28%, transparent); background: var(--color-danger-bg); font-size: var(--text-sm); color: var(--color-danger); }
.sub__hint { margin: var(--space-1) 0 0; font-size: var(--text-sm); color: var(--color-text-muted); }
.sub__plans { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: var(--space-4); margin-top: var(--space-5); }
.sub__plan { display: flex; flex-direction: column; min-width: 0; padding: 1.35rem 1.25rem 1.15rem; border: 1px solid var(--color-border); border-radius: 18px; background: var(--color-surface); box-shadow: var(--shadow-sm); }
.sub__plan--current { border-color: color-mix(in srgb, var(--color-brand-500) 55%, var(--color-border)); }
.sub__plan--popular { border-color: color-mix(in srgb, var(--color-brand-400) 70%, var(--color-border)); }
.sub__plan-top { display: flex; align-items: center; justify-content: space-between; gap: var(--space-2); min-height: 1.85rem; }
.sub__mark { display: grid; place-items: center; width: 2.15rem; height: 2.15rem; border-radius: 12px; background: var(--color-accent-soft); color: var(--color-ink-brand, var(--color-brand-700)); }
.sub__mark--hero { width: 2.6rem; height: 2.6rem; }
.sub__flag { margin: 0; padding: 0.22rem 0.6rem; border-radius: 999px; background: var(--color-brand-600); color: #fff; font-size: 0.68rem; font-weight: 700; text-transform: uppercase; }
.sub__plan h3 { margin: var(--space-4) 0 0; font-size: 1.2rem; }
.sub__tagline { margin: var(--space-1) 0 0; min-height: 2.6rem; font-size: var(--text-sm); color: var(--color-text-muted); }
.sub__price { display: flex; align-items: baseline; gap: 0.3rem; margin: var(--space-4) 0 0; }
.sub__price-lead { font-size: 1.7rem; font-weight: 740; letter-spacing: -0.04em; }
.sub__price-unit, .sub__price-alt { font-size: var(--text-sm); color: var(--color-text-muted); }
.sub__price-alt { margin: 0.35rem 0 0; }
.sub__plan ul { display: flex; flex-direction: column; gap: 0.45rem; margin: var(--space-4) 0 0; padding: var(--space-3) 0 0; border-top: 1px solid var(--color-border); list-style: none; font-size: var(--text-sm); color: var(--color-text-secondary); }
.sub__foot { display: flex; flex-direction: column; gap: var(--space-2); margin-top: auto; padding-top: var(--space-4); }
.sub__cycle { width: 100%; }
.sub__usage { display: flex; flex-direction: column; gap: var(--space-4); }
.sub__meters { display: grid; grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr)); gap: var(--space-3); }
.sub__meter-label { display: flex; justify-content: space-between; gap: 0.5rem; font-size: 0.78rem; color: var(--color-text-secondary); }
.sub__meter { height: 0.4rem; margin-top: 0.35rem; border-radius: 999px; background: var(--color-canvas); overflow: hidden; }
.sub__meter span { display: block; height: 100%; background: var(--color-brand-600); }
.sub__pay { display: flex; gap: 0.4rem; justify-content: flex-end; }
.sub__pay .field { min-width: 10rem; }
@media (max-width: 1100px) { .sub__plans { grid-template-columns: repeat(2, minmax(0, 1fr)); } .sub__hero { grid-template-columns: 1fr; } }
@media (max-width: 720px) { .sub__plans, .sub__facts { grid-template-columns: 1fr; } .sub__tagline { min-height: 0; } .sub__pay { flex-direction: column; } }
</style>
