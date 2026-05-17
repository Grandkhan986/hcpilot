import { create } from 'zustand'
import { devtools } from 'zustand/middleware'
import api from '../lib/api'

interface DashboardStats {
  total_visits: number
  today_visits: number
  total_revenue: number
  today_revenue: number
  pending_invoices: number
  low_stock_items: number
  upcoming_visits: number
  completed_visits: number
}

interface DashboardState {
  stats: DashboardStats
  loading: boolean
  fetchStats: () => Promise<void>
}

export const useDashboardStore = create<DashboardState>()(
  devtools((set) => ({
    stats: {
      total_visits: 0,
      today_visits: 0,
      total_revenue: 0,
      today_revenue: 0,
      pending_invoices: 0,
      low_stock_items: 0,
      upcoming_visits: 0,
      completed_visits: 0,
    },
    loading: false,
    fetchStats: async () => {
      set({ loading: true })
      try {
        const response = await api.get('/reports/dashboard')
        set({ stats: response.data, loading: false })
      } catch (error) {
        set({ loading: false })
      }
    },
  }))
)
