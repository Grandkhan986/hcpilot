import { useState, useEffect } from 'react'
import api from '../lib/api'
import {
  Search, Plus, Phone, Mail, MapPin,
  Heart, AlertCircle
} from 'lucide-react'

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
}

const Patients = () => {
  const [patients, setPatients] = useState<Patient[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null)

  useEffect(() => {
    fetchPatients()
  }, [])

  const fetchPatients = async () => {
    try {
      const response = await api.get('/patients')
      setPatients(response.data)
    } catch (err) {
      console.error('Failed to fetch patients', err)
    } finally {
      setLoading(false)
    }
  }

  const filteredPatients = patients.filter(patient => {
    const fullName = `${patient.first_name} ${patient.last_name}`.toLowerCase()
    return (
      fullName.includes(searchTerm.toLowerCase()) ||
      patient.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      patient.phone?.includes(searchTerm)
    )
  })

  const getAge = (dob?: string) => {
    if (!dob) return null
    const birth = new Date(dob)
    const age = Math.floor((Date.now() - birth.getTime()) / (365.25 * 24 * 60 * 60 * 1000))
    return age
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin w-8 h-8 border-4 border-teal-500 border-t-transparent rounded-full" />
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Patients</h1>
          <p className="text-slate-500 mt-0.5">{patients.length} patient(s) enregistré(s)</p>
        </div>
        <button
          type="button"
          className="flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-teal-500 to-teal-600 text-white rounded-xl font-medium text-sm hover:from-teal-600 hover:to-teal-700 transition-all shadow-lg shadow-teal-500/25"
        >
          <Plus className="w-4 h-4" />
          Nouveau patient
        </button>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
        <input
          type="text"
          placeholder="Rechercher par nom, email ou téléphone..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full pl-12 pr-4 py-3 rounded-xl border border-slate-200 bg-white focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all outline-none text-sm"
        />
      </div>

      {/* Patient grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filteredPatients.map((patient) => (
          <div
            key={patient.id}
            onClick={() => setSelectedPatient(selectedPatient?.id === patient.id ? null : patient)}
            className={`bg-white rounded-2xl border p-5 cursor-pointer transition-all hover:shadow-md ${
              selectedPatient?.id === patient.id
                ? 'border-teal-300 ring-2 ring-teal-500/20 shadow-md'
                : 'border-slate-200/80 hover:border-slate-300'
            }`}
          >
            {/* Patient header */}
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 rounded-full bg-gradient-to-br from-teal-400 to-emerald-500 flex items-center justify-center text-white font-semibold shadow-sm">
                {patient.first_name[0]}{patient.last_name[0]}
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-semibold text-slate-900 truncate">
                  {patient.first_name} {patient.last_name}
                </h3>
                <div className="flex items-center gap-2 text-sm text-slate-500">
                  {patient.gender === 'M' ? 'Homme' : 'Femme'}
                  {getAge(patient.date_of_birth) && (
                    <span>· {getAge(patient.date_of_birth)} ans</span>
                  )}
                </div>
              </div>
            </div>

            {/* Contact */}
            <div className="space-y-2 mb-4">
              {patient.phone && (
                <div className="flex items-center gap-2 text-sm text-slate-600">
                  <Phone className="w-4 h-4 text-slate-400" />
                  <span>{patient.phone}</span>
                </div>
              )}
              {patient.email && (
                <div className="flex items-center gap-2 text-sm text-slate-600">
                  <Mail className="w-4 h-4 text-slate-400" />
                  <span className="truncate">{patient.email}</span>
                </div>
              )}
              {patient.address && (
                <div className="flex items-center gap-2 text-sm text-slate-600">
                  <MapPin className="w-4 h-4 text-slate-400" />
                  <span className="truncate">{patient.address}</span>
                </div>
              )}
            </div>

            {/* Medical info */}
            {selectedPatient?.id === patient.id && (
              <div className="pt-4 border-t border-slate-100 space-y-3 animate-in fade-in">
                {patient.medical_history && (
                  <div className="flex items-start gap-2">
                    <Heart className="w-4 h-4 text-red-400 mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-xs font-medium text-slate-500 uppercase">Antécédents</p>
                      <p className="text-sm text-slate-700">{patient.medical_history}</p>
                    </div>
                  </div>
                )}
                {patient.allergies && (
                  <div className="flex items-start gap-2">
                    <AlertCircle className="w-4 h-4 text-amber-500 mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-xs font-medium text-slate-500 uppercase">Allergies</p>
                      <p className="text-sm text-red-600 font-medium">{patient.allergies}</p>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>

      {filteredPatients.length === 0 && (
        <div className="text-center py-12">
          <Search className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <p className="text-slate-500">Aucun patient trouvé</p>
        </div>
      )}
    </div>
  )
}

export default Patients
