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

type PlanId = 'starter' | 'professional' | 'enterprise'
type BillingCycle = 'monthly' | 'yearly'
type SubscriptionStatus = NonNullable<User['subscription']>['status']

const FEATURES = ['users', 'devices', 'warehouses', 'products', 'modules', 'storage', 'support'] as const
const FEATURE_ICONS: Record<(typeof FEATURES)[number], string> = {
  users: 'organization',
  devices: 'device-pos',
  warehouses: 'stores',
  products: 'products',
  modules: 'layers',
  storage: 'package',
  support: 'mail',
}
const PLAN_ICONS: Record<PlanId, string> = {
  starter: 'sparkles',
  professional: 'layers',
  enterprise: 'building',
}
const RANK: Record<PlanId, number> = { starter: 1, professional: 2, enterprise: 3 }

const plans: { id: PlanId; monthly: number; yearly: number; popular?: boolean }[] = [
  { id: 'starter', monthly: 7, yearly: 50 },
  { id: 'professional', monthly: 15, yearly: 100, popular: true },
  { id: 'enterprise', monthly: 50, yearly: 200 },
]

const { t, locale } = useI18n()
const auth = useAuthStore()
const cycleAttempted = ref(false)
const upgrading = ref<PlanId | null>(null)
const actionError = ref('')

const subscription = computed(() => auth.user?.subscription ?? null)
const currentPlan = computed<PlanId>(() => subscription.value?.plan ?? 'starter')
const currentCycle = computed<BillingCycle>(() => subscription.value?.billing_cycle ?? 'yearly')
const currentPlanDef = computed(() => plans.find(plan => plan.id === currentPlan.value) ?? plans[0])

const usdExact = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})
const usdWhole = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
})

const renewsLabel = computed(() => {
  const value = subscription.value?.renews_on
  if (!value) return ''
  const [year, month, day] = value.split('-').map(Number)
  if (!year || !month || !day) return ''
  const formatted = new Intl.DateTimeFormat(locale.value === 'en' ? 'en-US' : intlLocale(locale.value), {
    month: 'numeric',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(year, month - 1, day))
  return t('subscriptionPage.nextBilling', { date: formatted })
})

const currentAmount = computed(() => {
  const yearly = currentCycle.value === 'yearly'
  const amount = yearly ? currentPlanDef.value.yearly : currentPlanDef.value.monthly
  return t(yearly ? 'subscriptionPage.perYear' : 'subscriptionPage.perMonth', {
    amount: usdExact.format(amount),
  })
})

const statusLabel = computed(() => {
  const status: SubscriptionStatus = subscription.value?.status ?? 'active'
  if (status === 'trial') return t('subscriptionPage.statusTrial')
  if (status === 'past_due') return t('subscriptionPage.statusPastDue')
  if (status === 'cancelled') return t('subscriptionPage.statusCancelled')
  return t('subscriptionPage.active')
})

const statusVariant = computed(() => {
  const status = subscription.value?.status ?? 'active'
  if (status === 'past_due') return 'warning' as const
  if (status === 'cancelled') return 'danger' as const
  if (status === 'trial') return 'info' as const
  return 'success' as const
})

function relation(planId: PlanId) {
  return Math.sign(RANK[planId] - RANK[currentPlan.value]) as -1 | 0 | 1
}

onMounted(() => {
  void auth.fetchMe()
})

async function upgrade(planId: PlanId) {
  if (upgrading.value || relation(planId) <= 0) return
  actionError.value = ''
  upgrading.value = planId
  try {
    const response = await api.patch<{ data: NonNullable<User['subscription']> }>('/tenant/subscription', { plan: planId })
    if (auth.user) auth.user = { ...auth.user, subscription: response.data }
  } catch (error) {
    actionError.value = extractApiErrorMessage(error)
  } finally {
    upgrading.value = null
  }
}

function priceYear(amount: number) {
  return t('subscriptionPage.orYearly', { amount: usdWhole.format(amount) })
}

function periodSuffix(key: 'subscriptionPage.perMonth') {
  return t(key, { amount: '\u0001' }).replace('\u0001', '').trim()
}

function yearlyDiscount(plan: { monthly: number; yearly: number }) {
  const full = plan.monthly * 12
  if (full <= 0 || plan.yearly >= full) return ''
  return `−${Math.round((1 - plan.yearly / full) * 100)}%`
}

async function requestCycleChange(event: Event) {
  if (currentCycle.value === 'monthly') {
    actionError.value = ''
    try {
      const response = await api.patch<{ data: NonNullable<User['subscription']> }>('/tenant/subscription', { billing_cycle: 'yearly' })
      if (auth.user) auth.user = { ...auth.user, subscription: response.data }
    } catch (error) {
      actionError.value = extractApiErrorMessage(error)
    }
    return
  }

  cycleAttempted.value = true
  const note = (event.currentTarget as HTMLElement).closest('article')?.querySelector('.sub__note')
  if (note instanceof HTMLElement) note.focus()
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('subscriptionPage.title') }}</template>
    <template #subtitle>{{ t('subscriptionPage.subtitle') }}</template>

    <div class="sub">
      <section class="sub__hero" aria-labelledby="subscription-current">
        <div class="sub__hero-copy">
          <p class="sub__eyebrow">{{ t('subscriptionPage.currentTitle') }}</p>
          <div class="sub__hero-title">
            <span class="sub__mark sub__mark--hero" aria-hidden="true">
              <AppIcon :name="PLAN_ICONS[currentPlan]" :size="22" />
            </span>
            <h2 id="subscription-current">{{ t(`subscriptionPage.plans.${currentPlan}.name`) }}</h2>
          </div>
          <p class="sub__hero-tagline">{{ t(`subscriptionPage.plans.${currentPlan}.tagline`) }}</p>
          <p class="sub__hero-price">{{ currentAmount }}</p>
          <p v-if="renewsLabel" class="sub__renewal">
            <AppIcon name="calendar" :size="15" />
            <span>{{ renewsLabel }}</span>
          </p>
        </div>

        <dl class="sub__facts">
          <div>
            <dt>{{ t('subscriptionPage.status') }}</dt>
            <dd><Badge :variant="statusVariant" dot>{{ statusLabel }}</Badge></dd>
          </div>
          <div>
            <dt>{{ t('subscriptionPage.plan') }}</dt>
            <dd>{{ t(`subscriptionPage.plans.${currentPlan}.name`) }}</dd>
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

      <p v-if="actionError" class="sub__error" role="alert">{{ actionError }}</p>

      <section class="sub__upgrades" aria-labelledby="subscription-upgrades">
        <div class="sub__section-head">
          <h2 id="subscription-upgrades">{{ t('subscriptionPage.upgradesTitle') }}</h2>
          <p class="sub__hint">{{ t('subscriptionPage.upgradesHint') }}</p>
        </div>

        <div class="sub__plans">
          <article
            v-for="plan in plans"
            :key="plan.id"
            class="sub__plan"
            :class="[
              `sub__plan--${plan.id}`,
              {
                'sub__plan--current': plan.id === currentPlan,
                'sub__plan--popular': plan.popular,
              },
            ]"
          >
            <div class="sub__plan-top">
              <span class="sub__mark" aria-hidden="true">
                <AppIcon :name="PLAN_ICONS[plan.id]" :size="18" />
              </span>
              <p v-if="plan.popular" class="sub__flag">{{ t('subscriptionPage.mostPopular') }}</p>
              <Badge v-else-if="plan.id === currentPlan" :variant="statusVariant" dot>{{ statusLabel }}</Badge>
            </div>

            <h3>{{ t(`subscriptionPage.plans.${plan.id}.name`) }}</h3>
            <p class="sub__tagline">{{ t(`subscriptionPage.plans.${plan.id}.tagline`) }}</p>

            <p class="sub__price">
              <span class="sub__price-lead">{{ usdWhole.format(plan.monthly) }}</span>
              <span class="sub__price-unit">{{ periodSuffix('subscriptionPage.perMonth') }}</span>
            </p>
            <p class="sub__price-alt">
              <span>{{ priceYear(plan.yearly) }}</span>
              <span v-if="yearlyDiscount(plan)" class="sub__save">{{ yearlyDiscount(plan) }}</span>
            </p>

            <ul>
              <li v-for="feature in FEATURES" :key="feature">
                <span class="sub__check" aria-hidden="true">
                  <AppIcon :name="FEATURE_ICONS[feature]" :size="13" />
                </span>
                <span>{{ t(`subscriptionPage.plans.${plan.id}.features.${feature}`) }}</span>
              </li>
            </ul>

            <div class="sub__foot">
              <button
                v-if="plan.id === currentPlan"
                type="button"
                class="btn-secondary sub__cycle"
                @click="requestCycleChange"
              >
                {{ t('subscriptionPage.changeCycle') }}
              </button>
              <button
                v-else-if="relation(plan.id) > 0"
                type="button"
                class="btn-primary sub__cycle"
                :class="{ 'ui-btn--loading': upgrading === plan.id }"
                :disabled="upgrading !== null"
                @click="upgrade(plan.id)"
              >
                {{ t('subscriptionPage.upgrade') }}
              </button>

              <p v-if="relation(plan.id) < 0" class="sub__note">
                {{ t('subscriptionPage.downgradeBlocked') }}
              </p>
              <p
                v-else-if="plan.id === currentPlan && currentCycle === 'yearly'"
                class="sub__note"
                :class="{ 'sub__note--hit': cycleAttempted }"
                tabindex="-1"
              >
                {{ t('subscriptionPage.yearlyLocked') }}
              </p>
            </div>
          </article>
        </div>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.sub {
  display: flex;
  flex-direction: column;
  gap: var(--space-8);
  max-width: 76rem;
}

.sub__hero {
  position: relative;
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

.sub__eyebrow {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.sub__hero-title {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  margin-top: var(--space-3);
}

.sub__hero h2,
.sub__section-head h2 {
  margin: 0;
  font-weight: 680;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.sub__hero h2 {
  font-size: clamp(1.8rem, 2.4vw, 2.35rem);
  color: var(--color-text-primary);
}

.sub__hero-tagline {
  margin: var(--space-2) 0 0;
  max-width: 28rem;
  font-size: var(--text-sm);
  line-height: 1.5;
  color: var(--color-text-muted);
}

.sub__hero-price {
  margin: var(--space-5) 0 0;
  font-size: clamp(1.6rem, 2vw, 2rem);
  font-weight: 720;
  letter-spacing: -0.04em;
  font-variant-numeric: tabular-nums;
  color: var(--color-text-primary);
}

.sub__renewal {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin: var(--space-3) 0 0;
  font-size: var(--text-sm);
  color: var(--color-text-secondary);
}

.sub__facts {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-3);
  margin: 0;
}

.sub__facts div {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  min-width: 0;
  padding: 0.9rem 1rem;
  border-radius: 14px;
  background: var(--color-canvas);
  border: 1px solid var(--color-border);
}

.sub__facts dt {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 650;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.sub__facts dd {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 650;
  color: var(--color-text-primary);
}

.sub__amount {
  font-variant-numeric: tabular-nums;
}

.sub__error {
  margin: calc(var(--space-5) * -1) 0 0;
  padding: 0.75rem 0.9rem;
  border-radius: 12px;
  border: 1px solid color-mix(in srgb, var(--color-danger) 28%, transparent);
  background: var(--color-danger-bg);
  font-size: var(--text-sm);
  color: var(--color-danger);
}

.sub__section-head h2 {
  font-size: var(--text-xl);
  color: var(--color-text-primary);
}

.sub__hint {
  margin: var(--space-1) 0 0;
  max-width: 36rem;
  font-size: var(--text-sm);
  line-height: 1.45;
  color: var(--color-text-muted);
}

.sub__plans {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-4);
  margin-top: var(--space-5);
  align-items: stretch;
}

.sub__plan {
  position: relative;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 1.35rem 1.25rem 1.15rem;
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-sm);
  transition:
    transform 180ms ease,
    box-shadow 180ms ease,
    border-color 180ms ease;
}

.sub__plan::before {
  content: "";
  position: absolute;
  inset: 0 0 auto;
  height: 3px;
  background: var(--plan-accent);
}

.sub__plan--starter { --plan-accent: #94a3b8; }
.sub__plan--professional { --plan-accent: var(--color-brand-500); }
.sub__plan--enterprise { --plan-accent: var(--color-brand-700); }

.sub__plan:hover {
  transform: translateY(-3px);
  box-shadow: var(--shadow-md);
}

.sub__plan--popular {
  border-color: color-mix(in srgb, var(--color-brand-400) 70%, var(--color-border));
  box-shadow:
    0 16px 36px rgba(124, 58, 237, 0.12),
    var(--shadow-sm);
}

.sub__plan--current {
  border-color: color-mix(in srgb, var(--color-brand-500) 55%, var(--color-border));
  box-shadow:
    0 0 0 1px color-mix(in srgb, var(--color-brand-500) 35%, transparent),
    var(--shadow-md);
}

.sub__plan-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  min-height: 1.85rem;
}

.sub__mark {
  display: grid;
  place-items: center;
  width: 2.15rem;
  height: 2.15rem;
  border-radius: 12px;
  color: var(--color-ink-brand, var(--color-brand-700));
  background: var(--color-accent-soft);}

.sub__mark--hero {
  width: 2.6rem;
  height: 2.6rem;
  border-radius: 14px;
}

.sub__flag {
  margin: 0;
  padding: 0.22rem 0.6rem;
  border-radius: 999px;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22);
}

.sub__plan h3 {
  margin: var(--space-4) 0 0;
  font-size: 1.2rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.sub__tagline {
  margin: var(--space-1) 0 0;
  min-height: 2.6rem;
  font-size: var(--text-sm);
  line-height: 1.4;
  color: var(--color-text-muted);
}

.sub__price {
  display: flex;
  align-items: baseline;
  gap: 0.3rem;
  margin: var(--space-4) 0 0;
  color: var(--color-text-primary);
}

.sub__price-lead {
  font-size: 2.15rem;
  font-weight: 740;
  letter-spacing: -0.045em;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}

.sub__price-unit {
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-muted);
}

.sub__price-alt {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  margin: 0.4rem 0 0;
  font-size: var(--text-sm);
  font-weight: 500;
  color: var(--color-text-secondary);
}

.sub__save {
  padding: 0.08rem 0.4rem;
  border-radius: 999px;
  background: var(--color-success-bg);
  color: var(--color-success);
  font-size: 0.72rem;
  font-weight: 750;
  letter-spacing: 0.01em;
}

.sub__plan ul {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  margin: var(--space-5) 0 0;
  padding: var(--space-4) 0 0;
  border-top: 1px solid var(--color-border);
  list-style: none;
}

.sub__plan li {
  display: flex;
  align-items: flex-start;
  gap: 0.55rem;
  font-size: var(--text-sm);
  line-height: 1.35;
  color: var(--color-text-secondary);
}

.sub__check {
  display: grid;
  place-items: center;
  flex: none;
  width: 1.35rem;
  height: 1.35rem;
  margin-top: 0.02rem;
  border-radius: 999px;
  background: var(--color-accent-soft);
  color: var(--color-ink-brand, var(--color-brand-700));}

.sub__foot {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  margin-top: auto;
  padding-top: var(--space-5);
}

.sub__cycle {
  width: 100%;
  white-space: normal;
  text-align: center;
}

.sub__note {
  margin: 0;
  padding: 0.7rem 0.8rem;
  border-radius: 12px;
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
  font-size: var(--text-xs);
  line-height: 1.45;
  color: var(--color-text-muted);
}

.sub__note--hit {
  border-color: color-mix(in srgb, var(--color-warning) 40%, var(--color-border));
  background: var(--color-warning-bg);
  color: var(--color-text-secondary);
  outline: none;
}

@media (min-width: 1080px) {
  .sub__plan--popular:not(.sub__plan--current) {
    transform: translateY(-8px);
  }

  .sub__plan--popular:not(.sub__plan--current):hover {
    transform: translateY(-12px);
  }
}

@media (max-width: 960px) {
  .sub__hero {
    grid-template-columns: 1fr;
    padding: var(--space-6);
  }

  .sub__plans {
    grid-template-columns: 1fr;
  }

  .sub__tagline {
    min-height: 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  .sub__plan,
  .sub__plan--popular:not(.sub__plan--current) {
    transform: none;
    transition: none;
  }
}
</style>
