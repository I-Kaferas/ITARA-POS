<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { formatMoney } from '../../utils/money'
import type { PosProduct } from '../../types/pos'

const props = defineProps<{
  sections: Array<{ id: string; name: string; depth?: number; products: PosProduct[] }>
  currency?: string
  emptyLabel: string
}>()

const emit = defineEmits<{
  select: [product: PosProduct]
}>()

const { t } = useI18n()

const productCount = computed(() => props.sections.reduce((sum, section) => sum + section.products.length, 0))

const products = computed(() => props.sections.flatMap(section => section.products))

function initial(name: string) {
  return name.trim().charAt(0).toUpperCase() || '?'
}
</script>

<template>
  <section class="pos-products">
    <div class="pos-products__toolbar">
      <p class="pos-products__count">{{ productCount }} {{ t('pos.articles') }}</p>
    </div>

    <div v-if="products.length" class="pos-products__grid">
      <button
        v-for="product in products"
        :key="product.product_id"
        class="pos-products__card"
        :class="{ 'pos-products__card--off': product.is_available === false }"
        :disabled="product.is_available === false"
        @click="emit('select', product)"
      >
        <div class="pos-products__image">
          <img v-if="product.primary_image_cdn_url" :src="product.primary_image_cdn_url" :alt="product.name" />
          <span v-else class="pos-products__placeholder">{{ initial(product.name) }}</span>
          <span class="pos-products__price">{{ formatMoney(product.price, currency) }}</span>
        </div>
        <div class="pos-products__info">
          <p class="pos-products__name">{{ product.name }}</p>
          <p class="pos-products__sku">
            {{ product.sku }}<span v-if="product.unit"> · {{ product.unit }}</span>
            <span v-if="product.requires_stock === false || product.product_type === 'service' || product.product_type === 'digital'"> · {{ t('products.natures.service.label') }}</span>
          </p>
        </div>
      </button>
    </div>

    <div v-else class="pos-products__empty">
      <AppIcon name="products" :size="28" />
      <p>{{ emptyLabel }}</p>
    </div>
  </section>
</template>

<style scoped>
.pos-products {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  min-height: 0;
  background: #f4f7fa;
}

.pos-products__sections {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding-bottom: 1rem;
}

.pos-products__section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.85rem 0.85rem 0.15rem;
}

.pos-products__section-head h3 {
  margin: 0;
  font-size: 0.82rem;
  font-weight: 700;
  color: #1c2830;
}

.pos-products__section-head span {
  font-size: 0.7rem;
  font-weight: 700;
  color: #64748b;
  background: #e4edf2;
  border-radius: 999px;
  padding: 0.1rem 0.45rem;
}

.pos-products__section-empty {
  margin: 0.35rem 0.85rem 0.2rem;
  font-size: 0.75rem;
  color: #94a3b8;
}

.pos-products__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.7rem 0.9rem 0.15rem;
}

.pos-products__count {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 650;
  color: #64748b;
}

.pos-products__grid {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
  width: 100%;
  padding: 0.7rem 0.85rem 1rem;
  align-content: start;
}

.pos-products__card {
  display: flex;
  flex-direction: column;
  width: 100%;
  min-width: 0;
  max-width: none;
  border: 1px solid #e6edf3;
  border-radius: 1rem;
  overflow: hidden;
  background: #fff;
  cursor: pointer;
  text-align: left;
  padding: 0;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}

.pos-products__card:hover:not(:disabled) {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--color-brand-500, #5c7f96) 45%, white);
  box-shadow: 0 12px 24px rgba(74, 109, 134, 0.14);
}

.pos-products__card:active:not(:disabled) {
  transform: translateY(0);
}

.pos-products__card--off {
  opacity: 0.55;
  cursor: not-allowed;
}

.pos-products__image {
  position: relative;
  height: 7.25rem;
  background: #e4edf2;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.pos-products__image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.pos-products__placeholder {
  font-size: 1.85rem;
  font-weight: 750;
  color: var(--color-brand-600, #4a6d86);
}

.pos-products__price {
  position: absolute;
  right: 0.5rem;
  bottom: 0.5rem;
  margin: 0;
  padding: 0.2rem 0.5rem;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.82);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 750;
}

.pos-products__info {
  padding: 0.65rem 0.75rem 0.75rem;
}

.pos-products__name {
  margin: 0;
  font-size: 0.84rem;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  min-height: 2.15em;
}

.pos-products__sku {
  margin: 0.3rem 0 0;
  font-size: 0.7rem;
  color: #94a3b8;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}

.pos-products__empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  color: #94a3b8;
  text-align: center;
  padding: 2rem;
}

.pos-products__empty p {
  margin: 0;
  font-size: 0.9rem;
}
</style>
