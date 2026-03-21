import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { userApi } from '../api/user'
import { Chip } from '../components/shared/Chip'

export function UserProfilePage() {
  const { user, refreshUser } = useAuth()
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState({ firstName: '', lastName: '', phoneNumber: '', email: '' })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  if (!user) return null

  const initials = [user.firstName?.[0], user.lastName?.[0]].filter(Boolean).join('').toUpperCase() || '?'

  const startEdit = () => {
    setForm({ firstName: user.firstName, lastName: user.lastName, phoneNumber: user.phoneNumber, email: user.email })
    setEditing(true)
    setError('')
    setSuccess('')
  }

  const handleSave = async () => {
    setLoading(true); setError('')
    try {
      await userApi.updateProfile(form)
      await refreshUser()
      setEditing(false)
      setSuccess('Profile updated successfully.')
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to update profile')
    } finally { setLoading(false) }
  }

  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(f => ({ ...f, [k]: e.target.value }))

  return (
    <div className="page">
      <div className="page-header">
        <h2>My Profile</h2>
        {!editing
          ? <button className="btn btn-secondary" onClick={startEdit}>Edit</button>
          : <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setEditing(false)} disabled={loading}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={loading}>{loading ? 'Saving…' : 'Save'}</button>
            </div>
        }
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {success && <div className="alert alert-success">{success}</div>}

      <div className="profile-card">
        <div className="profile-avatar">{initials}</div>
        <div className="profile-fields">
          {editing ? (
            <>
              <div className="form-row">
                <div className="form-group">
                  <label>First Name</label>
                  <input value={form.firstName} onChange={set('firstName')} />
                </div>
                <div className="form-group">
                  <label>Last Name</label>
                  <input value={form.lastName} onChange={set('lastName')} />
                </div>
              </div>
              <div className="form-group">
                <label>Email</label>
                <input type="email" value={form.email} onChange={set('email')} />
              </div>
              <div className="form-group">
                <label>Phone Number</label>
                <input value={form.phoneNumber} onChange={set('phoneNumber')} />
              </div>
            </>
          ) : (
            <div className="profile-view">
              <Field label="Display Name" value={user.displayName} />
              <Field label="First Name" value={user.firstName} />
              <Field label="Last Name" value={user.lastName} />
              <Field label="Email" value={user.email} />
              <Field label="Phone" value={user.phoneNumber || '—'} />
              <Field label="Email Verified" value={user.emailVerified ? 'Yes' : 'No'} />
              <Field label="Active" value={user.isActive ? 'Yes' : 'No'} />
              <Field label="Member Since" value={new Date(user.createdAt).toLocaleDateString()} />
            </div>
          )}

          <div className="profile-section">
            <label>Roles</label>
            <div className="chip-list">
              {user.roles.length ? user.roles.map(r => <Chip key={r.id} label={r.name} />) : <span className="text-muted">None</span>}
            </div>
          </div>
          <div className="profile-section">
            <label>Role Groups</label>
            <div className="chip-list">
              {user.roleGroups.length ? user.roleGroups.map(g => <Chip key={g.id} label={g.name} />) : <span className="text-muted">None</span>}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="field-row">
      <span className="field-label">{label}</span>
      <span className="field-value">{value}</span>
    </div>
  )
}
