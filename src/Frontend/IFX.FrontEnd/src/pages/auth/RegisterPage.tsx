import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { authApi } from '../../api/auth'

export function RegisterPage() {
  const navigate = useNavigate()
  const [step, setStep] = useState<'register' | 'confirm'>('register')
  const [form, setForm] = useState({ email: '', password: '', confirmPassword: '', firstName: '', lastName: '' })
  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(f => ({ ...f, [k]: e.target.value }))

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    if (form.password !== form.confirmPassword) { setError('Passwords do not match'); return }
    setLoading(true); setError('')
    try {
      await authApi.register({ email: form.email, password: form.password, firstName: form.firstName, lastName: form.lastName })
      setStep('confirm')
      setSuccess('Account created! Please check your email for the confirmation code.')
    } catch (err: any) {
      setError(err.response?.data?.error || 'Registration failed')
    } finally { setLoading(false) }
  }

  const handleConfirm = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError('')
    try {
      await authApi.confirm({ email: form.email, confirmationCode: code })
      navigate('/login')
    } catch (err: any) {
      setError(err.response?.data?.error || 'Confirmation failed')
    } finally { setLoading(false) }
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
        <p className="auth-subtitle">{step === 'register' ? 'Create your account' : 'Confirm your email'}</p>
        {error && <div className="alert alert-error">{error}</div>}
        {success && <div className="alert alert-success">{success}</div>}

        {step === 'register' ? (
          <form onSubmit={handleRegister} className="auth-form">
            <div className="form-row">
              <div className="form-group">
                <label>First Name</label>
                <input required value={form.firstName} onChange={set('firstName')} />
              </div>
              <div className="form-group">
                <label>Last Name</label>
                <input required value={form.lastName} onChange={set('lastName')} />
              </div>
            </div>
            <div className="form-group">
              <label>Email</label>
              <input type="email" required value={form.email} onChange={set('email')} />
            </div>
            <div className="form-group">
              <label>Password</label>
              <input type="password" required value={form.password} onChange={set('password')} />
            </div>
            <div className="form-group">
              <label>Confirm Password</label>
              <input type="password" required value={form.confirmPassword} onChange={set('confirmPassword')} />
            </div>
            <button className="btn btn-primary btn-full" disabled={loading}>
              {loading ? 'Creating account...' : 'Register'}
            </button>
          </form>
        ) : (
          <form onSubmit={handleConfirm} className="auth-form">
            <div className="form-group">
              <label>Confirmation Code</label>
              <input required value={code} onChange={e => setCode(e.target.value)} placeholder="Enter code from email" />
            </div>
            <button className="btn btn-primary btn-full" disabled={loading}>
              {loading ? 'Confirming...' : 'Confirm'}
            </button>
          </form>
        )}

        <p className="auth-link">Already have an account? <Link to="/login">Sign in</Link></p>
      </div>
    </div>
  )
}
