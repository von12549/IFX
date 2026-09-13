import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { userManagementApi } from '../api/userManagement'
import { platformApi } from '../api/platform'
import { useAuth } from '../contexts/AuthContext'
import type { UserProfileDto } from '../types/api'
import { Chip } from '../components/shared/Chip'
import { SortableHeader } from '../components/shared/SortableHeader'
import { TenantRequiredBanner } from '../components/shared/TenantRequiredBanner'
import { ExpandableCrossTenantSection } from '../components/shared/ExpandableCrossTenantSection'

type SortCol = 'displayName' | 'email' | 'roles' | 'roleGroups' | 'isActive'

export function UserManagementPage() {
  const { selectedTenantId, isGlobalUser } = useAuth()
  const [users, setUsers] = useState<UserProfileDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [sortCol, setSortCol] = useState<SortCol>('displayName')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const navigate = useNavigate()

  const load = () =>
    userManagementApi.getAll(1, 50)
      .then(r => setUsers(r.data?.data?.items ?? []))
      .catch(() => setError('Failed to load users'))

  useEffect(() => {
    Promise.resolve()
      .then(() => { setLoading(true); return load() })
      .finally(() => setLoading(false))
  }, [selectedTenantId])

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const sorted = [...users].sort((a, b) => {
    let v = 0
    if (sortCol === 'roles') v = a.roles.length - b.roles.length
    else if (sortCol === 'roleGroups') v = a.roleGroups.length - b.roleGroups.length
    else if (sortCol === 'isActive') v = Number(a.isActive) - Number(b.isActive)
    else v = (a[sortCol] ?? '').localeCompare(b[sortCol] ?? '')
    return sortDir === 'asc' ? v : -v
  })

  return (
    <div className="page">
      <div className="page-header">
        <h2>User Management</h2>
      </div>
      {isGlobalUser && !selectedTenantId && <TenantRequiredBanner />}
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <SortableHeader label="Display Name" col="displayName" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Email" col="email" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Roles" col="roles" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Role Groups" col="roleGroups" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Active" col="isActive" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
              </tr>
            </thead>
            <tbody>
              {sorted.map(u => (
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

      {isGlobalUser && (
        <ExpandableCrossTenantSection<UserProfileDto>
          label="Users in Other Tenants"
          fetchData={platformApi.getAllUsersAcrossTenants}
          columns={[
            { header: 'Display Name', render: u => u.displayName },
            { header: 'Email', render: u => u.email },
            { header: 'Active', render: u => <span className={`badge ${u.isActive ? 'badge-success' : 'badge-muted'}`}>{u.isActive ? 'Active' : 'Inactive'}</span> },
          ]}
          getKey={u => u.id}
        />
      )}
    </div>
  )
}
