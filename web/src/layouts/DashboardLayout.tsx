import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard, Users, Calendar, Package, FileText,
  BarChart3, Settings, LogOut, Menu, Bell, Activity,
  ChevronLeft
} from 'lucide-react'
import { useState } from 'react'

const DashboardLayout = () => {
  const navigate = useNavigate()
  const [isSidebarOpen, setIsSidebarOpen] = useState(true)
  const user = JSON.parse(localStorage.getItem('user') || '{}')

  const handleLogout = () => {
    localStorage.removeItem('auth_token')
    localStorage.removeItem('user')
    navigate('/auth/login')
  }

  // Même ordre que les tabs iOS (AppMainView.swift)
  const navItems = [
    { path: '/', label: 'Accueil', icon: LayoutDashboard },
    { path: '/visits', label: 'Visites', icon: Calendar },
    { path: '/stock', label: 'Stock', icon: Package },
    { path: '/invoices', label: 'Factures', icon: FileText },
    { path: '/reports', label: 'Rapports', icon: BarChart3 },
    { path: '/patients', label: 'Patients', icon: Users },
    { path: '/settings', label: 'Profil', icon: Settings },
  ]

  return (
    <div className="flex h-screen bg-slate-50/50">
      {/* Sidebar */}
      <aside className={`${isSidebarOpen ? 'w-64' : 'w-[72px]'} transition-all duration-300 ease-in-out bg-white border-r border-slate-200/80 flex flex-col relative`}>
        {/* Logo */}
        <div className="h-16 flex items-center px-4 border-b border-slate-100">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-gradient-to-br from-teal-500 to-teal-600 rounded-xl flex items-center justify-center shadow-lg shadow-teal-500/20">
              <Activity className="w-5 h-5 text-white" />
            </div>
            {isSidebarOpen && (
              <span className="font-bold text-lg text-slate-800 tracking-tight">HCPilot</span>
            )}
          </div>
        </div>

        {/* Toggle button */}
        <button
          type="button"
          title="Toggle sidebar"
          onClick={() => setIsSidebarOpen(!isSidebarOpen)}
          className="absolute -right-3 top-20 w-6 h-6 bg-white border border-slate-200 rounded-full flex items-center justify-center shadow-sm hover:bg-slate-50 transition-colors z-10"
        >
          <ChevronLeft className={`w-3.5 h-3.5 text-slate-500 transition-transform ${!isSidebarOpen ? 'rotate-180' : ''}`} />
        </button>

        {/* Navigation */}
        <nav className="flex-1 py-4 px-3 space-y-1 overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200 group ${
                  isActive
                    ? 'bg-teal-50 text-teal-700 font-medium shadow-sm'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <div className={`flex-shrink-0 ${isActive ? 'text-teal-600' : 'text-slate-400 group-hover:text-slate-600'}`}>
                    <item.icon className="w-5 h-5" />
                  </div>
                  {isSidebarOpen && <span className="text-sm">{item.label}</span>}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* User section */}
        <div className="p-3 border-t border-slate-100">
          {isSidebarOpen && user && (
            <div className="flex items-center gap-3 px-3 py-2 mb-2">
              <div className="w-9 h-9 rounded-full bg-gradient-to-br from-teal-400 to-emerald-500 flex items-center justify-center text-white text-sm font-semibold shadow-sm">
                {user.full_name?.split(' ').map((n: string) => n[0]).join('').slice(0, 2) || 'U'}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-slate-900 truncate">{user.full_name}</p>
                <p className="text-xs text-slate-500 truncate">{user.specialty || user.role}</p>
              </div>
            </div>
          )}
          <button
            type="button"
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-slate-500 hover:bg-red-50 hover:text-red-600 transition-all"
          >
            <LogOut className="w-5 h-5" />
            {isSidebarOpen && <span className="text-sm">Déconnexion</span>}
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="h-16 bg-white/80 backdrop-blur-sm border-b border-slate-200/80 flex items-center justify-between px-6 sticky top-0 z-10">
          <button
            type="button"
            title="Menu"
            onClick={() => setIsSidebarOpen(!isSidebarOpen)}
            className="lg:hidden p-2 rounded-xl hover:bg-slate-100 text-slate-600"
          >
            <Menu className="w-5 h-5" />
          </button>

          <div className="flex-1" />


          <div className="flex items-center gap-3">
            <button type="button" title="Notifications" className="relative p-2.5 rounded-xl hover:bg-slate-100 text-slate-500 transition-colors">
              <Bell className="w-5 h-5" />
              <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full" />
            </button>
            <div className="w-px h-8 bg-slate-200" />
            <div className="flex items-center gap-2 pl-2">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-teal-400 to-emerald-500 flex items-center justify-center text-white text-xs font-semibold">
                {user.full_name?.split(' ').map((n: string) => n[0]).join('').slice(0, 2) || 'U'}
              </div>
              <span className="text-sm font-medium text-slate-700 hidden sm:block">{user.full_name}</span>
            </div>
          </div>
        </header>

        {/* Content */}
        <main className="flex-1 overflow-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

export default DashboardLayout
