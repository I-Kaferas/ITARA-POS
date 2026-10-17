<script setup lang="ts">
defineProps<{ name: string }>()
</script>

<template>
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.75"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <!-- Point of sale / terminal -->
    <template v-if="name === 'POS'">
      <rect x="3" y="4" width="18" height="12" rx="2" />
      <path d="M8 20h8" />
      <path d="M12 16v4" />
      <path d="M7 8h4" />
      <path d="M7 11h7" />
    </template>

    <!-- Inventory / boxes -->
    <template v-else-if="name === 'INV'">
      <path d="M21 8 12 3 3 8l9 5 9-5Z" />
      <path d="M3 8v8l9 5" />
      <path d="M21 8v8l-9 5" />
      <path d="M12 13v8" />
    </template>

    <!-- Catalog / grid -->
    <template v-else-if="name === 'CAT'">
      <rect x="3" y="3" width="7" height="7" rx="1.2" />
      <rect x="14" y="3" width="7" height="7" rx="1.2" />
      <rect x="3" y="14" width="7" height="7" rx="1.2" />
      <rect x="14" y="14" width="7" height="7" rx="1.2" />
    </template>

    <!-- Organization / network -->
    <template v-else-if="name === 'ORG'">
      <circle cx="12" cy="12" r="2.5" />
      <circle cx="5" cy="7" r="2" />
      <circle cx="19" cy="7" r="2" />
      <circle cx="5" cy="17" r="2" />
      <circle cx="19" cy="17" r="2" />
      <path d="M7 8.2 10.2 10.5" />
      <path d="M16.8 8.2 13.8 10.5" />
      <path d="M7 15.8 10.2 13.5" />
      <path d="M16.8 15.8 13.8 13.5" />
    </template>

    <!-- Hospitality / utensils -->
    <template v-else-if="name === 'HOT'">
      <path d="M8 3v7a2 2 0 0 0 2 2h0a2 2 0 0 0 2-2V3" />
      <path d="M10 12v9" />
      <path d="M16 3v18" />
      <path d="M16 8h3a2 2 0 0 0 0-4h-3" />
    </template>

    <!-- Reporting / chart -->
    <template v-else-if="name === 'RPT' || name === 'AN'">
      <path d="M4 19V5" />
      <path d="M4 19h16" />
      <path d="M8 15v-4" />
      <path d="M12 15V8" />
      <path d="M16 15v-6" />
    </template>

    <!-- Cloud & local -->
    <template v-else-if="name === 'CL'">
      <path d="M7.5 18H17a4 4 0 0 0 .5-7.97A5.5 5.5 0 0 0 6.1 8.6 3.5 3.5 0 0 0 7.5 18Z" />
      <path d="M9 21h6" />
      <path d="M12 18v3" />
    </template>

    <!-- Real time / sync -->
    <template v-else-if="name === 'RT'">
      <path d="M21 12a9 9 0 1 1-2.6-6.3" />
      <path d="M21 4v6h-6" />
      <path d="M12 7v5l3 2" />
    </template>

    <!-- Security / lock -->
    <template v-else-if="name === 'SEC'">
      <rect x="5" y="11" width="14" height="10" rx="2" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
      <circle cx="12" cy="16" r="1.2" />
    </template>

    <!-- Business modules / puzzle -->
    <template v-else-if="name === 'MOD'">
      <path d="M10 4h4v3a2 2 0 1 0 0 4v3h-4v-3a2 2 0 1 0 0-4V4Z" />
      <path d="M4 10h3a2 2 0 1 1 4 0h3v4h-3a2 2 0 1 1-4 0H4v-4Z" />
      <path d="M14 14h3a2 2 0 1 1 4 0h-1v4h-3a2 2 0 1 0-4 0h-3v-4h4Z" />
    </template>

    <!-- Support / headset -->
    <template v-else-if="name === 'SUP'">
      <path d="M4 13a8 8 0 0 1 16 0" />
      <path d="M4 13v3a2 2 0 0 0 2 2h1v-5H6a2 2 0 0 0-2 2Z" />
      <path d="M20 13v3a2 2 0 0 1-2 2h-1v-5h1a2 2 0 0 1 2 2Z" />
      <path d="M9 19h4a2 2 0 0 0 2-2v-1" />
    </template>

    <!-- Devices / Windows & Android -->
    <template v-else-if="name === 'DEV'">
      <rect x="2" y="4" width="13" height="10" rx="1.5" />
      <path d="M6 18h5" />
      <path d="M8.5 14v4" />
      <rect x="15" y="8" width="7" height="12" rx="1.5" />
      <path d="M17.5 18.5h2" />
    </template>

    <!-- Web back-office / browser -->
    <template v-else-if="name === 'WEB'">
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M3 9h18" />
      <circle cx="6.5" cy="6.5" r="0.7" fill="currentColor" stroke="none" />
      <circle cx="9" cy="6.5" r="0.7" fill="currentColor" stroke="none" />
      <path d="M7 13h6" />
      <path d="M7 16h10" />
    </template>

    <!-- Local sync / Master · terminals -->
    <template v-else-if="name === 'SYNC'">
      <path d="M7 7a6 6 0 0 1 9.5-1.5L18 7" />
      <path d="M17 4v3h-3" />
      <path d="M17 17a6 6 0 0 1-9.5 1.5L6 17" />
      <path d="M7 20v-3h3" />
      <circle cx="12" cy="12" r="2" />
    </template>

    <!-- Mail -->
    <template v-else-if="name === 'MAIL'">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="m3 7 9 7 9-7" />
    </template>

    <!-- Phone -->
    <template v-else-if="name === 'PHONE'">
      <path d="M7 3h3.2l1.3 3.2-2 1.2a12 12 0 0 0 5.1 5.1l1.2-2 3.2 1.3V18a2 2 0 0 1-2.2 2A15.8 15.8 0 0 1 5 7.2 2 2 0 0 1 7 3Z" />
    </template>

    <!-- Send / paper plane -->
    <template v-else-if="name === 'SEND'">
      <path d="M22 2 11 13" />
      <path d="M22 2 15 22l-4-9-9-4 20-7Z" />
    </template>

    <!-- Fallback chart -->
    <template v-else>
      <path d="M4 19V5" />
      <path d="M4 19h16" />
      <path d="M8 15v-4" />
      <path d="M12 15V8" />
      <path d="M16 15v-6" />
    </template>
  </svg>
</template>
