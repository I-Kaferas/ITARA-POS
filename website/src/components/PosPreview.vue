<template>
  <div class="pos-preview" aria-hidden="true">
    <div class="pos-preview__chrome">
      <span class="pos-preview__dot" />
      <span class="pos-preview__dot" />
      <span class="pos-preview__dot" />
      <span class="pos-preview__title">{{ title }}</span>
    </div>
    <div class="pos-preview__body">
      <aside class="pos-preview__rail">
        <div class="pos-preview__rail-item is-active" />
        <div class="pos-preview__rail-item" />
        <div class="pos-preview__rail-item" />
        <div class="pos-preview__rail-item" />
      </aside>
      <div class="pos-preview__grid">
        <div v-for="n in 6" :key="n" class="pos-preview__tile">
          <span class="pos-preview__tile-bar" />
          <span class="pos-preview__tile-line" />
        </div>
      </div>
      <div class="pos-preview__cart">
        <div class="pos-preview__cart-row" />
        <div class="pos-preview__cart-row" />
        <div class="pos-preview__cart-row is-accent" />
        <div class="pos-preview__pay">Encaisser</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ title?: string }>()
</script>
