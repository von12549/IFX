import { Outlet } from 'react-router-dom'
import { Header } from './Header'
import { Sidebar } from './Sidebar'
import { Toaster } from '../shared/Toaster'

export function AppLayout() {
  return (
    <div className="app-shell">
      <Header />
      <div className="app-body">
        <Sidebar />
        <main className="main-content">
          <Outlet />
        </main>
      </div>
      <Toaster />
    </div>
  )
}
