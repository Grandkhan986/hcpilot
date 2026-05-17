import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

interface Invoice {
  id: string
  patient_id: string
  provider_id: string
  visit_id: string
  invoice_number: string
  items: Array<{ description: string; quantity: number; price: number }>
  subtotal: number
  tax: number
  discount: number
  total: number
  status: 'draft' | 'sent' | 'paid' | 'overdue'
  due_date: string
  paid_at?: string
  stripe_payment_intent_id?: string
  created_at: string
  updated_at: string
}

interface InvoiceState {
  invoices: Invoice[]
  currentInvoice: Invoice | null
  addInvoice: (invoice: Invoice) => void
  updateInvoice: (invoice: Invoice) => void
  deleteInvoice: (id: string) => void
  setCurrentInvoice: (invoice: Invoice | null) => void
}

export const useInvoiceStore = create<InvoiceState>()(
  devtools((set) => ({
    invoices: [],
    currentInvoice: null,
    addInvoice: (invoice) => set((state) => ({ invoices: [...state.invoices, invoice] })),
    updateInvoice: (invoice) =>
      set((state) => ({
        invoices: state.invoices.map((i) => (i.id === invoice.id ? invoice : i)),
      })),
    deleteInvoice: (id) => set((state) => ({ invoices: state.invoices.filter((i) => i.id !== id) })),
    setCurrentInvoice: (invoice) => set({ currentInvoice: invoice }),
  }))
)
