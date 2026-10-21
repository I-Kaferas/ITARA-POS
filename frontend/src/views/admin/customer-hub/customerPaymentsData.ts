export type PaymentStatus = 'completed' | 'pending' | 'failed'
export type PaymentType = 'order' | 'tip' | 'refund' | 'direct'

export type CustomerHubPayment = {
  id: string
  customer: string
  reference: string
  description: string
  amount: number
  fee: number
  status: PaymentStatus
  type: PaymentType
  at: string
}

export type PaymentTrendPoint = {
  date: string
  label: string
  amount: number
}

export const CUSTOMER_PAYMENTS_SEED: CustomerHubPayment[] = [
  {
    id: 'pay-001',
    customer: 'Jean Mobile',
    reference: 'SO-20260309-00001',
    description: 'Paiement commande #SO-20260309-00001',
    amount: 45000,
    fee: 300,
    status: 'completed',
    type: 'order',
    at: '2026-03-09T14:30:00',
  },
  {
    id: 'pay-002',
    customer: 'Marie App',
    reference: 'SO-20260309-00002',
    description: 'Paiement commande #SO-20260309-00002',
    amount: 18500,
    fee: 200,
    status: 'completed',
    type: 'order',
    at: '2026-03-09T13:15:00',
  },
  {
    id: 'pay-003',
    customer: 'Pierre Mobile',
    reference: 'TIP-20260308-001',
    description: 'Pourboire de Pierre',
    amount: 5000,
    fee: 0,
    status: 'completed',
    type: 'tip',
    at: '2026-03-08T22:00:00',
  },
  {
    id: 'pay-004',
    customer: 'Pierre Mobile',
    reference: 'SO-20260308-00005',
    description: 'Paiement commande #SO-20260308-00005',
    amount: 72000,
    fee: 400,
    status: 'completed',
    type: 'order',
    at: '2026-03-08T21:45:00',
  },
  {
    id: 'pay-005',
    customer: 'Alice App',
    reference: 'SO-20260308-00004',
    description: 'Paiement commande #SO-20260308-00004',
    amount: 35000,
    fee: 250,
    status: 'completed',
    type: 'order',
    at: '2026-03-08T20:00:00',
  },
  {
    id: 'pay-006',
    customer: 'Claude App',
    reference: 'RF-20260308-001',
    description: 'Remboursement commande annulée',
    amount: -12000,
    fee: 0,
    status: 'completed',
    type: 'refund',
    at: '2026-03-08T17:00:00',
  },
  {
    id: 'pay-007',
    customer: 'David App',
    reference: 'SO-20260307-00010',
    description: 'Paiement commande #SO-20260307-00010',
    amount: 95000,
    fee: 350,
    status: 'completed',
    type: 'order',
    at: '2026-03-07T22:10:00',
  },
  {
    id: 'pay-008',
    customer: 'Grace App',
    reference: 'DIR-20260307-001',
    description: 'Paiement direct',
    amount: 15000,
    fee: 0,
    status: 'pending',
    type: 'direct',
    at: '2026-03-07T16:00:00',
  },
]

/** Daily gross received (completed inbound only), 04–09 Mar 2026 */
export const PAYMENT_TREND_SEED: PaymentTrendPoint[] = [
  { date: '2026-03-04', label: '04 Mar', amount: 48000 },
  { date: '2026-03-05', label: '05 Mar', amount: 92000 },
  { date: '2026-03-06', label: '06 Mar', amount: 145000 },
  { date: '2026-03-07', label: '07 Mar', amount: 95000 },
  { date: '2026-03-08', label: '08 Mar', amount: 112000 },
  { date: '2026-03-09', label: '09 Mar', amount: 63500 },
]

export function cloneCustomerPayments(): CustomerHubPayment[] {
  return CUSTOMER_PAYMENTS_SEED.map(row => ({ ...row }))
}

export function clonePaymentTrend(): PaymentTrendPoint[] {
  return PAYMENT_TREND_SEED.map(row => ({ ...row }))
}
