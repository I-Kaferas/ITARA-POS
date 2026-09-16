<script setup lang="ts">
defineProps<{
  name: string
  size?: number
}>()
</script>

<template>
  <svg
    :width="size ?? 18"
    :height="size ?? 18"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.75"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <!-- Dashboard -->
    <template v-if="name === 'dashboard'">
      <rect x="3" y="3" width="7" height="9" rx="1.5" />
      <rect x="14" y="3" width="7" height="5" rx="1.5" />
      <rect x="14" y="12" width="7" height="9" rx="1.5" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" />
    </template>

    <!-- Catalog -->
    <template v-else-if="name === 'catalog'">
      <path d="M4 7h16M4 12h16M4 17h10" />
      <circle cx="19" cy="17" r="2" />
    </template>

    <!-- Products -->
    <template v-else-if="name === 'products'">
      <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" />
      <line x1="3" y1="6" x2="21" y2="6" />
      <path d="M16 10a4 4 0 0 1-8 0" />
    </template>

    <!-- Stores -->
    <template v-else-if="name === 'stores'">
      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
      <polyline points="9 22 9 12 15 12 15 22" />
    </template>

    <!-- Organization -->
    <template v-else-if="name === 'organization'">
      <circle cx="12" cy="5" r="2" />
      <path d="M4 20v-1a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v1" />
      <path d="M16 3.5a4 4 0 0 1 0 7" />
      <path d="M21 20v-1a3 3 0 0 0-2-2.83" />
      <path d="M8 3.5a4 4 0 0 0 0 7" />
      <path d="M3 20v-1a3 3 0 0 1 2-2.83" />
    </template>

    <!-- Account -->
    <template v-else-if="name === 'account'">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 20v-1a8 8 0 0 1 16 0v1" />
    </template>

    <!-- Logout -->
    <template v-else-if="name === 'logout'">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </template>

    <!-- Store pin -->
    <template v-else-if="name === 'store-pin'">
      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
      <circle cx="12" cy="10" r="3" />
    </template>

    <template v-else-if="name === 'menu'">
      <line x1="4" y1="7" x2="20" y2="7" />
      <line x1="4" y1="12" x2="20" y2="12" />
      <line x1="4" y1="17" x2="20" y2="17" />
    </template>

    <!-- Chevron -->
    <template v-else-if="name === 'chevron-right'">
      <polyline points="9 18 15 12 9 6" />
    </template>

    <!-- Plus -->
    <template v-else-if="name === 'plus'">
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </template>

    <!-- Search -->
    <template v-else-if="name === 'search'">
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </template>

    <!-- Building -->
    <template v-else-if="name === 'building'">
      <rect x="4" y="2" width="16" height="20" rx="2" />
      <path d="M9 22v-4h6v4" />
      <line x1="8" y1="6" x2="8" y2="6.01" />
      <line x1="12" y1="6" x2="12" y2="6.01" />
      <line x1="16" y1="6" x2="16" y2="6.01" />
      <line x1="8" y1="10" x2="8" y2="10.01" />
      <line x1="12" y1="10" x2="12" y2="10.01" />
      <line x1="16" y1="10" x2="16" y2="10.01" />
    </template>

    <!-- Package -->
    <template v-else-if="name === 'package'">
      <path d="M16.5 9.4l-9-5.19M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
      <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
      <line x1="12" y1="22.08" x2="12" y2="12" />
    </template>

    <!-- Import -->
    <template v-else-if="name === 'import'">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </template>

    <!-- Layers -->
    <template v-else-if="name === 'layers'">
      <polygon points="12 2 2 7 12 12 22 7 12 2" />
      <polyline points="2 17 12 22 22 17" />
      <polyline points="2 12 12 17 22 12" />
    </template>

    <!-- Sparkles -->
    <template v-else-if="name === 'sparkles'">
      <path d="M12 3l1.5 4.5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1.5L12 3z" />
      <path d="M19 14l.75 2.25L22 17l-2.25.75L19 20l-.75-2.25L16 17l2.25-.75L19 14z" />
    </template>

    <!-- Check -->
    <template v-else-if="name === 'check'">
      <polyline points="20 6 9 17 4 12" />
    </template>

    <!-- Inventory -->
    <template v-else-if="name === 'inventory'">
      <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
      <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
      <line x1="12" y1="22.08" x2="12" y2="12" />
    </template>

    <!-- Suppliers -->
    <template v-else-if="name === 'suppliers'">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </template>

    <!-- Purchases -->
    <template v-else-if="name === 'purchases'">
      <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" />
      <line x1="3" y1="6" x2="21" y2="6" />
      <path d="M16 10a4 4 0 0 1-8 0" />
    </template>

    <!-- Customers -->
    <template v-else-if="name === 'customers'">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </template>

    <!-- Sales -->
    <template v-else-if="name === 'sales'">
      <line x1="12" y1="1" x2="12" y2="23" />
      <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
    </template>

    <!-- POS terminal -->
    <template v-else-if="name === 'device-pos'">
      <rect x="3" y="4" width="18" height="12" rx="2" />
      <path d="M8 20h8" />
      <path d="M12 16v4" />
    </template>

    <!-- Printer -->
    <template v-else-if="name === 'device-printer'">
      <polyline points="6 9 6 2 18 2 18 9" />
      <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
      <rect x="6" y="14" width="12" height="8" />
    </template>

    <!-- Tablet -->
    <template v-else-if="name === 'device-tablet'">
      <rect x="5" y="2" width="14" height="20" rx="2" />
      <line x1="12" y1="18" x2="12.01" y2="18" />
    </template>

    <!-- Computer -->
    <template v-else-if="name === 'device-computer'">
      <rect x="2" y="3" width="20" height="14" rx="2" />
      <path d="M8 21h8" />
      <path d="M12 17v4" />
    </template>

    <!-- Other device -->
    <template v-else-if="name === 'device-other'">
      <rect x="3" y="3" width="7" height="7" rx="1.5" />
      <rect x="14" y="3" width="7" height="7" rx="1.5" />
      <rect x="3" y="14" width="7" height="7" rx="1.5" />
      <rect x="14" y="14" width="7" height="7" rx="1.5" />
    </template>

    <!-- Network -->
    <template v-else-if="name === 'wifi' || name === 'conn-network'">
      <path d="M5 12.55a11 11 0 0 1 14.08 0" />
      <path d="M1.42 9a16 16 0 0 1 21.16 0" />
      <path d="M8.53 16.11a6 6 0 0 1 6.95 0" />
      <line x1="12" y1="20" x2="12.01" y2="20" />
    </template>

    <!-- USB -->
    <template v-else-if="name === 'conn-usb'">
      <circle cx="10" cy="7" r="2" />
      <path d="M10 9v8" />
      <path d="M10 17h6" />
      <path d="M16 14v6" />
      <path d="M6 13l4 4" />
    </template>

    <!-- Bluetooth -->
    <template v-else-if="name === 'conn-bluetooth'">
      <polyline points="6.5 6.5 17.5 17.5 12 23 12 1 17.5 6.5 6.5 17.5" />
    </template>

    <template v-else-if="name === 'edit'">
      <path d="M12 20h9" />
      <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" />
    </template>

    <template v-else-if="name === 'trash'">
      <polyline points="3 6 5 6 21 6" />
      <path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
      <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    </template>

    <template v-else-if="name === 'alert'">
      <path d="M10.3 3.7 1.8 18a2 2 0 0 0 1.7 3h16.9a2 2 0 0 0 1.7-3L13.7 3.7a2 2 0 0 0-3.4 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </template>

    <template v-else-if="name === 'info'">
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="16" x2="12" y2="12" />
      <line x1="12" y1="8" x2="12.01" y2="8" />
    </template>

    <template v-else-if="name === 'lock'">
      <rect x="4" y="11" width="16" height="10" rx="2" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
    </template>

    <template v-else-if="name === 'percent'">
      <line x1="19" y1="5" x2="5" y2="19" />
      <circle cx="7.5" cy="7.5" r="2.5" />
      <circle cx="16.5" cy="16.5" r="2.5" />
    </template>

    <template v-else-if="name === 'note'">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="8" y1="13" x2="16" y2="13" />
      <line x1="8" y1="17" x2="13" y2="17" />
    </template>

    <template v-else-if="name === 'pause'">
      <rect x="6" y="4" width="4" height="16" rx="1" />
      <rect x="14" y="4" width="4" height="16" rx="1" />
    </template>

    <template v-else-if="name === 'card'">
      <rect x="2" y="5" width="20" height="14" rx="2" />
      <line x1="2" y1="10" x2="22" y2="10" />
    </template>

    <template v-else-if="name === 'tag'">
      <path d="M20.6 13.4 12 22l-9-9V3h10z" />
      <circle cx="7.5" cy="7.5" r="1.2" fill="currentColor" stroke="none" />
    </template>

    <template v-else-if="name === 'coins'">
      <ellipse cx="12" cy="6" rx="8" ry="3" />
      <path d="M4 6v6c0 1.7 3.6 3 8 3s8-1.3 8-3V6" />
      <path d="M4 12v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" />
    </template>

    <template v-else-if="name === 'receipt'">
      <path d="M6 2h12v20l-2-1.5L14 22l-2-1.5L10 22l-2-1.5L6 22z" />
      <line x1="9" y1="8" x2="15" y2="8" />
      <line x1="9" y1="12" x2="15" y2="12" />
    </template>

    <template v-else-if="name === 'shift'">
      <circle cx="12" cy="12" r="9" />
      <polyline points="12 7 12 12 16 14" />
    </template>

    <template v-else-if="name === 'transfer'">
      <polyline points="17 1 21 5 17 9" />
      <path d="M3 11V9a4 4 0 0 1 4-4h14" />
      <polyline points="7 23 3 19 7 15" />
      <path d="M21 13v2a4 4 0 0 1-4 4H3" />
    </template>

    <template v-else-if="name === 'adjust'">
      <line x1="4" y1="21" x2="4" y2="14" />
      <line x1="4" y1="10" x2="4" y2="3" />
      <line x1="12" y1="21" x2="12" y2="12" />
      <line x1="12" y1="8" x2="12" y2="3" />
      <line x1="20" y1="21" x2="20" y2="16" />
      <line x1="20" y1="12" x2="20" y2="3" />
      <line x1="1" y1="14" x2="7" y2="14" />
      <line x1="9" y1="8" x2="15" y2="8" />
      <line x1="17" y1="16" x2="23" y2="16" />
    </template>

    <template v-else-if="name === 'pin'">
      <path d="M12 21s7-5.4 7-11a7 7 0 1 0-14 0c0 5.6 7 11 7 11z" />
      <circle cx="12" cy="10" r="2.5" />
    </template>

    <template v-else-if="name === 'bell'">
      <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.7 21a2 2 0 0 1-3.4 0" />
    </template>

    <template v-else-if="name === 'mail'">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <polyline points="3 7 12 13 21 7" />
    </template>

    <template v-else-if="name === 'phone'">
      <path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3.1-8.7A2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.3 1.8.6 2.6a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.5-1.1a2 2 0 0 1 2.1-.5c.8.3 1.7.5 2.6.6a2 2 0 0 1 1.7 2z" />
    </template>

    <template v-else-if="name === 'calendar'">
      <rect x="3" y="4" width="18" height="18" rx="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </template>

    <template v-else-if="name === 'filter'">
      <polygon points="22 3 2 3 10 12.5 10 19 14 21 14 12.5 22 3" />
    </template>

    <template v-else-if="name === 'calculator'">
      <rect x="5" y="2" width="14" height="20" rx="2" />
      <rect x="8" y="5" width="8" height="3" rx="0.6" />
      <circle cx="8.5" cy="12" r="0.8" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="0.8" fill="currentColor" stroke="none" />
      <circle cx="15.5" cy="12" r="0.8" fill="currentColor" stroke="none" />
      <circle cx="8.5" cy="16" r="0.8" fill="currentColor" stroke="none" />
      <circle cx="12" cy="16" r="0.8" fill="currentColor" stroke="none" />
      <circle cx="15.5" cy="16" r="0.8" fill="currentColor" stroke="none" />
    </template>

    <template v-else-if="name === 'id-card'">
      <rect x="3" y="6" width="18" height="12" rx="2" />
      <circle cx="8.5" cy="12" r="1.7" />
      <path d="M12.5 10.5h6" />
      <path d="M12.5 13.5h5" />
    </template>

    <template v-else-if="name === 'upload'">
      <path d="M12 16V7" />
      <path d="M8.5 10.5 12 7l3.5 3.5" />
      <path d="M5 19h14" />
    </template>

    <template v-else-if="name === 'bed'">
      <path d="M3 18v-6a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v6" />
      <path d="M3 14h18" />
      <path d="M6 9V7a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v2" />
      <line x1="3" y1="18" x2="3" y2="21" />
      <line x1="21" y1="18" x2="21" y2="21" />
    </template>

    <template v-else-if="name === 'broom'">
      <path d="M12 4v8" />
      <path d="M9 3h6" />
      <path d="M8 12h8l1.5 7H6.5L8 12z" />
      <path d="M10 15h4" />
    </template>

    <template v-else-if="name === 'key'">
      <circle cx="8" cy="15" r="4" />
      <path d="M11.5 12.5 21 3" />
      <path d="M16 5.5 18.5 8" />
      <path d="M18.5 3 21 5.5" />
    </template>

    <template v-else-if="name === 'floors'">
      <rect x="4" y="4" width="16" height="4" rx="1" />
      <rect x="4" y="10" width="16" height="4" rx="1" />
      <rect x="4" y="16" width="16" height="4" rx="1" />
    </template>

    <template v-else-if="name === 'tables'">
      <rect x="3" y="4" width="8" height="7" rx="1.5" />
      <rect x="13" y="4" width="8" height="7" rx="1.5" />
      <rect x="3" y="13" width="8" height="7" rx="1.5" />
      <rect x="13" y="13" width="8" height="7" rx="1.5" />
    </template>

    <!-- Amenity: TV -->
    <template v-else-if="name === 'tv'">
      <rect x="2" y="4" width="20" height="13" rx="2" />
      <line x1="8" y1="21" x2="16" y2="21" />
      <line x1="12" y1="17" x2="12" y2="21" />
    </template>

    <!-- Amenity: Air conditioning -->
    <template v-else-if="name === 'ac'">
      <path d="M12 3v18" />
      <path d="M5.5 7.5 12 12l6.5-4.5" />
      <path d="M5.5 16.5 12 12l6.5 4.5" />
      <circle cx="12" cy="12" r="1.5" />
    </template>

    <!-- Amenity: Minibar -->
    <template v-else-if="name === 'minibar'">
      <rect x="5" y="3" width="14" height="18" rx="2" />
      <path d="M5 9h14" />
      <path d="M9 13h2v5H9z" />
      <path d="M13 13h2v3h-2z" />
    </template>

    <!-- Amenity: Safe -->
    <template v-else-if="name === 'safe'">
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <circle cx="12" cy="12" r="3.5" />
      <circle cx="12" cy="12" r="1" fill="currentColor" stroke="none" />
      <path d="M7 8h.01" />
    </template>

    <!-- Amenity: Balcony -->
    <template v-else-if="name === 'balcony'">
      <path d="M4 10V4h16v6" />
      <path d="M3 20h18" />
      <path d="M5 10v10" />
      <path d="M19 10v10" />
      <path d="M9 10v10" />
      <path d="M15 10v10" />
      <path d="M3 14h18" />
    </template>

    <!-- Amenity: Bathtub -->
    <template v-else-if="name === 'bathtub'">
      <path d="M4 12h16a2 2 0 0 1 2 2v2a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4v-2a2 2 0 0 1 2-2z" />
      <path d="M6 12V7a2 2 0 0 1 2-2h1" />
      <circle cx="15" cy="7" r="1" />
      <circle cx="18" cy="6" r="1" />
    </template>

    <!-- Amenity: Shower -->
    <template v-else-if="name === 'shower'">
      <path d="M4 4h8a4 4 0 0 1 4 4v2" />
      <path d="M12 10v2" />
      <circle cx="8" cy="16" r="1" />
      <circle cx="12" cy="18" r="1" />
      <circle cx="16" cy="16" r="1" />
      <circle cx="10" cy="20" r="1" />
      <circle cx="14" cy="20" r="1" />
    </template>

    <!-- Amenity: Desk -->
    <template v-else-if="name === 'desk'">
      <path d="M3 10h18" />
      <path d="M5 10v10" />
      <path d="M19 10v10" />
      <path d="M9 14h6" />
      <path d="M8 6h8l1 4H7l1-4z" />
    </template>

    <!-- Amenity: Kettle -->
    <template v-else-if="name === 'kettle'">
      <path d="M8 8h8l1 10H7L8 8z" />
      <path d="M10 8V6a2 2 0 0 1 2-2h0a2 2 0 0 1 2 2v2" />
      <path d="M17 11h2a2 2 0 0 1 0 4h-2" />
      <path d="M7 18h10" />
    </template>

    <!-- Amenity: Hairdryer -->
    <template v-else-if="name === 'hairdryer'">
      <path d="M4 10a6 6 0 0 1 12 0v1H4v-1z" />
      <path d="M16 11h3a2 2 0 0 1 2 2v1" />
      <path d="M10 11v9" />
      <path d="M8 20h4" />
      <circle cx="10" cy="8" r="1.5" />
    </template>

    <!-- Amenity: Projector -->
    <template v-else-if="name === 'projector'">
      <rect x="2" y="8" width="20" height="9" rx="2" />
      <circle cx="12" cy="12.5" r="2.5" />
      <path d="M7 17v2" />
      <path d="M17 17v2" />
      <path d="M6 8V6" />
    </template>

    <!-- Amenity: Sound / mic -->
    <template v-else-if="name === 'sound'">
      <path d="M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z" />
      <path d="M5 11a7 7 0 0 0 14 0" />
      <path d="M12 18v3" />
      <path d="M8 21h8" />
    </template>

    <!-- Amenity: Stage -->
    <template v-else-if="name === 'stage'">
      <path d="M3 18h18" />
      <path d="M5 18V12l7-5 7 5v6" />
      <path d="M9 18v-3h6v3" />
      <path d="M12 7V4" />
    </template>

    <!-- Amenity: Catering -->
    <template v-else-if="name === 'catering'">
      <path d="M4 11h16v2a6 6 0 0 1-6 6h-4a6 6 0 0 1-6-6v-2z" />
      <path d="M8 11V7a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v4" />
      <path d="M12 19v2" />
      <path d="M9 21h6" />
    </template>

    <template v-else-if="name === 'parking'">
      <rect x="4" y="3" width="16" height="18" rx="2" />
      <path d="M9 17V7h4.2a3.3 3.3 0 0 1 0 6.6H9" />
    </template>

    <template v-else-if="name === 'pool'">
      <path d="M4 18c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0 3 1 4.5 0" />
      <path d="M4 14c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0 3 1 4.5 0" />
      <path d="M8 6c0 2 1.5 3 1.5 5" />
      <path d="M16 4c0 2.5-1.5 3.5-1.5 6" />
    </template>

    <template v-else-if="name === 'gym'">
      <path d="M6.5 9.5 4 12l2.5 2.5" />
      <path d="M17.5 9.5 20 12l-2.5 2.5" />
      <path d="M6.5 12h11" />
      <path d="M4 10v4" />
      <path d="M20 10v4" />
      <path d="M8 9v6" />
      <path d="M16 9v6" />
    </template>

    <template v-else-if="name === 'coffee'">
      <path d="M5 8h11v5a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4V8z" />
      <path d="M16 9h2a2.5 2.5 0 0 1 0 5h-2" />
      <path d="M4 19h13" />
      <path d="M9 3c0 1 .5 1.5.5 2.5S9 7 9 8" />
      <path d="M12 3c0 1 .5 1.5.5 2.5S12 7 12 8" />
    </template>

    <template v-else-if="name === 'iron'">
      <path d="M4 16h14a3 3 0 0 0 0-6H9L5 14v2z" />
      <path d="M4 16v2h12" />
      <circle cx="15" cy="12" r="1" />
    </template>

    <template v-else-if="name === 'fridge'">
      <rect x="6" y="2" width="12" height="20" rx="2" />
      <path d="M6 10h12" />
      <path d="M9 6v2" />
      <path d="M9 13v3" />
    </template>

    <template v-else-if="name === 'microwave'">
      <rect x="2" y="6" width="20" height="12" rx="2" />
      <rect x="5" y="9" width="10" height="6" rx="1" />
      <circle cx="18" cy="10" r="1" />
      <circle cx="18" cy="14" r="1" />
    </template>

    <template v-else-if="name === 'laundry'">
      <rect x="4" y="3" width="16" height="18" rx="2" />
      <circle cx="12" cy="13" r="4" />
      <circle cx="12" cy="13" r="1.5" />
      <path d="M8 6h.01" />
      <path d="M11 6h5" />
    </template>

    <template v-else-if="name === 'elevator'">
      <rect x="5" y="2" width="14" height="20" rx="2" />
      <path d="M9 9l3-2 3 2" />
      <path d="M9 15l3 2 3-2" />
    </template>

    <template v-else-if="name === 'wheelchair'">
      <circle cx="8" cy="5" r="2" />
      <path d="M10 8.5 12 14l4 1" />
      <path d="M8 8v4" />
      <circle cx="9" cy="17" r="4" />
      <path d="M13 17h5l2 3" />
    </template>

    <template v-else-if="name === 'pets'">
      <circle cx="11" cy="5" r="2" />
      <circle cx="17" cy="7" r="1.5" />
      <circle cx="5" cy="7" r="1.5" />
      <circle cx="18" cy="13" r="1.5" />
      <circle cx="4" cy="13" r="1.5" />
      <path d="M8 14c0-2 1.5-3.5 4-3.5s4 1.5 4 3.5-2 5-4 5-4-3-4-5z" />
    </template>

    <template v-else-if="name === 'smoking'">
      <path d="M3 17h10" />
      <path d="M16 17h1" />
      <path d="M19 17h2" />
      <path d="M17 14c1 0 2-.8 2-2s-1-2-1-3 1-2 1-3" />
      <path d="M20 14c1.2 0 2.2-1 2.2-2.3S21 9.5 21 8.2 22.2 6 22.2 4.7" />
    </template>

    <template v-else-if="name === 'no-smoking'">
      <circle cx="12" cy="12" r="9" />
      <path d="M4.5 4.5 19.5 19.5" />
      <path d="M5 14h7" />
      <path d="M14 14h1.5" />
    </template>

    <template v-else-if="name === 'baby'">
      <circle cx="12" cy="6" r="3" />
      <path d="M7 20c0-3 2.2-5 5-5s5 2 5 5" />
      <path d="M8 13c-1.5.5-2.5 2-2.5 3.5" />
      <path d="M16 13c1.5.5 2.5 2 2.5 3.5" />
    </template>

    <template v-else-if="name === 'towel'">
      <path d="M6 4h9a3 3 0 0 1 0 6H8" />
      <path d="M8 10v10" />
      <path d="M6 4v4" />
      <path d="M12 10v4" />
    </template>

    <template v-else-if="name === 'slippers'">
      <path d="M4 15c0-3 2-5 5-5h3c2 0 3 1.2 3 3v4H4v-2z" />
      <path d="M12 15c0-2.5 1.8-4 4.5-4H19c1.5 0 2.5 1 2.5 2.5V18H12v-3z" />
    </template>

    <template v-else-if="name === 'robe'">
      <path d="M8 4h8l2 6v10H6V10l2-6z" />
      <path d="M12 4v16" />
      <path d="M8 10h8" />
    </template>

    <template v-else-if="name === 'lamp'">
      <path d="M9 18h6" />
      <path d="M12 18v3" />
      <path d="M7 14h10l-1.5-7h-7L7 14z" />
      <path d="M10 7V4h4v3" />
    </template>

    <template v-else-if="name === 'fan'">
      <circle cx="12" cy="12" r="2" />
      <path d="M12 10c2-4 6-5 7-3s-1 5-5 6" />
      <path d="M14 12c4 2 5 6 3 7s-5-1-6-5" />
      <path d="M12 14c-2 4-6 5-7 3s1-5 5-6" />
      <path d="M10 12C6 10 5 6 7 5s5 1 6 5" />
    </template>

    <template v-else-if="name === 'heater'">
      <rect x="5" y="3" width="14" height="18" rx="2" />
      <path d="M9 7v10" />
      <path d="M12 7v10" />
      <path d="M15 7v10" />
    </template>

    <template v-else-if="name === 'window'">
      <rect x="3" y="4" width="18" height="16" rx="1.5" />
      <path d="M12 4v16" />
      <path d="M3 12h18" />
    </template>

    <template v-else-if="name === 'garden'">
      <path d="M12 21V11" />
      <path d="M8 21h8" />
      <path d="M12 11c-3 0-5-2.2-5-5 2.5 0 5 2 5 5z" />
      <path d="M12 11c3 0 5-2.2 5-5-2.5 0-5 2-5 5z" />
      <path d="M12 11c0-3 2-5 5-5-1 2.5-3 5-5 5z" />
    </template>

    <template v-else-if="name === 'restaurant'">
      <path d="M7 3v8a2 2 0 0 0 2 2v8" />
      <path d="M5 3c0 2.5 2 3 2 5" />
      <path d="M9 3c0 2.5-2 3-2 5" />
      <path d="M16 3v18" />
      <path d="M16 8h3a2 2 0 0 0 0-4h-3" />
    </template>

    <template v-else-if="name === 'bar'">
      <path d="M6 4h12l-5 8v6h3v2H8v-2h3v-6L6 4z" />
      <path d="M8 8h8" />
    </template>

    <template v-else-if="name === 'spa'">
      <path d="M12 21c-4-3-7-6.5-7-10a7 7 0 0 1 14 0c0 3.5-3 7-7 10z" />
      <path d="M9 11c1-2 2.5-3 3-3s2 1 3 3" />
    </template>

    <template v-else-if="name === 'luggage'">
      <rect x="5" y="7" width="14" height="13" rx="2" />
      <path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2" />
      <path d="M5 12h14" />
    </template>

    <template v-else-if="name === 'clock'">
      <circle cx="12" cy="12" r="9" />
      <polyline points="12 7 12 12 15 14" />
    </template>

    <template v-else-if="name === 'camera'">
      <path d="M4 8h3l2-2h6l2 2h3v11H4V8z" />
      <circle cx="12" cy="13" r="3.5" />
    </template>

    <template v-else-if="name === 'music'">
      <path d="M9 18V6l10-2v12" />
      <circle cx="7" cy="18" r="2.5" />
      <circle cx="17" cy="16" r="2.5" />
    </template>

    <template v-else-if="name === 'game'">
      <rect x="2" y="8" width="20" height="10" rx="4" />
      <path d="M7 13h4" />
      <path d="M9 11v4" />
      <circle cx="15" cy="12" r="1" />
      <circle cx="18" cy="14" r="1" />
    </template>

    <template v-else-if="name === 'water'">
      <path d="M12 3c0 0-6 7-6 11a6 6 0 0 0 12 0c0-4-6-11-6-11z" />
    </template>

    <template v-else-if="name === 'fire'">
      <path d="M12 3c2 4-2 5-1 9 3-1 5-4 5-7 3 3 4 6 4 9a8 8 0 1 1-16 0c0-4 3-7 8-11z" />
    </template>

    <template v-else-if="name === 'leaf'">
      <path d="M5 19c8 0 14-6 14-14-8 0-14 6-14 14z" />
      <path d="M5 19c3-4 7-7 12-9" />
    </template>

    <template v-else-if="name === 'sun'">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2" />
      <path d="M12 20v2" />
      <path d="M4.9 4.9 6.3 6.3" />
      <path d="M17.7 17.7 19.1 19.1" />
      <path d="M2 12h2" />
      <path d="M20 12h2" />
      <path d="M4.9 19.1 6.3 17.7" />
      <path d="M17.7 6.3 19.1 4.9" />
    </template>

    <template v-else-if="name === 'moon'">
      <path d="M21 14.5A8.5 8.5 0 1 1 9.5 3 7 7 0 0 0 21 14.5z" />
    </template>

    <template v-else-if="name === 'star'">
      <polygon points="12 3 14.8 9.2 21.5 9.8 16.5 14.2 18.2 21 12 17.5 5.8 21 7.5 14.2 2.5 9.8 9.2 9.2 12 3" />
    </template>

    <template v-else-if="name === 'heart'">
      <path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.6-7 10-7 10z" />
    </template>

    <template v-else-if="name === 'umbrella'">
      <path d="M12 12v8a2 2 0 0 0 4 0" />
      <path d="M4 12a8 8 0 0 1 16 0H4z" />
    </template>

    <template v-else-if="name === 'car'">
      <path d="M4 15h16v3H4z" />
      <path d="M5 15 7 9h10l2 6" />
      <circle cx="7.5" cy="18" r="1.5" />
      <circle cx="16.5" cy="18" r="1.5" />
    </template>

    <template v-else-if="name === 'bus'">
      <rect x="4" y="3" width="16" height="15" rx="2" />
      <path d="M4 11h16" />
      <path d="M8 18v2" />
      <path d="M16 18v2" />
      <circle cx="8" cy="14" r="1" />
      <circle cx="16" cy="14" r="1" />
    </template>

    <template v-else-if="name === 'plane'">
      <path d="M10.5 19 12 22l1.5-3 6.5 1-4-5 5-9-9 5-5-4 1 6.5z" />
    </template>

    <template v-else-if="name === 'map'">
      <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21 3 6" />
      <line x1="9" y1="3" x2="9" y2="18" />
      <line x1="15" y1="6" x2="15" y2="21" />
    </template>

    <template v-else-if="name === 'globe'">
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18" />
      <path d="M12 3a14 14 0 0 1 0 18" />
      <path d="M12 3a14 14 0 0 0 0 18" />
    </template>

    <template v-else-if="name === 'power'">
      <path d="M12 3v9" />
      <path d="M7.5 6.5a7 7 0 1 0 9 0" />
    </template>

    <template v-else-if="name === 'plug'">
      <path d="M9 3v6" />
      <path d="M15 3v6" />
      <path d="M7 9h10v3a5 5 0 0 1-10 0V9z" />
      <path d="M12 17v4" />
    </template>

    <template v-else-if="name === 'battery'">
      <rect x="3" y="7" width="16" height="10" rx="2" />
      <path d="M19 10h2v4h-2" />
      <path d="M6 10h6v4H6z" fill="currentColor" stroke="none" />
    </template>

    <template v-else-if="name === 'speaker'">
      <rect x="5" y="3" width="14" height="18" rx="2" />
      <circle cx="12" cy="14" r="3.5" />
      <circle cx="12" cy="7" r="1.2" />
    </template>

    <template v-else-if="name === 'headset'">
      <path d="M4 13v-2a8 8 0 0 1 16 0v2" />
      <rect x="2" y="13" width="4" height="6" rx="1.5" />
      <rect x="18" y="13" width="4" height="6" rx="1.5" />
    </template>

    <!-- Default fallback -->
    <template v-else>
      <circle cx="12" cy="12" r="10" />
    </template>
  </svg>
</template>
