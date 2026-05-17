import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  User, Mail, Bell, CreditCard, FileText, Settings as SettingsIcon,
  Info, LogOut, ChevronRight, DollarSign
} from 'lucide-react'

const Settings = () => {
  const navigate = useNavigate()
  const user = JSON.parse(localStorage.getItem('user') || '{}')
  const [notifications, setNotifications] = useState(true)
  const [emailNotifs, setEmailNotifs] = useState(true)
  const [darkMode, setDarkMode] = useState(false)
  const [autoOptimize, setAutoOptimize] = useState(true)

  const handleLogout = () => {
    localStorage.removeItem('auth_token')
    localStorage.removeItem('user')
    navigate('/auth/login')
  }

  return (
    <div className="max-w-xl mx-auto space-y-6">
      {/* Profile header — comme iOS ProfileView */}
      <div className="flex flex-col items-center py-6">
        <div className="w-24 h-24 rounded-full bg-blue-500 flex items-center justify-center text-white text-3xl mb-3">
          <User className="w-12 h-12" />
        </div>
        <h2 className="text-lg font-bold text-slate-900">{user.full_name || 'Utilisateur'}</h2>
        <p className="text-sm text-slate-500">{user.specialty || 'Professionnel de santé'}</p>
      </div>

      {/* Stats — comme iOS LazyVGrid 3 colonnes */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { value: '4 250 €', label: 'Revenu du jour' },
          { value: '3', label: 'Visites' },
          { value: '1', label: 'En attente' },
        ].map((stat, i) => (
          <div key={i} className="bg-white rounded-2xl border border-slate-200/80 p-4 text-center">
            <p className="text-lg font-bold text-slate-900">{stat.value}</p>
            <p className="text-xs text-slate-500 mt-0.5">{stat.label}</p>
          </div>
        ))}
      </div>

      {/* Menu sections — comme iOS MenuSection / MenuItem */}
      <div className="space-y-4">
        {/* Compte */}
        <div className="bg-white rounded-2xl border border-slate-200/80 overflow-hidden">
          <p className="px-4 pt-4 pb-2 text-xs font-medium text-slate-400 uppercase">Compte</p>
          <MenuItem icon={User} label="Mon profil" />
          <MenuItem icon={Mail} label="Messages" />
          <MenuItem icon={Bell} label="Notifications" />
        </div>

        {/* Finance */}
        <div className="bg-white rounded-2xl border border-slate-200/80 overflow-hidden">
          <p className="px-4 pt-4 pb-2 text-xs font-medium text-slate-400 uppercase">Finance</p>
          <MenuItem icon={DollarSign} label="Revenus" onClick={() => navigate('/reports')} />
          <MenuItem icon={FileText} label="Factures" onClick={() => navigate('/invoices')} />
          <MenuItem icon={CreditCard} label="Paiements" />
        </div>

        {/* Configuration — toggles comme iOS SettingsView */}
        <div className="bg-white rounded-2xl border border-slate-200/80 overflow-hidden">
          <p className="px-4 pt-4 pb-2 text-xs font-medium text-slate-400 uppercase">Configuration</p>
          <ToggleItem label="Notifications push" checked={notifications} onChange={setNotifications} />
          <ToggleItem label="Notifications email" checked={emailNotifs} onChange={setEmailNotifs} />
          <ToggleItem label="Mode sombre" checked={darkMode} onChange={setDarkMode} />
          <ToggleItem label="Optimisation auto des itinéraires" checked={autoOptimize} onChange={setAutoOptimize} />
          <MenuItem icon={SettingsIcon} label="Paramètres" />
          <MenuItem icon={Info} label="À propos" />
        </div>

        {/* Logout */}
        <button
          type="button"
          onClick={handleLogout}
          className="w-full bg-white rounded-2xl border border-slate-200/80 p-4 flex items-center gap-3 text-red-600 hover:bg-red-50 transition-colors"
        >
          <LogOut className="w-5 h-5" />
          <span className="text-sm font-medium">Déconnexion</span>
        </button>
      </div>

      <p className="text-center text-xs text-slate-400 pb-4">HCPilot v1.0.0</p>
    </div>
  )
}

function MenuItem({ icon: Icon, label, onClick }: { icon: any; label: string; onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full flex items-center gap-3 px-4 py-3 hover:bg-slate-50 transition-colors border-t border-slate-100 first:border-t-0"
    >
      <Icon className="w-5 h-5 text-slate-600" />
      <span className="flex-1 text-left text-sm text-slate-900">{label}</span>
      <ChevronRight className="w-4 h-4 text-slate-300" />
    </button>
  )
}

function ToggleItem({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="flex items-center justify-between px-4 py-3 border-t border-slate-100 first:border-t-0">
      <span className="text-sm text-slate-900">{label}</span>
      <button
        type="button"
        role="switch"
        title={label}
        aria-checked={checked ? 'true' : 'false'}
        onClick={() => onChange(!checked)}
        className={`relative w-11 h-6 rounded-full transition-colors ${checked ? 'bg-teal-500' : 'bg-slate-200'}`}
      >
        <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow-sm transition-transform ${checked ? 'translate-x-5' : ''}`} />
      </button>
    </div>
  )
}

export default Settings
