import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'

interface User {
  id: string
  email: string
  full_name: string
  role: string
  specialty?: string
  state_license?: string
  created_at: string
}

interface AuthState {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  login: (token: string, user: User) => void
  logout: () => void
  updateProfile: (user: Partial<User>) => void
}

export const useAuthStore = create<AuthState>()(
  devtools(
    persist(
      (set) => ({
        user: null,
        token: null,
        isAuthenticated: false,
        login: (token, user) => set({ token, user, isAuthenticated: true }),
        logout: () => set({ user: null, token: null, isAuthenticated: false }),
        updateProfile: (user) => set((state) => ({ user: { ...state.user!, ...user } })),
      }),
      {
        name: 'auth-storage',
      }
    )
  )
)
