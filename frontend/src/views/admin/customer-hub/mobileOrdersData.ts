export type OrderType = 'dine_in' | 'takeaway' | 'delivery'
export type OrderStatus = 'new' | 'processing' | 'completed' | 'cancelled'
export type PaymentStatus = 'paid' | 'unpaid' | 'partial'

export type MobileOrderLine = {
  name: string
  quantity: number
  unit_price: number
  notes?: string | null
}

export type MobileOrder = {
  id: string
  reference: string
  customer: string
  phone: string
  type: OrderType
  table: string | null
  address: string | null
  amount: number
  status: OrderStatus
  payment: PaymentStatus
  at: string
  notes: string | null
  lines: MobileOrderLine[]
}

export const MOBILE_ORDERS_SEED: MobileOrder[] = [
  {
    id: 'mo-00001',
    reference: '00001',
    customer: 'Jean Mobile',
    phone: '+257 79 111 001',
    type: 'dine_in',
    table: 'T5',
    address: null,
    amount: 45000,
    status: 'new',
    payment: 'paid',
    at: '2026-03-09T14:30:00',
    notes: 'Sans oignon',
    lines: [
      { name: 'Brochettes de boeuf', quantity: 2, unit_price: 12000 },
      { name: 'Frites', quantity: 1, unit_price: 6000 },
      { name: 'Jus de passion', quantity: 2, unit_price: 7500, notes: 'Peu de sucre' },
    ],
  },
  {
    id: 'mo-00002',
    reference: '00002',
    customer: 'Marie App',
    phone: '+257 79 222 002',
    type: 'takeaway',
    table: null,
    address: null,
    amount: 18500,
    status: 'processing',
    payment: 'paid',
    at: '2026-03-09T13:15:00',
    notes: 'À emporter — prêt pour 13h45',
    lines: [
      { name: 'Burger classique', quantity: 1, unit_price: 12500 },
      { name: 'Soda', quantity: 1, unit_price: 6000 },
    ],
  },
  {
    id: 'mo-00005',
    reference: '00005',
    customer: 'Pierre Mobile',
    phone: '+257 79 333 003',
    type: 'dine_in',
    table: 'T2',
    address: null,
    amount: 72000,
    status: 'completed',
    payment: 'paid',
    at: '2026-03-08T21:45:00',
    notes: null,
    lines: [
      { name: 'Pizza 4 fromages', quantity: 2, unit_price: 22000 },
      { name: 'Salade verte', quantity: 1, unit_price: 8000 },
      { name: 'Bière locale', quantity: 4, unit_price: 5000 },
    ],
  },
  {
    id: 'mo-00004',
    reference: '00004',
    customer: 'Alice App',
    phone: '+257 79 444 004',
    type: 'delivery',
    table: null,
    address: 'Rohero, Ave de la Liberté',
    amount: 35000,
    status: 'completed',
    payment: 'paid',
    at: '2026-03-08T20:00:00',
    notes: 'Sonner à la grille',
    lines: [
      { name: 'Poulet grillé', quantity: 1, unit_price: 18000 },
      { name: 'Riz sauce', quantity: 1, unit_price: 7000 },
      { name: 'Eau minérale', quantity: 2, unit_price: 5000 },
    ],
  },
  {
    id: 'mo-00003',
    reference: '00003',
    customer: 'Claude App',
    phone: '+257 79 555 005',
    type: 'dine_in',
    table: 'T8',
    address: null,
    amount: 12000,
    status: 'cancelled',
    payment: 'unpaid',
    at: '2026-03-08T16:20:00',
    notes: 'Client parti',
    lines: [
      { name: 'Café expresso', quantity: 2, unit_price: 6000 },
    ],
  },
  {
    id: 'mo-00010',
    reference: '00010',
    customer: 'David App',
    phone: '+257 79 666 006',
    type: 'dine_in',
    table: 'T1',
    address: null,
    amount: 95000,
    status: 'completed',
    payment: 'paid',
    at: '2026-03-07T22:10:00',
    notes: 'Anniversaire — bougie demandée',
    lines: [
      { name: 'Plateau mixte', quantity: 1, unit_price: 45000 },
      { name: 'Gâteau maison', quantity: 1, unit_price: 25000 },
      { name: 'Champagne', quantity: 1, unit_price: 25000 },
    ],
  },
  {
    id: 'mo-00009',
    reference: '00009',
    customer: 'Grace App',
    phone: '+257 79 777 007',
    type: 'takeaway',
    table: null,
    address: null,
    amount: 22000,
    status: 'completed',
    payment: 'partial',
    at: '2026-03-07T15:30:00',
    notes: 'Acompte mobile money reçu',
    lines: [
      { name: 'Wrap poulet', quantity: 2, unit_price: 8000 },
      { name: 'Smoothie mangue', quantity: 1, unit_price: 6000 },
    ],
  },
  {
    id: 'mo-00012',
    reference: '00012',
    customer: 'Sarah Mobile',
    phone: '+257 71 888 008',
    type: 'delivery',
    table: null,
    address: 'Kinindo, près du marché',
    amount: 41500,
    status: 'new',
    payment: 'paid',
    at: '2026-03-09T15:05:00',
    notes: 'Livraison urgente',
    lines: [
      { name: 'Sushi mix 12 pcs', quantity: 1, unit_price: 28000 },
      { name: 'Miso soup', quantity: 1, unit_price: 5500 },
      { name: 'Thé vert', quantity: 2, unit_price: 4000 },
    ],
  },
  {
    id: 'mo-00011',
    reference: '00011',
    customer: 'Eric App',
    phone: '+257 72 999 009',
    type: 'dine_in',
    table: 'T12',
    address: null,
    amount: 28000,
    status: 'processing',
    payment: 'unpaid',
    at: '2026-03-09T14:55:00',
    notes: 'Paiement à table',
    lines: [
      { name: 'Pâtes carbonara', quantity: 1, unit_price: 16000 },
      { name: 'Eau gazeuse', quantity: 2, unit_price: 6000 },
    ],
  },
]

export function cloneMobileOrders(): MobileOrder[] {
  return MOBILE_ORDERS_SEED.map(order => ({
    ...order,
    lines: order.lines.map(line => ({ ...line })),
  }))
}

export function nextStatuses(status: OrderStatus): OrderStatus[] {
  switch (status) {
    case 'new':
      return ['processing', 'cancelled']
    case 'processing':
      return ['completed', 'cancelled']
    default:
      return []
  }
}
