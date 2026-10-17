<template>
  <div class="pos-preview" aria-hidden="true">
    <div class="pos-preview__chrome">
      <span class="pos-preview__dot" />
      <span class="pos-preview__dot" />
      <span class="pos-preview__dot" />
      <span class="pos-preview__title">{{ title }}</span>
      <span class="pos-preview__live">Live</span>
    </div>
    <div class="pos-preview__body">
      <aside class="pos-preview__rail">
        <div
          v-for="n in 4"
          :key="`rail-${n}`"
          class="pos-preview__rail-item"
          :style="{ '--i': n - 1 }"
        />
      </aside>
      <div class="pos-preview__grid">
        <div
          v-for="n in 6"
          :key="n"
          class="pos-preview__tile"
          :style="{ '--i': n - 1 }"
        >
          <span class="pos-preview__tile-bar" />
          <span class="pos-preview__tile-line" />
          <span class="pos-preview__tile-line pos-preview__tile-line--short" />
        </div>
        <div class="pos-preview__cursor" />
      </div>
      <div class="pos-preview__cart">
        <div
          v-for="n in 3"
          :key="`cart-${n}`"
          class="pos-preview__cart-row"
          :class="{ 'is-accent': n === 3 }"
          :style="{ '--i': n - 1 }"
        />
        <div class="pos-preview__pay">
          <span class="pos-preview__pay-label">{{ t('preview.checkout') }}</span>
          <span class="pos-preview__pay-shine" />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from '../i18n'

defineProps<{ title?: string }>()
const { t } = useI18n()
</script>
