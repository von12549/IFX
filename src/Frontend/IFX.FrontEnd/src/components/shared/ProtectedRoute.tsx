import { Navigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth()

  if (isLoading) {
    return <div className="loading-screen"><span className="spinner" /></div>
  }

  return isAuthenticated ? <>{children}</> : <Navigate to="/login" replace />
}
