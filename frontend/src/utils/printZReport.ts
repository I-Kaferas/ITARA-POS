import i18n from '../i18n'
import { intlLocale } from '../i18n/locales'
import { formatMoney } from './format'

export type ZReportPayload = {
  title?: string
  cashier?: { id?: string; name?: string } | null
  register?: { id?: string; name?: string; code?: string } | null
  opened_at?: string | null
  closed_at?: string | null
  opening_balance?: number
  sales_count?: number
  sales_total?: number
  cash_in_total?: number
  cash_out_total?: number
  expenses_total?: number
  expected_cash?: number
  actual_cash?: number | null
  variance?: number | null
  invoices_count?: number
  invoices_total?: number
  invoices?: Array<{
    reference?: string
    total?: number
    completed_at?: string | null
    currency?: string | null
  }>
  payment_methods?: Array<{
    method?: string
    label?: string
    count?: number
    amount?: number
  }>
  currency?: string
}

function escapeHtml(value: string) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

function formatDate(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleString(intlLocale())
}

export function printZReport(payload: ZReportPayload, title: string, existingWindow?: Window | null) {
  const t = i18n.global.t
  const currency = payload.currency
  const payments = payload.payment_methods ?? []
  const invoices = payload.invoices ?? []
  const cashierName = payload.cashier?.name || '—'
  const registerName = payload.register?.name || payload.register?.code || '—'

  const paymentRows = payments.map((row) => `
    <tr>
      <td>${escapeHtml(row.label || row.method || '')}</td>
      <td class="num">${row.count ?? 0}</td>
      <td class="num">${formatMoney(row.amount ?? 0, currency)}</td>
    </tr>
  `).join('') || `<tr><td colspan="3">${escapeHtml(t('print.noPayments'))}</td></tr>`

  const invoiceRows = invoices.map((inv) => `
    <tr>
      <td>${escapeHtml(inv.reference || '')}</td>
      <td class="num">${escapeHtml(formatDate(inv.completed_at))}</td>
      <td class="num">${formatMoney(inv.total ?? 0, inv.currency || currency)}</td>
    </tr>
  `).join('') || `<tr><td colspan="3">${escapeHtml(t('print.noInvoices'))}</td></tr>`

  const html = `<!DOCTYPE html>
<html lang="${intlLocale().slice(0, 2)}">
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: Arial, sans-serif; color: #0f172a; margin: 24px; max-width: 720px; }
    h1 { font-size: 20px; margin: 0 0 4px; }
    h2 { font-size: 13px; margin: 20px 0 8px; color: #334155; text-transform: uppercase; letter-spacing: .04em; }
    .meta { font-size: 12px; color: #64748b; margin-bottom: 16px; line-height: 1.5; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 24px; font-size: 13px; margin: 12px 0 8px; }
    .grid div { display: flex; justify-content: space-between; gap: 12px; border-bottom: 1px dashed #e2e8f0; padding: 4px 0; }
    .grid .label { color: #64748b; }
    .grid .value { font-weight: 600; }
    table { width: 100%; border-collapse: collapse; margin-top: 4px; font-size: 12px; }
    th, td { border-bottom: 1px solid #e2e8f0; padding: 8px 6px; text-align: left; }
    th { color: #64748b; font-weight: 600; }
    .num { text-align: right; white-space: nowrap; }
    .footer { margin-top: 24px; font-size: 11px; color: #64748b; }
    @media print { body { margin: 0; } }
  </style>
</head>
<body>
  <h1>${escapeHtml(title)}</h1>
  <div class="meta">
    <div>${escapeHtml(t('print.cashier'))}: ${escapeHtml(cashierName)}</div>
    <div>${escapeHtml(t('print.register'))}: ${escapeHtml(registerName)}</div>
    <div>${escapeHtml(t('print.openedAt'))}: ${escapeHtml(formatDate(payload.opened_at))}</div>
    <div>${escapeHtml(t('print.closedAt'))}: ${escapeHtml(formatDate(payload.closed_at))}</div>
  </div>

  <h2>${escapeHtml(t('print.cashSummary'))}</h2>
  <div class="grid">
    <div><span class="label">${escapeHtml(t('print.openingBalance'))}</span><span class="value">${formatMoney(payload.opening_balance ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.salesTotal'))}</span><span class="value">${formatMoney(payload.sales_total ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.cashIn'))}</span><span class="value">${formatMoney(payload.cash_in_total ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.cashOut'))}</span><span class="value">${formatMoney(payload.cash_out_total ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.expenses'))}</span><span class="value">${formatMoney(payload.expenses_total ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.expectedCash'))}</span><span class="value">${formatMoney(payload.expected_cash ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.countedCash'))}</span><span class="value">${formatMoney(payload.actual_cash ?? 0, currency)}</span></div>
    <div><span class="label">${escapeHtml(t('print.variance'))}</span><span class="value">${formatMoney(payload.variance ?? 0, currency)}</span></div>
  </div>

  <h2>${escapeHtml(t('print.byPaymentMethod'))}</h2>
  <table>
    <thead>
      <tr>
        <th>${escapeHtml(t('print.payment'))}</th>
        <th class="num">${escapeHtml(t('print.invoiceCount'))}</th>
        <th class="num">${escapeHtml(t('print.amount'))}</th>
      </tr>
    </thead>
    <tbody>${paymentRows}</tbody>
  </table>

  <h2>${escapeHtml(t('print.invoicesSection'))} (${payload.invoices_count ?? invoices.length})</h2>
  <p style="font-size:12px;color:#64748b;margin:0 0 6px">${escapeHtml(t('print.invoicesTotal'))}: ${formatMoney(payload.invoices_total ?? 0, currency)}</p>
  <table>
    <thead>
      <tr>
        <th>${escapeHtml(t('print.reference'))}</th>
        <th class="num">${escapeHtml(t('print.date'))}</th>
        <th class="num">${escapeHtml(t('print.amount'))}</th>
      </tr>
    </thead>
    <tbody>${invoiceRows}</tbody>
  </table>
  <div class="footer">${escapeHtml(t('print.zFooter'))}</div>
</body>
</html>`

  const popup = existingWindow && !existingWindow.closed
    ? existingWindow
    : window.open('', '_blank', 'width=800,height=900')
  if (!popup) return false
  popup.document.open()
  popup.document.write(html)
  popup.document.close()
  popup.focus()
  window.setTimeout(() => {
    if (!popup.closed) popup.print()
  }, 200)
  return true
}
