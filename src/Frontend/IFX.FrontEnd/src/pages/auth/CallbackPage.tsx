import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'

export function CallbackPage() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState('')

  useEffect(() => {
    const hash = window.location.hash.slice(1)
    const params = new URLSearchParams(hash)

    const errorParam = params.get('error')
    if (errorParam) {
      setError(params.get('error_description') || errorParam)
      return
    }

    const accessToken = params.get('access_token')
    const idToken = params.get('id_token') || ''
    const refreshToken = params.get('refresh_token') || ''
    const expiresIn = parseInt(params.get('expires_in') || '3600', 10)

    if (!accessToken) {
      setError('No access token received. Please try signing in again.')
      return
    }

    login({ accessToken, idToken, refreshToken, expiresIn })
      .then(() => navigate('/profile', { replace: true }))
      .catch(() => setError('Failed to load your profile. Please try again.'))
  }, [login, navigate])

  if (error) {
    return (
      <div className="auth-page">
        <div className="auth-card">
          <div className="alert alert-error">{error}</div>
          <a href="/login" className="btn btn-primary btn-full" style={{ marginTop: 16 }}>Back to Login</a>
        </div>
      </div>
    )
  }

  return (
    <div className="auth-page">
      <div className="auth-card" style={{ textAlign: 'center' }}>
        <span className="spinner" style={{ width: 40, height: 40 }} />
        <p style={{ marginTop: 16, color: 'var(--text-muted)' }}>Signing you in…</p>
      </div>
    </div>
  )
}
