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

function hasOptions(product: PosProduct) {
  return (product.variants?.length ?? 0) > 0 || (product.option_groups?.length ?? 0) > 0 || (product.sale_units?.length ?? 0) > 1
}

function quantityLabel(product: PosProduct) {
  if (product.stock_display) return product.stock_display
  if (typeof product.quantity_on_hand === 'number') return String(product.quantity_on_hand)
  if (product.requires_stock === false || product.product_type === 'service' || product.product_type === 'digital') {
    return '—'
  }
  return '0'
}

function imageSrc(product: PosProduct) {
  const raw = product.primary_image_cdn_url?.trim()
  if (!raw) return ''
  try {
    const url = new URL(raw, window.location.origin)
    if (url.pathname.startsWith('/storage/')) return `${url.pathname}${url.search}`
  } catch {
    return raw
  }
  return raw
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
        <div class="pos-products__photo">
          <img v-if="imageSrc(product)" :src="imageSrc(product)" :alt="product.name" />
          <span v-else class="pos-products__nophoto">
            <AppIcon name="products" :size="28" />
            <span>{{ initial(product.name) }}</span>
          </span>
          <span v-if="product.is_available === false" class="pos-products__off">{{ t('pos.outOfStock') }}</span>
        </div>
        <div class="pos-products__body">
          <p class="pos-products__name">{{ product.name }}</p>
          <p class="pos-products__metric">
            <span>{{ t('products.price') }}</span>
            <strong>{{ formatMoney(product.price || 0, currency) }}</strong>
          </p>
          <p class="pos-products__metric">
            <span>{{ t('pos.stockQty') }}</span>
            <strong>{{ quantityLabel(product) }}</strong>
          </p>
          <p v-if="hasOptions(product)" class="pos-products__sku">{{ t('pos.chooseOption') }}</p>
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
  gap: 0.7rem;
  width: 100%;
  padding: 0.55rem 0.75rem 1rem;
  align-content: start;
}

.pos-products__card {
  display: flex;
  flex-direction: column;
  width: 100%;
  min-width: 0;
  border: 1px solid #d7e2ea;
  border-radius: 0.85rem;
  overflow: hidden;
  background: #fff;
  cursor: pointer;
  text-align: left;
  padding: 0;
  box-shadow: 0 1px 0 rgba(15, 23, 42, 0.03);
  transition: border-color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}

.pos-products__card:hover:not(:disabled) {
  transform: translateY(-1px);
  border-color: var(--color-brand-400, #7d9aaf);
  box-shadow: 0 8px 18px rgba(61, 92, 115, 0.12);
}

.pos-products__card:active:not(:disabled) {
  transform: translateY(0);
}

.pos-products__card--off {
  cursor: not-allowed;
}

.pos-products__card--off .pos-products__photo img {
  filter: grayscale(0.7);
  opacity: 0.55;
}

.pos-products__photo {
  position: relative;
  height: 7.5rem;
  background: #e8eef3;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.pos-products__photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.pos-products__nophoto {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.2rem;
  color: #7d93a3;
  font-size: 0.85rem;
  font-weight: 750;
}

.pos-products__off {
  position: absolute;
  top: 0.4rem;
  right: 0.4rem;
  padding: 0.12rem 0.4rem;
  border-radius: 999px;
  background: #fee2e2;
  color: #b91c1c;
  font-size: 0.65rem;
  font-weight: 700;
}

.pos-products__body {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: 0.6rem 0.65rem 0.7rem;
}

.pos-products__name {
  margin: 0;
  font-size: 0.84rem;
  font-weight: 700;
  color: #1c2830;
  line-height: 1.25;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  min-height: 2.1em;
}

.pos-products__metric {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.4rem;
  margin: 0;
}

.pos-products__metric span {
  font-size: 0.68rem;
  font-weight: 650;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.pos-products__metric strong {
  font-size: 0.92rem;
  font-weight: 750;
  color: #1c2830;
}

.pos-products__sku {
  margin: 0;
  font-size: 0.68rem;
  color: var(--color-brand-700, #3d5c73);
  font-weight: 650;
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
