<script setup lang="ts">
import { computed, toRef } from 'vue'
import { useI18n } from 'vue-i18n'
import { intlLocale } from '../../i18n/locales'
import { useCountUp } from '../../motion/useCountUp'
import { motion } from '../../motion/tokens'
import { getAppCurrency } from '../../utils/currency'
import { formatMoney } from '../../utils/money'

const props = withDefaults(defineProps<{
  value: number
  format?: 'integer' | 'money' | 'decimal' | 'compact'
  digits?: number
  fixed?: boolean
  suffix?: string
  currency?: string
  duration?: number
}>(), {
  format: 'integer',
  digits: 1,
  fixed: false,
  suffix: '',
  currency: '',
  duration: motion.duration.kpi,
})

const { locale } = useI18n()
const displayed = useCountUp(toRef(props, 'value'), props.duration)

function render(amount: number) {
  const lang = intlLocale(locale.value)
  const currency = props.currency || undefined
  const suffix = props.suffix
  if (props.format === 'money') return `${formatMoney(Math.round(amount), currency, lang)}${suffix}`
  if (props.format === 'compact') {
    const major = (Number.isFinite(amount) ? amount : 0) / 100
    const abs = Math.abs(major)
    const code = currency || getAppCurrency()
    const body = new Intl.NumberFormat(lang, {
      maximumFractionDigits: 1,
      minimumFractionDigits: abs >= 1000 ? 1 : 0,
    })
    if (abs >= 1_000_000) return `${body.format(major / 1_000_000)}M ${code}${suffix}`
    if (abs >= 1_000) return `${body.format(major / 1_000)}K ${code}${suffix}`
    return `${formatMoney(Math.round(amount), currency, lang)}${suffix}`
  }
  if (props.format === 'decimal') {
    const digits = props.digits
    const places = props.fixed ? digits : 0
    const body = new Intl.NumberFormat(lang, {
      minimumFractionDigits: places,
      maximumFractionDigits: digits,
    }).format(amount)
    return `${body}${suffix}`
  }
  return `${new Intl.NumberFormat(lang).format(Math.round(amount))}${suffix}`
}

const text = computed(() => render(displayed.value))
const finalText = computed(() => render(props.value))
</script>

<template>
  <span class="count-up" :aria-label="finalText">{{ text }}</span>
</template>
