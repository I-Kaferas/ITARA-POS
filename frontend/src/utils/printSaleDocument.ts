import i18n from '../i18n'
import { intlLocale } from '../i18n/locales'
import { formatMoney } from './format'

export type SaleDocPayload = {
  document_type?: string
  document_number?: string
  sale_reference?: string
  date?: string | null
  company?: {
    name?: string | null
    trade_name?: string | null
    tax_id?: string | null
    phone?: string | null
    email?: string | null
    address?: Record<string, string | null> | string | null
    receipt_footer?: string | null
  }
  store?: { name?: string | null; code?: string | null }
  customer?: { name?: string | null; email?: string | null; phone?: string | null } | null
  items?: Array<{
    name?: string
    sku?: string
    quantity?: number
    unit_price?: number
    line_total?: number
  }>
  payments?: Array<{ method?: string; method_label?: string; amount?: number }>
  subtotal?: number
  tax_total?: number
  discount_total?: number
  fees_total?: number
  total?: number
  currency?: string
  footer?: string | null
}

function addressText(address: SaleDocPayload['company'] extends infer C
  ? C extends { address?: infer A } ? A : never
  : never): string {
  if (!address) return ''
  if (typeof address === 'string') return address
  return [address.street, address.city, address.postal_code, address.country]
    .filter(Boolean)
    .join(', ')
}

export function printSaleDocument(payload: SaleDocPayload, title: string) {
  const companyName = payload.company?.trade_name || payload.company?.name || 'POS'
  const items = payload.items ?? []
  const payments = payload.payments ?? []
  const currency = payload.currency

  const rows = items.map((line) => `
    <tr>
      <td>${escapeHtml(line.name ?? '')}<div class="muted">${escapeHtml(line.sku ?? '')}</div></td>
      <td class="num">${line.quantity ?? 0}</td>
      <td class="num">${formatMoney(line.unit_price ?? 0, currency)}</td>
      <td class="num">${formatMoney(line.line_total ?? 0, currency)}</td>
    </tr>
  `).join('')

  const paymentRows = payments.map((payment) => `
    <tr>
      <td>${escapeHtml(payment.method_label || payment.method || '')}</td>
      <td class="num">${formatMoney(payment.amount ?? 0, currency)}</td>
    </tr>
  `).join('')

  const t = i18n.global.t
  const html = `<!DOCTYPE html>
<html lang="${intlLocale().slice(0, 2)}">
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: Arial, sans-serif; color: #0f172a; margin: 24px; }
    h1 { font-size: 18px; margin: 0 0 4px; }
    h2 { font-size: 14px; margin: 0 0 16px; color: #475569; font-weight: 500; }
    .meta { font-size: 12px; color: #64748b; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 12px; }
    th, td { border-bottom: 1px solid #e2e8f0; padding: 8px 6px; text-align: left; vertical-align: top; }
    th { color: #64748b; font-weight: 600; }
    .num { text-align: right; white-space: nowrap; }
    .muted { color: #94a3b8; font-size: 11px; margin-top: 2px; }
    .totals { margin-top: 16px; width: 280px; margin-left: auto; font-size: 12px; }
    .totals div { display: flex; justify-content: space-between; padding: 4px 0; }
    .totals .grand { font-weight: 700; font-size: 14px; border-top: 1px solid #cbd5e1; margin-top: 6px; padding-top: 8px; }
    .footer { margin-top: 24px; font-size: 11px; color: #64748b; }
    @media print { body { margin: 0; } }
  </style>
</head>
<body>
  <h1>${escapeHtml(companyName)}</h1>
  <h2>${escapeHtml(title)} — ${escapeHtml(payload.document_number || payload.sale_reference || '')}</h2>
  <div class="meta">
    <div>${escapeHtml(payload.store?.name || '')}</div>
    <div>${escapeHtml(addressText(payload.company?.address))}</div>
    <div>${escapeHtml(payload.company?.tax_id || '')}</div>
    <div>${escapeHtml(payload.date || '')}</div>
    <div>${escapeHtml(payload.customer?.name || t('print.walkIn'))}</div>
  </div>
  <table>
    <thead>
      <tr>
        <th>${escapeHtml(t('print.item'))}</th>
        <th class="num">${escapeHtml(t('print.qty'))}</th>
        <th class="num">${escapeHtml(t('print.unitPrice'))}</th>
        <th class="num">${escapeHtml(t('print.total'))}</th>
      </tr>
    </thead>
    <tbody>${rows}</tbody>
  </table>
  <div class="totals">
    <div><span>${escapeHtml(t('print.subtotal'))}</span><span>${formatMoney(payload.subtotal ?? 0, currency)}</span></div>
    <div><span>${escapeHtml(t('print.discounts'))}</span><span>${formatMoney(payload.discount_total ?? 0, currency)}</span></div>
    <div><span>${escapeHtml(t('print.tax'))}</span><span>${formatMoney(payload.tax_total ?? 0, currency)}</span></div>
    <div><span>${escapeHtml(t('print.fees'))}</span><span>${formatMoney(payload.fees_total ?? 0, currency)}</span></div>
    <div class="grand"><span>${escapeHtml(t('print.total'))}</span><span>${formatMoney(payload.total ?? 0, currency)}</span></div>
  </div>
  ${payments.length ? `<table><thead><tr><th>${escapeHtml(t('print.payment'))}</th><th class="num">${escapeHtml(t('print.amount'))}</th></tr></thead><tbody>${paymentRows}</tbody></table>` : ''}
  <div class="footer">${escapeHtml(payload.footer || payload.company?.receipt_footer || '')}</div>
  <script>window.onload = () => { window.print(); }</script>
</body>
</html>`

  const popup = window.open('', '_blank', 'noopener,noreferrer,width=800,height=900')
  if (!popup) return
  popup.document.open()
  popup.document.write(html)
  popup.document.close()
}

function escapeHtml(value: string) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}
