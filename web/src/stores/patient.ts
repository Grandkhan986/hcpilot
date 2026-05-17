import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

interface Patient {
  id: string
  first_name: string
  last_name: string
  email?: string
  phone?: string
  date_of_birth?: string
  gender?: string
  address?: string
  medical_history?: string
  allergies?: string
  created_at: string
  updated_at: string
}

interface PatientState {
  patients: Patient[]
  currentPatient: Patient | null
  addPatient: (patient: Patient) => void
  updatePatient: (patient: Patient) => void
  deletePatient: (id: string) => void
  setCurrentPatient: (patient: Patient | null) => void
}

export const usePatientStore = create<PatientState>()(
  devtools((set) => ({
    patients: [],
    currentPatient: null,
    addPatient: (patient) => set((state) => ({ patients: [...state.patients, patient] })),
    updatePatient: (patient) =>
      set((state) => ({
        patients: state.patients.map((p) => (p.id === patient.id ? patient : p)),
      })),
    deletePatient: (id) => set((state) => ({ patients: state.patients.filter((p) => p.id !== id) })),
    setCurrentPatient: (patient) => set({ currentPatient: patient }),
  }))
)
