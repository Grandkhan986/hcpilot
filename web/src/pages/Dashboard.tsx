import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../lib/api'
import {
  Users, Calendar, Euro,
  ArrowRight, Play, CheckCircle2, Package, Navigation,
  Bell, Route
} from 'lucide-react'

interface DashboardData {
  total_patients: number
  today_visits: number
  pending_invoices: number
  low_stock_alerts: number
  monthly_revenue: number
  visits_today: any[]
  low_stock_items: any[]
}

const Dashboard = () => {
  const [data, setData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()
  const user = JSON.parse(localStorage.getItem('user') || '{}')

  useEffect(() => {
    fetchDashboard()
  }, [])

  const fetchDashboard = async () => {
    try {
      const response = await api.get('/reports/dashboard')
      setData(response.data)
    } catch (err) {
      console.error('Failed to fetch dashboard', err)
    } finally {
      setLoading(false)
    }
  }

  const handleStartVisit = async (visitId: string) => {
    try {
      await api.post(`/visits/${visitId}/start`)
      fetchDashboard()
    } catch (err) {
      console.error('Failed to start visit', err)
    }
  }

  const handleCompleteVisit = async (visitId: string) => {
    try {
      await api.post(`/visits/${visitId}/complete`)
      fetchDashboard()
    } catch (err) {
      console.error('Failed to complete visit', err)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin w-8 h-8 border-4 border-teal-500 border-t-transparent rounded-full" />
      </div>
    )
  }

  const getVisitTypeLabel = (type: string) => {
    const types: Record<string, string> = {
      'Primary_Care': 'Soins primaires',
      'IV_Hydration': 'Perfusion IV',
      'Post_Op': 'Post-opératoire',
      'Vaccination': 'Vaccination',
      'Consultation': 'Consultation',
    }
    return types[type] || type.replace('_', ' ')
  }

  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'in_progress':
        return { label: 'En cours', class: 'bg-blue-100 text-blue-700', dot: 'bg-blue-500 animate-pulse' }
      case 'completed':
        return { label: 'Terminée', class: 'bg-green-100 text-green-700', dot: 'bg-green-500' }
      default:
        return { label: 'Planifiée', class: 'bg-slate-100 text-slate-600', dot: 'bg-slate-400' }
    }
  }

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* Header — comme iOS HomeView */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-slate-900">
            Bonjour, {user.full_name || 'Docteur'}
          </h1>
          <p className="text-sm text-slate-500">
            Aujourd'hui, {new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}
          </p>
        </div>
        <button
          type="button"
          title="Notifications"
          className="relative p-2.5 rounded-xl hover:bg-slate-100 text-slate-600 transition-colors"
        >
          <Bell className="w-5 h-5" />
          <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full" />
        </button>
      </div>

      {/* Stats Cards — grille 2 colonnes comme iOS LazyVGrid */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl border border-slate-200/80 p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-slate-500">Revenu du jour</p>
              <p className="text-2xl font-bold text-slate-900 mt-1">
                {(data?.monthly_revenue || 0).toLocaleString('fr-FR')} &euro;
              </p>
            </div>
            <div className="w-11 h-11 bg-green-100 rounded-full flex items-center justify-center">
              <Euro className="w-5 h-5 text-green-600" />
            </div>
          </div>
        </div>
        <div className="bg-white rounded-2xl border border-slate-200/80 p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-slate-500">Visites du jour</p>
              <p className="text-2xl font-bold text-slate-900 mt-1">{data?.today_visits || 0}</p>
            </div>
            <div className="w-11 h-11 bg-blue-100 rounded-full flex items-center justify-center">
              <Users className="w-5 h-5 text-blue-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Ma Journée — carte + boutons comme iOS */}
      <div className="bg-white rounded-2xl border border-slate-200/80 overflow-hidden">
        <div className="flex items-center justify-between p-5 pb-3">
          <h2 className="font-semibold text-slate-900">Ma Journée</h2>
          <button
            type="button"
            onClick={() => navigate('/visits')}
            className="text-sm text-teal-600 hover:text-teal-700 font-medium"
          >
            Optimiser
          </button>
        </div>

        {/* Carte placeholder */}
        <div className="mx-5 h-48 bg-gradient-to-br from-slate-100 to-slate-200 rounded-xl flex items-center justify-center relative overflow-hidden">
          <div className="absolute inset-0 opacity-30">
            <div className="absolute top-4 left-6 w-3 h-3 bg-teal-500 rounded-full" />
            <div className="absolute top-12 right-16 w-3 h-3 bg-blue-500 rounded-full" />
            <div className="absolute bottom-8 left-20 w-3 h-3 bg-purple-500 rounded-full" />
            <svg className="absolute inset-0 w-full h-full" viewBox="0 0 400 200">
              <path d="M 24 16 Q 100 60 184 48 Q 260 36 350 90 Q 380 108 320 140 Q 250 170 80 130" stroke="#14b8a6" strokeWidth="2" fill="none" strokeDasharray="6 4" opacity="0.5" />
            </svg>
          </div>
          <div className="text-center z-10">
            <Navigation className="w-8 h-8 text-teal-500 mx-auto mb-2" />
            <p className="text-sm text-slate-500 font-medium">
              {data?.today_visits || 0} visites · Paris
            </p>
          </div>
        </div>

        {/* Boutons Commencer / Options — comme iOS */}
        <div className="flex gap-3 p-5">
          <button
            type="button"
            onClick={() => {
              const firstScheduled = data?.visits_today?.find((v: any) => v.status === 'scheduled')
              if (firstScheduled) handleStartVisit(firstScheduled.id)
            }}
            className="flex-1 py-3 bg-teal-500 text-white font-medium rounded-xl hover:bg-teal-600 transition-colors shadow-md shadow-teal-500/20"
          >
            Commencer
          </button>
          <button
            type="button"
            title="Options de route"
            onClick={() => navigate('/visits')}
            className="px-4 py-3 bg-teal-50 text-teal-600 rounded-xl hover:bg-teal-100 transition-colors"
          >
            <Route className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Visites à venir — comme iOS "Visites à venir" */}
      <div className="bg-white rounded-2xl border border-slate-200/80">
        <div className="flex items-center justify-between p-5 pb-3">
          <h2 className="font-semibold text-slate-900">Visites à venir</h2>
          <button
            type="button"
            onClick={() => navigate('/visits')}
            className="text-sm text-teal-600 hover:text-teal-700 font-medium flex items-center gap-1"
          >
            Tout voir <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="px-5 pb-5 space-y-3">
          {data?.visits_today?.length === 0 && (
            <div className="text-center py-10">
              <Calendar className="w-10 h-10 text-slate-300 mx-auto mb-2" />
              <p className="text-slate-400">Aucune visite prévue</p>
            </div>
          )}

          {data?.visits_today?.map((visit: any) => {
            const status = getStatusConfig(visit.status)
            const visitTime = new Date(visit.visit_date).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })

            return (
              <div
                key={visit.id}
                className={`flex items-center gap-4 p-4 rounded-xl border transition-all group ${
                  visit.status === 'in_progress'
                    ? 'bg-blue-50/50 border-blue-200'
                    : 'bg-slate-50/50 border-slate-100 hover:border-slate-200'
                }`}
              >
                {/* Avatar initiales — comme iOS Circle overlay */}
                <div className="w-12 h-12 rounded-full bg-blue-500 flex items-center justify-center text-white text-sm font-semibold flex-shrink-0">
                  {getVisitTypeLabel(visit.visit_type).substring(0, 2).toUpperCase()}
                </div>

                {/* Infos */}
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-slate-900">
                    {getVisitTypeLabel(visit.visit_type)}
                  </p>
                  <p className="text-sm text-slate-500 truncate">
                    {visit.address}
                  </p>
                </div>

                {/* Heure + statut — comme iOS right side */}
                <div className="text-right flex-shrink-0">
                  <p className="font-medium text-slate-900">{visitTime}</p>
                  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-medium ${status.class}`}>
                    <span className={`w-1.5 h-1.5 rounded-full ${status.dot}`} />
                    {status.label}
                  </span>
                </div>

                {/* Actions au hover */}
                <div className="flex-shrink-0">
                  {visit.status === 'scheduled' && (
                    <button
                      type="button"
                      title="Commencer la visite"
                      onClick={() => handleStartVisit(visit.id)}
                      className="opacity-0 group-hover:opacity-100 p-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-all"
                    >
                      <Play className="w-4 h-4" />
                    </button>
                  )}
                  {visit.status === 'in_progress' && (
                    <button
                      type="button"
                      title="Terminer la visite"
                      onClick={() => handleCompleteVisit(visit.id)}
                      className="p-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-all"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Statut du Stock — comme iOS "Statut du Stock" */}
      <div className="bg-white rounded-2xl border border-slate-200/80">
        <div className="flex items-center justify-between p-5 pb-3">
          <div className="flex items-center gap-2">
            <h2 className="font-semibold text-slate-900">Statut du Stock</h2>
            {(data?.low_stock_alerts || 0) > 0 && (
              <span className="text-xs text-red-600 font-medium">
                {data?.low_stock_alerts} items faibles
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={() => navigate('/stock')}
            className="text-sm text-teal-600 hover:text-teal-700 font-medium"
          >
            Gérer
          </button>
        </div>

        {/* Cartes stock horizontales — comme iOS HStack prefix(3) */}
        <div className="px-5 pb-5 grid grid-cols-3 gap-3">
          {data?.low_stock_items?.slice(0, 3).map((item: any) => (
            <div
              key={item.id}
              className="p-4 rounded-xl bg-slate-50 border border-slate-100 text-center"
            >
              <div className="w-10 h-10 mx-auto mb-2 bg-amber-100 rounded-full flex items-center justify-center">
                <Package className="w-5 h-5 text-amber-600" />
              </div>
              <p className="text-sm font-medium text-slate-900 truncate">{item.product_name}</p>
              <p className={`text-lg font-bold mt-1 ${
                item.quantity <= item.min_quantity ? 'text-red-600' : 'text-slate-900'
              }`}>
                {item.quantity}
              </p>
              <p className="text-xs text-slate-500">
                {item.quantity <= item.min_quantity ? 'Stock faible' : 'Stock OK'}
              </p>
            </div>
          ))}

          {(!data?.low_stock_items || data.low_stock_items.length === 0) && (
            <div className="col-span-3 text-center py-6 text-slate-400 text-sm">
              Tout le stock est en ordre
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default Dashboard
