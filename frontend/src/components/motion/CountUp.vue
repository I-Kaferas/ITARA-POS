<script setup lang="ts">
import { computed, toRef } from 'vue'
import { useI18n } from 'vue-i18n'
import { intlLocale } from '../../i18n/locales'
import { useCountUp } from '../../motion/useCountUp'
import { motion } from '../../motion/tokens'
import { formatMoney } from '../../utils/money'

const props = withDefaults(defineProps<{
  value: number
  format?: 'integer' | 'money'
  duration?: number
}>(), {
  format: 'integer',
  duration: motion.duration.kpi,
})

const { locale } = useI18n()
const displayed = useCountUp(toRef(props, 'value'), props.duration)

const text = computed(() => {
  const lang = intlLocale(locale.value)
  if (props.format === 'money') return formatMoney(Math.round(displayed.value), undefined, lang)
  return new Intl.NumberFormat(lang).format(Math.round(displayed.value))
})

const finalText = computed(() => {
  const lang = intlLocale(locale.value)
  if (props.format === 'money') return formatMoney(props.value, undefined, lang)
  return new Intl.NumberFormat(lang).format(Math.round(props.value))
})
</script>

<template>
  <span class="count-up" :aria-label="finalText">{{ text }}</span>
</template>
