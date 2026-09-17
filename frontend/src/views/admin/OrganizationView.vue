<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../components/layout/PageFrame.vue'
import { useBackofficeStore } from '../../stores/backoffice'

const { t } = useI18n()
const store = useBackofficeStore()

onMounted(async () => {
  await store.loadCompanies()
  const details = await Promise.all(store.companies.map(c => store.loadCompanyDetail(c.id)))
  store.companies.splice(0, store.companies.length, ...details)
})
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.organization') }}</template>

    <div class="space-y-6">
      <div
        v-for="company in store.companies"
        :key="company.id"
        class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200"
      >
        <div class="mb-4 flex items-center justify-between">
          <div>
            <h3 class="text-lg font-semibold">{{ company.name }}</h3>
            <p class="text-sm text-slate-500">{{ company.currency_code }} · {{ company.is_active ? t('products.active') : t('products.inactive') }}</p>
          </div>
        </div>

        <div v-if="company.branches?.length" class="space-y-4">
          <div v-for="branch in company.branches" :key="branch.id" class="rounded-lg bg-slate-50 p-4">
            <p class="font-medium">{{ branch.name }} <span class="text-slate-400">({{ branch.code }})</span></p>
            <ul v-if="branch.stores?.length" class="mt-2 space-y-1 pl-4">
              <li v-for="s in branch.stores" :key="s.id" class="text-sm text-slate-600">
                ⌂ {{ s.name }} — {{ s.code }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </PageFrame>
</template>
