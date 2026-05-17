import { useState } from 'react'
import { Download, TrendingUp } from 'lucide-react'

const PERIODS = [
  { key: 'today', label: "Aujourd'hui" },
  { key: 'this_week', label: 'Cette semaine' },
  { key: 'this_month', label: 'Ce mois' },
  { key: 'this_year', label: 'Cette année' },
]

const DATA: Record<string, { revenue: string; visits: number; avg: string; trend: string; byType: { label: string; value: number }[]; monthly: { month: string; revenue: number }[] }> = {
  today: {
    revenue: '1 250,00 €', visits: 8, avg: '156,25 €', trend: '+12%',
    byType: [{ label: 'Perfusion IV', value: 800 }, { label: 'Post-Op', value: 350 }, { label: 'Soins primaires', value: 100 }],
    monthly: [],
  },
  this_week: {
    revenue: '5 800,00 €', visits: 35, avg: '165,71 €', trend: '+8%',
    byType: [{ label: 'Perfusion IV', value: 3500 }, { label: 'Post-Op', value: 1500 }, { label: 'Soins primaires', value: 800 }],
    monthly: [],
  },
  this_month: {
    revenue: '28 500,00 €', visits: 180, avg: '158,33 €', trend: '+12%',
    byType: [{ label: 'Perfusion IV', value: 18000 }, { label: 'Post-Op', value: 7000 }, { label: 'Soins primaires', value: 3500 }],
    monthly: [
      { month: 'Jan', revenue: 12000 }, { month: 'Fév', revenue: 15000 },
      { month: 'Mar', revenue: 18000 }, { month: 'Avr', revenue: 20000 },
      { month: 'Mai', revenue: 25000 }, { month: 'Jun', revenue: 28000 },
    ],
  },
  this_year: {
    revenue: '342 000,00 €', visits: 2160, avg: '158,33 €', trend: '+15%',
    byType: [{ label: 'Perfusion IV', value: 216000 }, { label: 'Post-Op', value: 84000 }, { label: 'Soins primaires', value: 42000 }],
    monthly: [],
  },
}

const Reports = () => {
  const [period, setPeriod] = useState('this_month')
  const data = DATA[period]
  const maxType = Math.max(...data.byType.map(t => t.value))
  const maxMonthly = Math.max(...data.monthly.map(m => m.revenue), 1)

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Header — comme iOS ReportsView */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Rapports</h1>
          <p className="text-sm text-slate-500">Analytiques de performance</p>
        </div>
        <button
          type="button"
          className="flex items-center gap-2 px-4 py-2.5 bg-teal-500 text-white rounded-xl text-sm font-medium hover:bg-teal-600 transition-colors shadow-md shadow-teal-500/20"
        >
          <Download className="w-4 h-4" />
          Exporter
        </button>
      </div>

      {/* Period segmented — comme iOS */}
      <div className="flex bg-slate-100 rounded-xl p-1">
        {PERIODS.map(p => (
          <button
            key={p.key}
            type="button"
            onClick={() => setPeriod(p.key)}
            className={`flex-1 py-2 text-xs font-medium rounded-lg transition-all ${
              period === p.key ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500'
            }`}
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* Metric cards — grille 3 colonnes comme iOS LazyVGrid */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Revenu total', value: data.revenue, color: 'text-green-600 bg-green-50', trend: data.trend },
          { label: 'Total visites', value: `${data.visits}`, color: 'text-blue-600 bg-blue-50', trend: '+8%' },
          { label: 'Panier moyen', value: data.avg, color: 'text-purple-600 bg-purple-50', trend: '-2%' },
        ].map((metric, i) => (
          <div key={i} className="bg-white rounded-2xl border border-slate-200/80 p-4">
            <div className="flex items-start justify-between mb-2">
              <div>
                <p className="text-xl font-bold text-slate-900">{metric.value}</p>
                <p className="text-xs text-slate-500 mt-0.5">{metric.label}</p>
              </div>
              <div className={`w-10 h-10 rounded-full ${metric.color} flex items-center justify-center`}>
                <TrendingUp className="w-4 h-4" />
              </div>
            </div>
            <p className="text-xs">
              <span className={metric.trend.startsWith('+') ? 'text-green-600 font-semibold' : 'text-red-600 font-semibold'}>
                {metric.trend}
              </span>
              <span className="text-slate-400 ml-1">vs mois dernier</span>
            </p>
          </div>
        ))}
      </div>

      {/* Revenue by type — barres comme iOS RevenueBar */}
      <div className="bg-white rounded-2xl border border-slate-200/80 p-5">
        <h2 className="font-semibold text-slate-900 mb-4">Revenus par type de service</h2>
        <div className="space-y-4">
          {data.byType.map((item, i) => (
            <div key={i}>
              <div className="flex justify-between text-sm mb-1">
                <span className="text-slate-700">{item.label}</span>
                <span className="font-semibold text-slate-900">{item.value.toLocaleString('fr-FR')} &euro;</span>
              </div>
              <div className="w-full h-2 bg-slate-100 rounded-full overflow-hidden">
                <div
                  className="h-full bg-teal-500 rounded-full transition-all duration-500"
                  style={{ width: `${(item.value / maxType) * 100}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Monthly chart — barres comme iOS MonthlyBar */}
      {data.monthly.length > 0 && (
        <div className="bg-white rounded-2xl border border-slate-200/80 p-5">
          <h2 className="font-semibold text-slate-900 mb-4">Revenus mensuels</h2>
          <div className="space-y-3">
            {data.monthly.map((m, i) => (
              <div key={i} className="flex items-center gap-3">
                <span className="text-sm text-slate-500 w-8">{m.month}</span>
                <div className="flex-1 h-3 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-blue-500 rounded-full transition-all duration-500"
                    style={{ width: `${(m.revenue / maxMonthly) * 100}%` }}
                  />
                </div>
                <span className="text-sm font-semibold text-slate-900 w-20 text-right">
                  {(m.revenue / 1000).toFixed(0)}k &euro;
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

export default Reports
