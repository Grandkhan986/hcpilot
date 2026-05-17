import { useState, useEffect } from 'react'
import api from '../lib/api'
import { Search, Plus, FileText, Calendar, Clock } from 'lucide-react'

interface Invoice {
  id: string
  patient_id: string
  invoice_number: string
  items: { description: string; quantity: number; price: number }[]
  total: number
  status: string
  due_date: string
  paid_at?: string
  created_at: string
}

const Invoices = () => {
  const [invoices, setInvoices] = useState<Invoice[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filter, setFilter] = useState('all')

  useEffect(() => {
    fetchInvoices()
  }, [])

  const fetchInvoices = async () => {
    try {
      const response = await api.get('/invoices')
      setInvoices(response.data)
    } catch (err) {
      console.error('Failed to fetch invoices', err)
    } finally {
      setLoading(false)
    }
  }

  const filteredInvoices = invoices.filter(inv => {
    const matchesSearch = inv.invoice_number.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesFilter = filter === 'all' || inv.status === filter
    return matchesSearch && matchesFilter
  })

  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'paid': return { label: 'Payée', class: 'bg-green-100 text-green-700', letter: 'P', color: 'bg-green-500' }
      case 'sent': return { label: 'Envoyée', class: 'bg-blue-100 text-blue-700', letter: 'E', color: 'bg-blue-500' }
      case 'overdue': return { label: 'En retard', class: 'bg-red-100 text-red-700', letter: 'R', color: 'bg-red-500' }
      default: return { label: 'Brouillon', class: 'bg-slate-100 text-slate-600', letter: 'B', color: 'bg-slate-400' }
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin w-8 h-8 border-4 border-teal-500 border-t-transparent rounded-full" />
      </div>
    )
  }

  return (
    <div className="max-w-3xl mx-auto space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-900">Factures</h1>
        <button type="button" title="Nouvelle facture" className="p-2.5 bg-teal-500 text-white rounded-xl hover:bg-teal-600 transition-colors shadow-md shadow-teal-500/20">
          <Plus className="w-5 h-5" />
        </button>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
        <input
          type="text"
          placeholder="Rechercher..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full pl-11 pr-4 py-2.5 rounded-xl bg-slate-100 border-0 focus:bg-white focus:ring-2 focus:ring-teal-500/20 transition-all outline-none text-sm"
        />
      </div>

      {/* Segmented filter — comme iOS */}
      <div className="flex bg-slate-100 rounded-xl p-1">
        {[
          { key: 'all', label: 'Tous' },
          { key: 'paid', label: 'Payées' },
          { key: 'sent', label: 'Envoyées' },
          { key: 'draft', label: 'En attente' },
          { key: 'overdue', label: 'En retard' },
        ].map(tab => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setFilter(tab.key)}
            className={`flex-1 py-2 text-xs font-medium rounded-lg transition-all ${
              filter === tab.key
                ? 'bg-white text-slate-900 shadow-sm'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Invoice list — comme iOS InvoiceListItem */}
      <div className="space-y-2">
        {filteredInvoices.map(invoice => {
          const status = getStatusConfig(invoice.status)
          return (
            <div key={invoice.id} className="bg-white rounded-2xl border border-slate-200/80 p-4 flex items-center gap-4 hover:shadow-sm transition-shadow">
              {/* Circle avatar — comme iOS */}
              <div className={`w-12 h-12 rounded-full ${status.color} flex items-center justify-center text-white font-bold text-sm flex-shrink-0`}>
                {status.letter}
              </div>

              {/* Info */}
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-slate-900">{invoice.invoice_number}</p>
                <p className="text-sm text-slate-500">
                  {invoice.items?.[0]?.description || 'Facture'}
                </p>
                <div className="flex items-center gap-1 mt-1 text-xs text-slate-400">
                  <Calendar className="w-3 h-3" />
                  {new Date(invoice.created_at).toLocaleDateString('fr-FR')}
                </div>
              </div>

              {/* Amount + due date */}
              <div className="text-right flex-shrink-0">
                <p className="text-lg font-bold text-slate-900">
                  {invoice.total.toFixed(2)} &euro;
                </p>
                <div className="flex items-center gap-1 text-xs text-slate-400 justify-end">
                  <Clock className="w-3 h-3" />
                  {new Date(invoice.due_date).toLocaleDateString('fr-FR')}
                </div>
              </div>

              {/* Status badge */}
              <span className={`px-2 py-1 rounded-md text-xs font-semibold flex-shrink-0 ${status.class}`}>
                {status.label}
              </span>
            </div>
          )
        })}

        {filteredInvoices.length === 0 && (
          <div className="text-center py-12">
            <FileText className="w-10 h-10 text-slate-300 mx-auto mb-2" />
            <p className="text-slate-400">Aucune facture trouvée</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default Invoices
