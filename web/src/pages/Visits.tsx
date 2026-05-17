import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../lib/api'
import {
  Plus, Clock, MapPin, Play, CheckCircle2,
  XCircle, Euro, FileText, Timer
} from 'lucide-react'

interface Visit {
  id: string
  patient_id: string
  visit_date: string
  visit_type: string
  status: string
  address: string
  estimated_duration: number
  notes?: string
  total_amount: number
}

interface Patient {
  id: string
  first_name: string
  last_name: string
}

const Visits = () => {
  const [visits, setVisits] = useState<Visit[]>([])
  const [patients, setPatients] = useState<Patient[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const navigate = useNavigate()

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    try {
      const [visitsRes, patientsRes] = await Promise.all([
        api.get('/visits'),
        api.get('/patients'),
      ])
      setVisits(visitsRes.data)
      setPatients(patientsRes.data)
    } catch (err) {
      console.error('Failed to fetch data', err)
    } finally {
      setLoading(false)
    }
  }

  const startVisit = async (visitId: string) => {
    try {
      await api.post(`/visits/${visitId}/start`)
      setVisits(visits.map(v => v.id === visitId ? { ...v, status: 'in_progress' } : v))
    } catch (err) {
      console.error('Failed to start visit', err)
    }
  }

  const completeVisit = async (visitId: string) => {
    try {
      await api.post(`/visits/${visitId}/complete`)
      setVisits(visits.map(v => v.id === visitId ? { ...v, status: 'completed' } : v))
    } catch (err) {
      console.error('Failed to complete visit', err)
    }
  }

  const getPatientName = (patientId: string) => {
    const patient = patients.find(p => p.id === patientId)
    return patient ? `${patient.first_name} ${patient.last_name}` : 'Patient inconnu'
  }

  const getVisitTypeLabel = (type: string) => {
    const types: Record<string, string> = {
      'Primary_Care': 'Soins primaires',
      'IV_Hydration': 'Perfusion IV',
      'Post_Op': 'Post-opératoire',
    }
    return types[type] || type.replace('_', ' ')
  }

  const getVisitTypeColor = (type: string) => {
    switch (type) {
      case 'IV_Hydration': return 'bg-purple-100 text-purple-700'
      case 'Post_Op': return 'bg-blue-100 text-blue-700'
      default: return 'bg-teal-100 text-teal-700'
    }
  }

  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'in_progress':
        return { label: 'En cours', class: 'bg-blue-500 text-white', icon: Timer }
      case 'completed':
        return { label: 'Terminée', class: 'bg-emerald-100 text-emerald-700', icon: CheckCircle2 }
      case 'cancelled':
        return { label: 'Annulée', class: 'bg-red-100 text-red-700', icon: XCircle }
      default:
        return { label: 'Planifiée', class: 'bg-slate-100 text-slate-600', icon: Clock }
    }
  }

  const filteredVisits = visits.filter(v => {
    if (filter === 'all') return true
    return v.status === filter
  })

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
          <h1 className="text-2xl font-bold text-slate-900">Visites</h1>
          <p className="text-slate-500 mt-0.5">Gérez vos visites et suivez votre tournée</p>
        </div>
        <button
          type="button"
          className="flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-teal-500 to-teal-600 text-white rounded-xl font-medium text-sm hover:from-teal-600 hover:to-teal-700 transition-all shadow-lg shadow-teal-500/25"
        >
          <Plus className="w-4 h-4" />
          Nouvelle visite
        </button>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-2 flex-wrap">
        {[
          { key: 'all', label: 'Toutes', count: visits.length },
          { key: 'scheduled', label: 'Planifiées', count: visits.filter(v => v.status === 'scheduled').length },
          { key: 'in_progress', label: 'En cours', count: visits.filter(v => v.status === 'in_progress').length },
          { key: 'completed', label: 'Terminées', count: visits.filter(v => v.status === 'completed').length },
        ].map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setFilter(tab.key)}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              filter === tab.key
                ? 'bg-teal-500 text-white shadow-md shadow-teal-500/25'
                : 'bg-white text-slate-600 border border-slate-200 hover:border-slate-300'
            }`}
          >
            {tab.label}
            <span className={`ml-1.5 px-1.5 py-0.5 rounded-md text-xs ${
              filter === tab.key ? 'bg-white/20' : 'bg-slate-100'
            }`}>
              {tab.count}
            </span>
          </button>
        ))}
      </div>

      {/* Visits timeline */}
      <div className="space-y-4">
        {filteredVisits.map((visit) => {
          const status = getStatusConfig(visit.status)
          const visitTime = new Date(visit.visit_date).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
          const isActive = visit.status === 'in_progress'

          return (
            <div
              key={visit.id}
              className={`bg-white rounded-2xl border p-5 transition-all ${
                isActive
                  ? 'border-blue-200 ring-2 ring-blue-500/10 shadow-lg'
                  : 'border-slate-200/80 hover:shadow-md hover:border-slate-300'
              }`}
            >
              <div className="flex items-center gap-5">
                {/* Time block */}
                <div className={`flex-shrink-0 w-16 h-16 rounded-xl flex flex-col items-center justify-center ${
                  isActive ? 'bg-blue-500 text-white' : 'bg-slate-100 text-slate-700'
                }`}>
                  <span className="text-lg font-bold">{visitTime.split(':')[0]}</span>
                  <span className="text-xs">:{visitTime.split(':')[1]}</span>
                </div>

                {/* Visit info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-3 mb-1">
                    <h3 className="font-semibold text-slate-900">{getPatientName(visit.patient_id)}</h3>
                    <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${getVisitTypeColor(visit.visit_type)}`}>
                      {getVisitTypeLabel(visit.visit_type)}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-sm text-slate-500">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5" />
                      {visit.address}
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5" />
                      {visit.estimated_duration} min
                    </span>
                    <span className="flex items-center gap-1">
                      <Euro className="w-3.5 h-3.5" />
                      {visit.total_amount.toFixed(2)}
                    </span>
                  </div>
                  {visit.notes && (
                    <p className="text-sm text-slate-500 mt-1 italic">"{visit.notes}"</p>
                  )}
                </div>

                {/* Status + Actions */}
                <div className="flex items-center gap-3 flex-shrink-0">
                  <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold ${status.class}`}>
                    <status.icon className="w-3.5 h-3.5" />
                    {status.label}
                  </span>

                  {visit.status === 'scheduled' && (
                    <button
                      type="button"
                      onClick={() => startVisit(visit.id)}
                      className="flex items-center gap-2 px-4 py-2 bg-teal-500 text-white rounded-xl text-sm font-medium hover:bg-teal-600 transition-colors shadow-md shadow-teal-500/20"
                    >
                      <Play className="w-4 h-4" />
                      Démarrer
                    </button>
                  )}

                  {visit.status === 'in_progress' && (
                    <button
                      type="button"
                      onClick={() => completeVisit(visit.id)}
                      className="flex items-center gap-2 px-4 py-2 bg-emerald-500 text-white rounded-xl text-sm font-medium hover:bg-emerald-600 transition-colors shadow-md shadow-emerald-500/20"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      Terminer
                    </button>
                  )}

                  {visit.status === 'completed' && (
                    <button
                      type="button"
                      onClick={() => navigate('/invoices')}
                      className="flex items-center gap-2 px-4 py-2 bg-slate-100 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-200 transition-colors"
                    >
                      <FileText className="w-4 h-4" />
                      Facturer
                    </button>
                  )}
                </div>
              </div>
            </div>
          )
        })}

        {filteredVisits.length === 0 && (
          <div className="text-center py-16 bg-white rounded-2xl border border-slate-200/80">
            <Clock className="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <p className="text-slate-500 font-medium">Aucune visite dans cette catégorie</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default Visits
