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
  quantitiesByProductId?: Record<string, number>
  loading?: boolean
}>()

const emit = defineEmits<{
  select: [product: PosProduct]
  increment: [product: PosProduct]
  decrement: [product: PosProduct]
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

function qtyOf(product: PosProduct) {
  return props.quantitiesByProductId?.[product.product_id] ?? 0
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

function onPlus(event: Event, product: PosProduct) {
  event.stopPropagation()
  if (isSoldOut(product)) return
  emit('increment', product)
}

function onMinus(event: Event, product: PosProduct) {
  event.stopPropagation()
  emit('decrement', product)
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
      <article
        v-for="product in products"
        :key="product.product_id"
        class="pos-products__card"
        :class="{ 'pos-products__card--off': isSoldOut(product) }"
      >
        <button
          type="button"
          class="pos-products__hit"
          :disabled="isSoldOut(product)"
          @click="onSelect(product)"
        >
          <div class="pos-products__photo">
            <img
              v-if="imageSrc(product)"
              :src="imageSrc(product)"
              :alt="product.name"
              loading="lazy"
              decoding="async"
              fetchpriority="low"
            />
            <span v-else class="pos-products__nophoto">
              <AppIcon name="products" :size="32" />
            </span>
            <span v-if="isSoldOut(product)" class="pos-products__badge pos-products__badge--out">{{ t('pos.outShort') }}</span>
            <span v-else-if="hasOptions(product)" class="pos-products__badge pos-products__badge--opt">{{ t('pos.optionsShort') }}</span>
          </div>
          <div class="pos-products__body">
            <p class="pos-products__name">{{ product.name }}</p>
            <p class="pos-products__meta">
              <span v-if="product.category_name">{{ product.category_name }}</span>
              <span
                v-if="needsSaleQuantity(product)"
                class="pos-products__stock"
                :class="{ 'pos-products__stock--out': isSoldOut(product) }"
              >
                · {{ availableOnHand(product) ?? '—' }} {{ t('pos.available') }}
              </span>
            </p>
          </div>
        </button>

        <div class="pos-products__footer">
          <p class="pos-products__price">
            {{ formatMoney(product.price || 0, currency) }}
            <span class="pos-products__unit">{{ unitLabel(product) }}</span>
          </p>
          <div class="pos-products__qty" @click.stop>
            <button
              type="button"
              class="pos-products__qty-btn"
              :disabled="qtyOf(product) <= 0"
              :aria-label="t('common.delete')"
              @click="onMinus($event, product)"
            >
              −
            </button>
            <span class="pos-products__qty-val">{{ qtyOf(product) }}</span>
            <button
              type="button"
              class="pos-products__qty-btn pos-products__qty-btn--plus"
              :disabled="isSoldOut(product)"
              :aria-label="t('beverages.add')"
              @click="onPlus($event, product)"
            >
              +
            </button>
          </div>
        </div>
      </article>
    </div>

    <div v-else class="pos-products__empty">
      <AppIcon name="products" :size="28" />
      <p>{{ emptyLabel }}</p>
    </div>
  </section>
</template>

<style scoped>
.pos-products {
  position: relative;
  z-index: 0;
  flex: 1 1 auto;
  width: 100%;
  max-width: 100%;
  min-width: 0;
  min-height: 0;
  overflow: auto;
  padding: 0.15rem 0.1rem 1rem;
}

.pos-products__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(12.5rem, 1fr));
  gap: 0.9rem;
}

.pos-products__card {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 16px;
  background: var(--color-surface, #fff);
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(18, 36, 60, 0.04);
  transition:
    transform 180ms ease,
    box-shadow 180ms ease,
    border-color 180ms ease;
}

.pos-products__card:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--color-brand-600, #12243c) 22%, var(--color-border));
  box-shadow: 0 10px 22px rgba(18, 36, 60, 0.08);
}

.pos-products__card--off {
  opacity: 0.72;
}

.pos-products__card--skel {
  pointer-events: none;
  box-shadow: none;
}

.pos-products__hit {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
  text-align: left;
  border: 0;
  background: transparent;
  padding: 0;
  cursor: pointer;
  color: inherit;
}

.pos-products__hit:disabled {
  cursor: not-allowed;
}

.pos-products__photo {
  position: relative;
  aspect-ratio: 1.2 / 1;
  background: var(--color-canvas, #eef1f5);
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
  padding: 0.15rem 0.5rem;
  font-size: 0.65rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #fff;
}

.pos-products__badge--out {
  background: #c2410c;
}

.pos-products__badge--opt {
  background: var(--color-accent, #e39b2b);
  color: #12243c;
}

.pos-products__body {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.75rem 0.85rem 0.35rem;
}

.pos-products__name {
  margin: 0;
  font-family: var(--font-display, var(--font-brand, inherit));
  font-size: 0.9rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
  line-height: 1.25;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.pos-products__meta {
  margin: 0;
  font-size: 0.72rem;
  color: var(--color-text-faint);
  line-height: 1.35;
}

.pos-products__stock--out {
  color: #c2410c;
  font-weight: 600;
}

.pos-products__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  padding: 0.35rem 0.85rem 0.85rem;
}

.pos-products__price {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 750;
  color: var(--color-brand-600, #12243c);
}

.pos-products__unit {
  font-weight: 500;
  color: var(--color-text-muted);
  font-size: 0.72rem;
}

.pos-products__qty {
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  padding: 0.15rem;
  border-radius: 999px;
  background: var(--color-canvas, #eef1f5);
  border: 1px solid var(--color-border, #dbe3ea);
}

.pos-products__qty-btn {
  width: 1.7rem;
  height: 1.7rem;
  border: 0;
  border-radius: 999px;
  background: var(--color-surface, #fff);
  color: var(--color-text-secondary);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
}

.pos-products__qty-btn:disabled {
  opacity: 0.35;
  cursor: default;
}

.pos-products__qty-btn--plus {
  background: var(--color-brand-600, #12243c);
  color: #fff;
}

.pos-products__qty-btn--plus:disabled {
  background: var(--color-brand-600, #12243c);
  color: #fff;
}

.pos-products__qty-val {
  min-width: 1.25rem;
  text-align: center;
  font-size: 0.8rem;
  font-weight: 750;
  font-variant-numeric: tabular-nums;
  color: var(--color-text-primary);
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
    grid-template-columns: repeat(auto-fill, minmax(10rem, 1fr));
  }
}
</style>
