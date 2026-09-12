<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { formatMoney } from '../../utils/money'
import { needsSaleQuantity } from '../../utils/product'
import type { PosCartLine } from '../../types/pos'

const props = defineProps<{
  lines: PosCartLine[]
  currency?: string
  emptyLabel: string
  lineTotals?: Record<string, number>
}>()

const emit = defineEmits<{
  increment: [lineId: string]
  decrement: [lineId: string]
  quantity: [lineId: string, quantity: number]
  remove: [lineId: string]
}>()

const { t } = useI18n()

const itemCount = computed(() => props.lines.reduce((sum, line) => sum + line.quantity, 0))
</script>

<template>
  <aside class="pos-cart">
    <div class="pos-cart__header">
      <div>
        <h2 class="pos-cart__title">{{ t('pos.cart') }}</h2>
        <p class="pos-cart__meta">{{ itemCount }} {{ t('pos.articles') }}</p>
      </div>
      <span class="pos-cart__count">{{ lines.length }}</span>
    </div>

    <div class="pos-cart__lines">
      <article v-for="line in lines" :key="line.lineId" class="pos-cart__line">
        <div class="pos-cart__media">
          <img v-if="line.product.primary_image_cdn_url" :src="line.product.primary_image_cdn_url" :alt="line.product.name" />
          <span v-else>{{ line.product.name.trim().charAt(0).toUpperCase() }}</span>
        </div>
        <div class="pos-cart__body">
          <div class="pos-cart__line-top">
            <div class="min-w-0">
              <p class="pos-cart__name">{{ line.product.name }}</p>
              <p class="pos-cart__sku">
                <span v-if="line.product.category_name">{{ line.product.category_name }} · </span>{{ line.product.sku }}
              </p>
            </div>
            <button class="pos-cart__remove" type="button" :title="t('common.delete')" @click="emit('remove', line.lineId)">×</button>
          </div>
              <p class="pos-cart__unit">{{ t('pos.unitPrice') }} {{ formatMoney(line.product.price, currency) }}<span v-if="line.saleUnitId"> · {{ line.product.name.split(' · ').slice(1).join(' · ') }}</span></p>
          <div class="pos-cart__line-bottom">
            <div v-if="needsSaleQuantity(line.product)" class="pos-cart__qty">
              <button type="button" @click="emit('decrement', line.lineId)">−</button>
              <input
                type="number"
                min="1"
                :value="line.quantity"
                @change="emit('quantity', line.lineId, Math.max(1, Number(($event.target as HTMLInputElement).value) || 1))"
              />
              <button type="button" @click="emit('increment', line.lineId)">+</button>
            </div>
            <span v-else class="pos-cart__no-qty">{{ t('pos.noQuantity') }}</span>
            <span class="pos-cart__amount">
              {{ formatMoney(lineTotals?.[line.lineId] ?? line.product.price * line.quantity, currency) }}
            </span>
          </div>
        </div>
      </article>

      <div v-if="!lines.length" class="pos-cart__empty">
        <span class="pos-cart__empty-mark">+</span>
        <p>{{ emptyLabel }}</p>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.pos-cart {
  width: 22rem;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  border-left: 1px solid #e7edf3;
  background: #fbfcfd;
}

.pos-cart__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.9rem 1rem 0.8rem;
  border-bottom: 1px solid #e7edf3;
  background: #fff;
}

.pos-cart__title {
  margin: 0;
  font-size: 1rem;
  font-weight: 750;
  letter-spacing: -0.02em;
}

.pos-cart__meta {
  margin: 0.15rem 0 0;
  font-size: 0.72rem;
  color: #94a3b8;
}

.pos-cart__count {
  background: var(--color-brand-100, #e4edf2);
  color: var(--color-brand-700, #3d5c73);
  font-size: 0.75rem;
  font-weight: 750;
  min-width: 1.6rem;
  text-align: center;
  padding: 0.2rem 0.5rem;
  border-radius: 999px;
}

.pos-cart__lines {
  flex: 1;
  overflow-y: auto;
  padding: 0.75rem;
}

.pos-cart__line {
  display: flex;
  gap: 0.7rem;
  background: #fff;
  border: 1px solid #e7edf3;
  border-radius: 0.9rem;
  padding: 0.7rem;
  margin-bottom: 0.55rem;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
}

.pos-cart__media {
  width: 3.1rem;
  height: 3.1rem;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  overflow: hidden;
  border-radius: 0.7rem;
  background: #e4edf2;
  color: #3d5c73;
  font-weight: 700;
}

.pos-cart__media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.pos-cart__body {
  min-width: 0;
  flex: 1;
}

.pos-cart__line-top {
  display: flex;
  justify-content: space-between;
  gap: 0.5rem;
}

.pos-cart__name {
  margin: 0;
  font-size: 0.84rem;
  font-weight: 700;
  line-height: 1.3;
  color: #0f172a;
}

.pos-cart__remove {
  border: 1px solid #fecaca;
  background: #fef2f2;
  color: #dc2626;
  width: 1.45rem;
  height: 1.45rem;
  border-radius: 999px;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  line-height: 1;
}

.pos-cart__remove:hover {
  background: #dc2626;
  border-color: #dc2626;
  color: #fff;
}

.pos-cart__sku,
.pos-cart__unit {
  margin: 0.15rem 0 0;
  font-size: 0.7rem;
  color: #94a3b8;
}

.pos-cart__sku {
  font-family: var(--font-mono);
}

.pos-cart__line-bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 0.65rem;
}

.pos-cart__no-qty {
  font-size: 0.72rem;
  color: #94a3b8;
}

.pos-cart__qty {
  display: flex;
  align-items: center;
  gap: 0.15rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  padding: 0.15rem;
}

.pos-cart__qty button {
  width: 1.7rem;
  height: 1.7rem;
  border: none;
  border-radius: 999px;
  background: #fff;
  cursor: pointer;
  font-size: 0.95rem;
  color: #334155;
}

.pos-cart__qty button:hover {
  background: var(--color-brand-600, #4a6d86);
  color: #fff;
}

.pos-cart__qty input {
  width: 2.2rem;
  border: 0;
  background: transparent;
  text-align: center;
  font-size: 0.82rem;
  font-weight: 750;
  font-family: var(--font-mono);
  color: #1c2830;
}

.pos-cart__qty input::-webkit-outer-spin-button,
.pos-cart__qty input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.pos-cart__amount {
  font-size: 0.9rem;
  font-weight: 750;
  color: #0f172a;
}

.pos-cart__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.65rem;
  min-height: 14rem;
  color: #94a3b8;
  text-align: center;
}

.pos-cart__empty-mark {
  width: 2.6rem;
  height: 2.6rem;
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: #eef3f7;
  color: var(--color-brand-600, #4a6d86);
  font-size: 1.4rem;
  font-weight: 700;
}

.pos-cart__empty p {
  margin: 0;
  max-width: 12rem;
  font-size: 0.85rem;
  line-height: 1.4;
}
</style>
