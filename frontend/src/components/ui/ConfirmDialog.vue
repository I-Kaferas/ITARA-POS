<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import AppModal from './AppModal.vue'
import { useConfirm } from '../../composables/useConfirm'

const { t } = useI18n()
const { state, settle } = useConfirm()

function accept() {
  settle(true)
}

function cancel() {
  settle(false)
}
</script>

<template>
  <AppModal
    :open="state.open"
    :title="state.title || (state.mode === 'notice' ? t('common.notice') : t('common.confirmTitle'))"
    :size="state.items.length ? 'md' : 'sm'"
    :icon="state.mode === 'notice' ? 'info' : (state.danger ? 'trash' : 'alert')"
    :tone="state.mode === 'notice' ? 'info' : (state.danger ? 'danger' : 'warning')"
    :close-on-backdrop="false"
    @close="cancel"
  >
    <p class="confirm-dialog__message">{{ state.message }}</p>
    <ul v-if="state.items.length" class="confirm-dialog__items">
      <li v-for="(item, index) in state.items" :key="`${item.name}-${index}`">
        <span>
          <strong>{{ item.name }}</strong>
          <small v-if="item.detail">{{ item.detail }}</small>
        </span>
        <span v-if="item.quantity !== undefined && item.quantity !== ''" class="confirm-dialog__qty">{{ item.quantity }}</span>
      </li>
    </ul>
    <div class="app-modal__actions">
      <button v-if="state.mode === 'confirm'" type="button" class="btn-secondary" @click="cancel">
        {{ state.cancelLabel || t('common.cancel') }}
      </button>
      <button
        type="button"
        :class="state.danger ? 'btn-danger' : 'btn-primary'"
        @click="accept"
      >
        {{ state.confirmLabel || (state.mode === 'notice' ? t('common.ok') : t('common.delete')) }}
      </button>
    </div>
  </AppModal>
</template>

<style scoped>
.confirm-dialog__message {
  margin: 0 0 0.85rem;
  color: #334155;
  line-height: 1.5;
}

.confirm-dialog__items {
  margin: 0 0 1.1rem;
  padding: 0;
  list-style: none;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  overflow: hidden;
}

.confirm-dialog__items li {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.55rem 0.75rem;
  border-top: 1px solid #f1f5f9;
}

.confirm-dialog__items li:first-child {
  border-top: 0;
}

.confirm-dialog__items strong {
  display: block;
  font-size: 0.86rem;
  color: #1c2830;
}

.confirm-dialog__items small {
  display: block;
  color: #94a3b8;
  font-family: var(--font-mono);
}

.confirm-dialog__qty {
  font-family: var(--font-mono);
  font-weight: 650;
  color: #4a6d86;
  white-space: nowrap;
}
</style>
