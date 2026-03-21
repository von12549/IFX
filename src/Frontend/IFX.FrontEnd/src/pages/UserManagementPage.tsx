import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { userManagementApi } from '../api/userManagement'
import type { UserProfileDto } from '../types/api'
import { Chip } from '../components/shared/Chip'

export function UserManagementPage() {
  const [users, setUsers] = useState<UserProfileDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const navigate = useNavigate()

  useEffect(() => {
    userManagementApi.getAll()
      .then(r => setUsers(r.data?.data?.items ?? []))
      .catch(() => setError('Failed to load users'))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="page">
      <div className="page-header">
        <h2>User Management</h2>
      </div>
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <th>Display Name</th>
                <th>Email</th>
                <th>Roles</th>
                <th>Role Groups</th>
                <th>Active</th>
              </tr>
            </thead>
            <tbody>
              {users.map(u => (
                <tr key={u.id} className="clickable-row" onClick={() => navigate(`/users/${u.id}`)}>
                  <td>{u.displayName}</td>
                  <td>{u.email}</td>
                  <td>
                    <div className="chip-list">
                      {u.roles.map(r => <Chip key={r.id} label={r.name} />)}
                    </div>
                  </td>
                  <td>
                    <div className="chip-list">
                      {u.roleGroups.map(g => <Chip key={g.id} label={g.name} />)}
                    </div>
                  </td>
                  <td><span className={`badge ${u.isActive ? 'badge-success' : 'badge-muted'}`}>{u.isActive ? 'Active' : 'Inactive'}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
