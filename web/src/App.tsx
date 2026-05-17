import { BrowserRouter as Router, Routes, Route, Navigate, Outlet } from 'react-router-dom'

// Layouts
import DashboardLayout from './layouts/DashboardLayout'
import AuthLayout from './layouts/AuthLayout'

// Pages
import Dashboard from './pages/Dashboard'
import Login from './pages/Login'
import Register from './pages/Register'
import Patients from './pages/Patients'
import Visits from './pages/Visits'
import Stock from './pages/Stock'
import Invoices from './pages/Invoices'
import Reports from './pages/Reports'
import Settings from './pages/Settings'

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/auth" element={<AuthLayout />}>
          <Route path="login" element={<Login />} />
          <Route path="register" element={<Register />} />
        </Route>

        <Route path="/" element={<ProtectedRoute />}>
          <Route element={<DashboardLayout />}>
            <Route index element={<Dashboard />} />
            <Route path="patients" element={<Patients />} />
            <Route path="visits" element={<Visits />} />
            <Route path="stock" element={<Stock />} />
            <Route path="invoices" element={<Invoices />} />
            <Route path="reports" element={<Reports />} />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Route>
      </Routes>
    </Router>
  )
}

function ProtectedRoute() {
  const token = localStorage.getItem('auth_token')
  const user = localStorage.getItem('user')

  if (!token || !user) {
    return <Navigate to="/auth/login" replace />
  }

  return <Outlet />
}

export default App
