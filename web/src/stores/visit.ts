import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

interface Visit {
  id: string
  patient_id: string
  provider_id: string
  visit_date: string
  visit_type: string
  status: string
  address: string
  estimated_duration: number
  notes?: string
  total_amount: number
  copay?: number
  created_at: string
  updated_at: string
}

interface VisitState {
  visits: Visit[]
  currentVisit: Visit | null
  addVisit: (visit: Visit) => void
  updateVisit: (visit: Visit) => void
  deleteVisit: (id: string) => void
  setCurrentVisit: (visit: Visit | null) => void
  getTodayVisits: () => Visit[]
  getUpcomingVisits: () => Visit[]
}

export const useVisitStore = create<VisitState>()(
  devtools((set, get) => ({
    visits: [],
    currentVisit: null,
    addVisit: (visit) => set((state) => ({ visits: [...state.visits, visit] })),
    updateVisit: (visit) =>
      set((state) => ({
        visits: state.visits.map((v) => (v.id === visit.id ? visit : v)),
        currentVisit: state.currentVisit?.id === visit.id ? visit : state.currentVisit,
      })),
    deleteVisit: (id) => set((state) => ({ visits: state.visits.filter((v) => v.id !== id) })),
    setCurrentVisit: (visit) => set({ currentVisit: visit }),
    getTodayVisits: () => {
      const today = new Date().toISOString().split('T')[0]
      return get().visits.filter((v) => v.visit_date.startsWith(today))
    },
    getUpcomingVisits: () => {
      const now = new Date().toISOString()
      return get().visits.filter((v) => v.visit_date > now && v.status === 'scheduled')
    },
  }))
)
