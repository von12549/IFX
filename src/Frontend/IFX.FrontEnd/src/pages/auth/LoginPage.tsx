import { useState } from 'react'
import { Link } from 'react-router-dom'
import { authApi } from '../../api/auth'

export function LoginPage() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async () => {
    setLoading(true)
    setError('')
    try {
      const resp = await authApi.getAuthorizeUrl()
      const url = resp.data?.data?.authorizationUrl
      if (url) {
        window.location.href = url
      } else {
        setError('Failed to get authorization URL')
      }
    } catch {
      setError('Failed to connect to the server. Is the API running?')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-logo">
          <svg viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
            <polygon points="20,2 38,36 2,36" fill="none" stroke="#6366f1" strokeWidth="3" />
            <line x1="20" y1="14" x2="20" y2="28" stroke="#6366f1" strokeWidth="2.5" />
            <line x1="13" y1="28" x2="27" y2="28" stroke="#6366f1" strokeWidth="2.5" />
          </svg>
          <h1>IFX</h1>
        </div>
        <p className="auth-subtitle">Sign in to your account</p>
        {error && <div className="alert alert-error">{error}</div>}
        <button className="btn btn-primary btn-full" onClick={handleLogin} disabled={loading}>
          {loading ? 'Redirecting...' : 'Sign in with IFX Cognito'}
        </button>
        <p className="auth-link">
          Don't have an account? <Link to="/register">Register</Link>
        </p>
      </div>
    </div>
  )
}
