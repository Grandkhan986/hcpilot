import { useState, useEffect } from 'react'
import api from '../lib/api'
import { Search, Plus, Package, AlertTriangle, CheckCircle2 } from 'lucide-react'

interface StockItem {
  id: string
  product_name: string
  description?: string
  quantity: number
  min_quantity: number
  expiration_date?: string
  category: string
  cost_per_unit: number
}

const CATEGORIES = ['Toutes', 'IV_Supplies', 'Medication', 'Equipment']

const Stock = () => {
  const [stock, setStock] = useState<StockItem[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('Toutes')

  useEffect(() => {
    fetchStock()
  }, [])

  const fetchStock = async () => {
    try {
      const response = await api.get('/stock')
      setStock(response.data)
    } catch (err) {
      console.error('Failed to fetch stock', err)
    } finally {
      setLoading(false)
    }
  }

  const filteredStock = stock.filter(item => {
    const matchesSearch = item.product_name.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesCategory = selectedCategory === 'Toutes' || item.category === selectedCategory
    return matchesSearch && matchesCategory
  })

  const getCategoryLabel = (cat: string) => {
    const labels: Record<string, string> = {
      'Toutes': 'Toutes',
      'IV_Supplies': 'IV',
      'Medication': 'Médicaments',
      'Equipment': 'Équipement',
    }
    return labels[cat] || cat
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
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-900">Stock</h1>
        <button
          type="button"
          title="Ajouter un article"
          className="p-2.5 bg-teal-500 text-white rounded-xl hover:bg-teal-600 transition-colors shadow-md shadow-teal-500/20"
        >
          <Plus className="w-5 h-5" />
        </button>
      </div>

      {/* Search — comme iOS SearchBar */}
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

      {/* Segmented picker — comme iOS SegmentedPickerStyle */}
      <div className="flex bg-slate-100 rounded-xl p-1">
        {CATEGORIES.map(cat => (
          <button
            key={cat}
            type="button"
            onClick={() => setSelectedCategory(cat)}
            className={`flex-1 py-2 text-sm font-medium rounded-lg transition-all ${
              selectedCategory === cat
                ? 'bg-white text-slate-900 shadow-sm'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            {getCategoryLabel(cat)}
          </button>
        ))}
      </div>

      {/* Stock list — comme iOS List StockListItem */}
      <div className="space-y-2">
        {filteredStock.map(item => {
          const isLow = item.quantity <= item.min_quantity
          return (
            <div
              key={item.id}
              className="bg-white rounded-2xl border border-slate-200/80 p-4 flex items-center justify-between hover:shadow-sm transition-shadow"
            >
              <div>
                <p className="font-semibold text-slate-900">{item.product_name}</p>
                <p className="text-sm text-slate-500">{getCategoryLabel(item.category)}</p>
              </div>
              <div className="text-right">
                <p className={`text-lg font-bold ${isLow ? 'text-red-600' : 'text-slate-900'}`}>
                  {item.quantity}
                </p>
                {isLow ? (
                  <span className="inline-flex items-center gap-1 text-xs text-red-600 font-medium">
                    <AlertTriangle className="w-3 h-3" />
                    Stock faible
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 text-xs text-green-600 font-medium">
                    <CheckCircle2 className="w-3 h-3" />
                    Stock OK
                  </span>
                )}
              </div>
            </div>
          )
        })}

        {filteredStock.length === 0 && (
          <div className="text-center py-12">
            <Package className="w-10 h-10 text-slate-300 mx-auto mb-2" />
            <p className="text-slate-400">Aucun article trouvé</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default Stock
