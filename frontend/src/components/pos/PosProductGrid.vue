<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { formatMoney } from '../../utils/money'
import { availableStock, needsSaleQuantity } from '../../utils/product'
import type { PosProduct } from '../../types/pos'

const props = defineProps<{
  sections: Array<{ id: string; name: string; depth?: number; products: PosProduct[] }>
  currency?: string
  emptyLabel: string
  reservedByProductId?: Record<string, number>
  loading?: boolean
}>()

const emit = defineEmits<{
  select: [product: PosProduct]
}>()

const { t } = useI18n()

const products = computed(() => {
  const seen = new Set<string>()
  const list: PosProduct[] = []
  for (const section of props.sections) {
    for (const product of section.products) {
      if (seen.has(product.product_id)) continue
      seen.add(product.product_id)
      list.push(product)
    }
  }
  return list
})

function availableOnHand(product: PosProduct): number | null {
  return availableStock(product, props.reservedByProductId)
}

function isSoldOut(product: PosProduct) {
  if (product.is_available === false) return true
  if (!needsSaleQuantity(product)) return false
  const available = availableOnHand(product)
  return available !== null && available <= 0
}

function hasOptions(product: PosProduct) {
  return (product.variants?.length ?? 0) > 0 || (product.option_groups?.length ?? 0) > 0 || (product.sale_units?.length ?? 0) > 1
}

function unitLabel(product: PosProduct) {
  const base = product.sale_units?.find(item => item.is_base) ?? product.sale_units?.[0]
  if (base?.name) return `/${base.name}`
  const unit = product.unit?.trim()
  if (unit && unit.length <= 16) return `/${unit}`
  return ''
}

function stockCaption(product: PosProduct) {
  const available = availableOnHand(product)
  if (available === null) return product.stock_display || '—'
  if (available <= 0) return t('pos.zeroAvailable')
  return `${available} ${t('pos.available')}`
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

function onSelect(product: PosProduct) {
  if (isSoldOut(product)) return
  emit('select', product)
}
</script>

<template>
  <section class="pos-products">
    <div
      v-if="loading"
      class="pos-products__grid"
      role="status"
      :aria-label="t('common.loading')"
    >
      <div
        v-for="i in 12"
        :key="i"
        class="pos-products__card pos-products__card--skel"
        aria-hidden="true"
      >
        <div class="pos-products__photo">
          <span class="ui-skeleton ui-skeleton--thumb" />
        </div>
        <div class="pos-products__body">
          <span class="ui-skeleton ui-skeleton--md" :style="{ width: `${68 + (i % 3) * 8}%` }" />
          <span class="ui-skeleton ui-skeleton--sm" :style="{ width: `${38 + (i % 4) * 6}%` }" />
          <span class="ui-skeleton ui-skeleton--sm" :style="{ width: `${28 + (i % 5) * 5}%` }" />
        </div>
      </div>
    </div>

    <div v-else-if="products.length" class="pos-products__grid">
      <button
        v-for="product in products"
        :key="product.product_id"
        type="button"
        class="pos-products__card"
        :class="{ 'pos-products__card--off': isSoldOut(product) }"
        :disabled="isSoldOut(product)"
        @click="onSelect(product)"
      >
        <div class="pos-products__photo">
          <img v-if="imageSrc(product)" :src="imageSrc(product)" :alt="product.name" />
          <span v-else class="pos-products__nophoto">
            <AppIcon name="products" :size="32" />
          </span>
          <span v-if="isSoldOut(product)" class="pos-products__badge pos-products__badge--out">{{ t('pos.outShort') }}</span>
          <span v-else-if="hasOptions(product)" class="pos-products__badge pos-products__badge--opt">{{ t('pos.optionsShort') }}</span>
        </div>
        <div class="pos-products__body">
          <p class="pos-products__name">{{ product.name }}</p>
          <p class="pos-products__price">
            {{ formatMoney(product.price || 0, currency) }}
            <span class="pos-products__unit">{{ unitLabel(product) }}</span>
          </p>
          <p v-if="product.category_name" class="pos-products__cat">{{ product.category_name }}</p>
          <p
            v-if="needsSaleQuantity(product)"
            class="pos-products__stock"
            :class="{ 'pos-products__stock--out': isSoldOut(product) }"
          >
            {{ stockCaption(product) }}
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
  flex: 1 1 auto;
  min-width: 0;
  min-height: 0;
  overflow: auto;
  padding: 0.25rem 0.15rem 1rem;
}

.pos-products__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(11.5rem, 1fr));
  gap: 0.85rem;
}

.pos-products__card {
  display: flex;
  flex-direction: column;
  text-align: left;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: #fff;
  overflow: hidden;
  cursor: pointer;
  box-shadow: var(--shadow-xs);
  transition:
    transform var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out);
}

.pos-products__card:hover:not(:disabled) {
  transform: translateY(-2px);
  border-color: var(--color-brand-200);
  box-shadow: var(--shadow-sm);
}

.pos-products__card--off {
  opacity: 0.72;
  cursor: not-allowed;
}

.pos-products__card--skel {
  pointer-events: none;
  cursor: default;
  box-shadow: none;
}

.pos-products__card--skel .pos-products__body {
  gap: 0.45rem;
}

.pos-products__photo {
  position: relative;
  aspect-ratio: 1.15 / 1;
  background: var(--color-canvas);
  display: grid;
  place-items: center;
  overflow: hidden;
}

.pos-products__photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.pos-products__nophoto {
  color: var(--color-text-faint);
}

.pos-products__badge {
  position: absolute;
  top: 0.55rem;
  right: 0.55rem;
  border-radius: 999px;
  padding: 0.15rem 0.45rem;
  font-size: 0.65rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #fff;
}

.pos-products__badge--out {
  background: #ef4444;
}

.pos-products__badge--opt {
  background: var(--color-brand-600);
}

.pos-products__body {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.75rem 0.8rem 0.9rem;
}

.pos-products__name {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-text-primary);
  line-height: 1.25;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.pos-products__price {
  margin: 0.15rem 0 0;
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-brand-600);
}

.pos-products__unit {
  font-weight: 500;
  color: var(--color-text-muted);
  font-size: 0.75rem;
}

.pos-products__cat {
  margin: 0;
  font-size: 0.72rem;
  color: var(--color-text-faint);
}

.pos-products__stock {
  margin: 0.15rem 0 0;
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--color-text-muted);
}

.pos-products__stock--out {
  color: #dc2626;
}

.pos-products__empty {
  display: grid;
  place-items: center;
  gap: 0.5rem;
  min-height: 12rem;
  color: var(--color-text-muted);
  font-size: 0.9rem;
}

@media (max-width: 900px) {
  .pos-products__grid {
    grid-template-columns: repeat(auto-fill, minmax(9.5rem, 1fr));
  }
}
</style>
