# ITARA NEXUS · POS Analytics Dashboard

Vue 3 + Vite + Tailwind CSS v4 demo dashboard for multi-segment SaaS POS analytics.

## Stack

- Vue 3 + TypeScript + Vite
- Tailwind CSS v4 (`@custom-variant dark`)
- ECharts via `vue-echarts` (area, donut, bar)
- Lucide icons (`lucide-vue-next`)
- Seeded pseudo-random demo data

## Run

```bash
cd analytics-dashboard
npm install
npm run dev
```

Open http://localhost:5180/

## Notes

- Dark mode persists in `localStorage` (`itara-analytics-theme`).
- Date range + segment regenerate KPIs, charts, and transactions.
- Search / status filter / column sort operate on the table only.
