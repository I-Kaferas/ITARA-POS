<script setup lang="ts">
import { useId } from 'vue'
import type { AppLocale } from '../../i18n/locales'

defineProps<{
  locale: AppLocale
}>()

const clipId = `flag-${useId()}`
</script>

<template>
  <span class="lang-flag" aria-hidden="true">
    <svg v-if="locale === 'fr'" viewBox="0 0 3 2" preserveAspectRatio="xMidYMid slice">
      <rect width="1" height="2" fill="#0055A4" />
      <rect x="1" width="1" height="2" fill="#fff" />
      <rect x="2" width="1" height="2" fill="#EF4135" />
    </svg>
    <svg v-else-if="locale === 'en'" viewBox="0 0 60 30" preserveAspectRatio="xMidYMid slice">
      <defs>
        <clipPath :id="clipId">
          <rect width="60" height="30" />
        </clipPath>
      </defs>
      <g :clip-path="`url(#${clipId})`">
        <rect width="60" height="30" fill="#012169" />
        <path d="M0 0l60 30M60 0L0 30" stroke="#fff" stroke-width="6" />
        <path d="M0 0l60 30M60 0L0 30" stroke="#C8102E" stroke-width="4" />
        <path d="M30 0v30M0 15h60" stroke="#fff" stroke-width="10" />
        <path d="M30 0v30M0 15h60" stroke="#C8102E" stroke-width="6" />
      </g>
    </svg>
    <svg v-else viewBox="0 0 72 48" preserveAspectRatio="xMidYMid slice">
      <rect width="72" height="48" fill="#1eb53a" />
      <path fill="#00a3dd" d="M72 0v48H0z" />
      <path fill="none" stroke="#fcd116" stroke-width="11" d="M0 48L72 0" />
      <path fill="none" stroke="#000" stroke-width="6.5" d="M0 48L72 0" />
    </svg>
  </span>
</template>

<style scoped>
.lang-flag {
  display: block;
  width: 100%;
  height: 100%;
  overflow: hidden;
  line-height: 0;
}

.lang-flag svg {
  display: block;
  width: 100%;
  height: 100%;
}
</style>
