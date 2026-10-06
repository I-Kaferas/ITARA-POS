<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'

type Manufacturer = {
  id: string
  name: string
  description: string
  contactPerson: string
  email: string
  phone: string
  address: string
  city: string
  country: string
  website: string
  active: boolean
}

const manufacturers = ref<Manufacturer[]>([])

const { t } = useI18n()
const query = ref('')
const creating = ref(false)
const form = ref(blankForm())

const dirty = computed(() => {
  const current = form.value
  return creating.value && (
    current.name.trim() !== ''
    || current.description.trim() !== ''
    || current.contactPerson.trim() !== ''
    || current.email.trim() !== ''
    || current.phone.trim() !== ''
    || current.address.trim() !== ''
    || current.city.trim() !== ''
    || current.country.trim() !== ''
    || current.website.trim() !== ''
    || !current.active
  )
})

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return manufacturers.value
  return manufacturers.value.filter((item) =>
    [item.name, item.description, item.contactPerson, item.email, item.phone, item.address, item.city, item.country, item.website]
      .join(' ')
      .toLowerCase()
      .includes(q),
  )
})

function blankForm() {
  return {
    name: '',
    description: '',
    contactPerson: '',
    email: '',
    phone: '',
    address: '',
    city: '',
    country: '',
    website: '',
    active: true,
  }
}

function contactLabel(item: Manufacturer) {
  return item.contactPerson || item.email || item.phone
}

function locationLabel(item: Manufacturer) {
  return [item.city, item.country].filter(Boolean).join(', ') || item.address
}

function openCreate() {
  form.value = blankForm()
  creating.value = true
}

function closeCreate() {
  creating.value = false
}

function save() {
  const name = form.value.name.trim()
  if (!name) return
  manufacturers.value.unshift({
    id: `${Date.now()}`,
    name,
    description: form.value.description.trim(),
    contactPerson: form.value.contactPerson.trim(),
    email: form.value.email.trim(),
    phone: form.value.phone.trim(),
    address: form.value.address.trim(),
    city: form.value.city.trim(),
    country: form.value.country.trim(),
    website: form.value.website.trim(),
    active: form.value.active,
  })
  creating.value = false
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.inventoryItems.manufacturers') }}</template>
    <template #subtitle>{{ t('orgManufacturers.subtitle') }}</template>

    <div class="manufacturers">
      <div class="manufacturers__toolbar">
        <button type="button" class="btn-primary" @click="openCreate">
          {{ t('orgManufacturers.add') }}
        </button>
        <label class="manufacturers__search">
          <span class="sr-only">{{ t('orgManufacturers.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('orgManufacturers.searchPlaceholder')"
          />
        </label>
      </div>

      <div class="ui-table-wrap">
        <div class="overflow-x-auto">
          <table class="ui-table manufacturers__table">
            <thead>
              <tr>
                <th>{{ t('orgManufacturers.columns.name') }}</th>
                <th>{{ t('orgManufacturers.columns.contact') }}</th>
                <th>{{ t('orgManufacturers.columns.location') }}</th>
                <th>{{ t('orgManufacturers.columns.status') }}</th>
                <th>{{ t('orgManufacturers.columns.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!filtered.length">
                <td colspan="5" class="manufacturers__empty">{{ t('orgManufacturers.empty') }}</td>
              </tr>
              <tr v-for="item in filtered" :key="item.id">
                <td class="manufacturers__name">{{ item.name }}</td>
                <td :class="{ 'manufacturers__muted': !contactLabel(item) }">{{ contactLabel(item) || '—' }}</td>
                <td :class="{ 'manufacturers__muted': !locationLabel(item) }">{{ locationLabel(item) || '—' }}</td>
                <td>
                  <Badge :variant="item.active ? 'success' : 'neutral'" dot>
                    {{ item.active ? t('orgManufacturers.active') : t('orgManufacturers.inactive') }}
                  </Badge>
                </td>
                <td></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <AppModal
      :open="creating"
      :title="t('orgManufacturers.add')"
      icon="organization"
      tone="accent"
      size="lg"
      :dirty="dirty"
      @close="closeCreate"
    >
      <form id="manufacturer-form" class="manufacturers-form" @submit.prevent="save">
        <div>
          <FieldLabel icon="organization">{{ t('orgManufacturers.fields.name') }}</FieldLabel>
          <input v-model="form.name" class="field" required maxlength="120" :placeholder="t('orgManufacturers.placeholders.name')" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('orgManufacturers.fields.description') }}</FieldLabel>
          <textarea v-model="form.description" class="field" rows="3" maxlength="400" :placeholder="t('orgManufacturers.placeholders.description')" />
        </div>
        <div>
          <FieldLabel icon="account">{{ t('orgManufacturers.fields.contactPerson') }}</FieldLabel>
          <input v-model="form.contactPerson" class="field" maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="mail">{{ t('orgManufacturers.fields.email') }}</FieldLabel>
          <input v-model="form.email" class="field" type="email" maxlength="120" :placeholder="t('orgManufacturers.placeholders.email')" />
        </div>
        <div>
          <FieldLabel icon="phone">{{ t('orgManufacturers.fields.phone') }}</FieldLabel>
          <input v-model="form.phone" class="field" type="tel" maxlength="40" :placeholder="t('orgManufacturers.placeholders.phone')" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgManufacturers.fields.address') }}</FieldLabel>
          <input v-model="form.address" class="field" maxlength="160" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgManufacturers.fields.city') }}</FieldLabel>
          <input v-model="form.city" class="field" maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgManufacturers.fields.country') }}</FieldLabel>
          <input v-model="form.country" class="field" maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="globe">{{ t('orgManufacturers.fields.website') }}</FieldLabel>
          <input v-model="form.website" class="field" type="url" maxlength="200" :placeholder="t('orgManufacturers.placeholders.website')" />
        </div>
        <label class="manufacturers-form__check">
          <input v-model="form.active" type="checkbox" />
          {{ t('orgManufacturers.active') }}
        </label>
      </form>
      <template #footer>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="closeCreate">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" form="manufacturer-form">{{ t('common.save') }}</button>
        </div>
      </template>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.manufacturers {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.manufacturers__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.manufacturers__search {
  display: flex;
  flex: 1;
  min-width: 16rem;
}

.manufacturers__search .field {
  width: 100%;
}

.manufacturers__table td {
  height: auto;
  padding-top: var(--space-3);
  padding-bottom: var(--space-3);
}

.manufacturers__name {
  font-weight: 600;
  color: var(--color-text-primary);
}

.manufacturers__muted,
.manufacturers__empty {
  color: var(--color-text-muted);
}

.manufacturers__empty {
  text-align: center;
  padding-block: var(--space-8);
}

.manufacturers-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.manufacturers-form__check {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}
</style>
