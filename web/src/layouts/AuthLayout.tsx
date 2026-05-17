import { Navigate, Outlet } from 'react-router-dom'
import { Activity, Shield, MapPin, Clock } from 'lucide-react'

const AuthLayout = () => {
  const token = localStorage.getItem('auth_token')
  const user = localStorage.getItem('user')

  if (token && user) {
    return <Navigate to="/" replace />
  }

  return (
    <div className="min-h-screen flex">
      {/* Left panel - branding */}
      <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-teal-600 via-teal-700 to-emerald-800 relative overflow-hidden">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-20 left-20 w-72 h-72 bg-white rounded-full blur-3xl" />
          <div className="absolute bottom-20 right-20 w-96 h-96 bg-teal-300 rounded-full blur-3xl" />
        </div>

        <div className="relative z-10 flex flex-col justify-between p-12 w-full">
          <div>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-white/20 backdrop-blur-sm rounded-xl flex items-center justify-center">
                <Activity className="w-6 h-6 text-white" />
              </div>
              <span className="text-2xl font-bold text-white">HCPilot</span>
            </div>
          </div>

          <div className="space-y-8">
            <h2 className="text-4xl font-bold text-white leading-tight">
              Votre assistant pour les soins
              <br />
              <span className="text-teal-200">à domicile</span>
            </h2>
            <p className="text-teal-100 text-lg max-w-md">
              Gérez vos patients, optimisez vos tournées et simplifiez votre facturation en un seul endroit.
            </p>

            <div className="grid grid-cols-2 gap-4 max-w-md">
              {[
                { icon: Shield, label: 'Conforme HIPAA' },
                { icon: MapPin, label: 'Routes optimisées' },
                { icon: Clock, label: 'Gain de temps' },
                { icon: Activity, label: 'Suivi en direct' },
              ].map((item, i) => (
                <div key={i} className="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-xl p-3">
                  <item.icon className="w-5 h-5 text-teal-200" />
                  <span className="text-sm text-white font-medium">{item.label}</span>
                </div>
              ))}
            </div>
          </div>

          <p className="text-teal-200 text-sm">
            &copy; 2024 HCPilot. Tous droits réservés.
          </p>
        </div>
      </div>

      {/* Right panel - form */}
      <div className="flex-1 flex items-center justify-center p-6 bg-white">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden text-center mb-8">
            <div className="inline-flex items-center gap-2">
              <div className="w-8 h-8 bg-gradient-to-br from-teal-500 to-teal-600 rounded-lg flex items-center justify-center">
                <Activity className="w-5 h-5 text-white" />
              </div>
              <span className="text-xl font-bold text-slate-800">HCPilot</span>
            </div>
          </div>

          <Outlet />
        </div>
      </div>
    </div>
  )
}

export default AuthLayout
