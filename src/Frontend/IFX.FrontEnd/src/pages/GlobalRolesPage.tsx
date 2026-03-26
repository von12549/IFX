import { useEffect, useState } from 'react'
import { platformApi } from '../api/platform'
import type { GlobalRoleDto } from '../types/api'

export function GlobalRolesPage() {
  const [roles, setRoles] = useState<GlobalRoleDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    platformApi.getGlobalRoles()
      .then(r => setRoles(r.data?.data ?? []))
      .catch(() => setError('Failed to load global roles'))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="page">
      <div className="page-header">
        <h2>Global Roles</h2>
        <span className="badge badge-info">Read-only</span>
      </div>
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              {roles.map(r => (
                <tr key={r.id}>
                  <td>{r.name}</td>
                  <td className="text-muted">{r.description}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
