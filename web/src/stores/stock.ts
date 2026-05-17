import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

interface StockItem {
  id: string
  provider_id: string
  product_name: string
  description?: string
  quantity: number
  min_quantity: number
  expiration_date?: string
  barcode?: string
  category: string
  cost_per_unit: number
  created_at: string
  updated_at: string
}

interface StockState {
  items: StockItem[]
  lowStockItems: StockItem[]
  addStockItem: (item: StockItem) => void
  updateStockItem: (item: StockItem) => void
  deleteStockItem: (id: string) => void
  updateQuantity: (id: string, quantity: number) => void
  getItemsByCategory: (category: string) => StockItem[]
}

export const useStockStore = create<StockState>()(
  devtools((set, get) => ({
    items: [],
    lowStockItems: [],
    addStockItem: (item) => set((state) => ({ items: [...state.items, item] })),
    updateStockItem: (item) =>
      set((state) => ({
        items: state.items.map((i) => (i.id === item.id ? item : i)),
      })),
    deleteStockItem: (id) => set((state) => ({ items: state.items.filter((i) => i.id !== id) })),
    updateQuantity: (id, quantity) =>
      set((state) => ({
        items: state.items.map((i) => (i.id === id ? { ...i, quantity } : i)),
      })),
    getItemsByCategory: (category) => get().items.filter((i) => i.category === category),
  }))
)
