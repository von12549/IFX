import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { userManagementApi } from '../api/userManagement'
import { tenantApi } from '../api/tenant'
import type { UserProfileDto, TenantDto } from '../types/api'
import { Chip } from '../components/shared/Chip'
import { SortableHeader } from '../components/shared/SortableHeader'

type SortCol = 'displayName' | 'email' | 'roles' | 'roleGroups' | 'isActive'

export function UserManagementPage() {
  const [users, setUsers] = useState<UserProfileDto[]>([])
  const [tenants, setTenants] = useState<TenantDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [sortCol, setSortCol] = useState<SortCol>('displayName')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const [filterTenantId, setFilterTenantId] = useState<string>('')
  const navigate = useNavigate()

  const load = (tenantId?: string) =>
    userManagementApi.getAll(1, 50, tenantId || undefined)
      .then(r => setUsers(r.data?.data?.items ?? []))
      .catch(() => setError('Failed to load users'))

  useEffect(() => {
    Promise.all([
      load(),
      tenantApi.getAll().then(r => setTenants(r.data?.data ?? [])),
    ]).finally(() => setLoading(false))
  }, [])

  const handleFilterChange = (tenantId: string) => {
    setFilterTenantId(tenantId)
    load(tenantId || undefined)
  }

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
      {error && <div className="alert alert-error">{error}</div>}

      <div className="filter-bar">
        <label>Filter by Tenant:</label>
        <select value={filterTenantId} onChange={e => handleFilterChange(e.target.value)}>
          <option value="">— Select Tenant —</option>
          {tenants.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
        </select>
      </div>

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
    </div>
  )
}
