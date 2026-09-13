import { apiErrorMessage } from '../api/errors'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { roleGroupApi } from '../api/roleGroup'
import { tenantApi } from '../api/tenant'
import { platformApi } from '../api/platform'
import { useAuth } from '../contexts/AuthContext'
import type { CreateRoleGroupRequest, RoleGroupDto, TenantDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { SortableHeader } from '../components/shared/SortableHeader'
import { TenantRequiredBanner } from '../components/shared/TenantRequiredBanner'
import { ExpandableCrossTenantSection } from '../components/shared/ExpandableCrossTenantSection'

type SortCol = 'name' | 'description' | 'tenantName' | 'roles'

export function RoleGroupManagementPage() {
  const { selectedTenantId, isGlobalUser } = useAuth()
  const [groups, setGroups] = useState<RoleGroupDto[]>([])
  const [tenants, setTenants] = useState<TenantDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState<CreateRoleGroupRequest>({ name: '', description: '', tenantId: '' })
  const [saving, setSaving] = useState(false)
  const [sortCol, setSortCol] = useState<SortCol>('name')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const navigate = useNavigate()

  const load = () => roleGroupApi.getAll().then(r => setGroups(r.data?.data ?? [])).catch(() => setError('Failed to load role groups'))

  useEffect(() => {
    tenantApi.getAll().then(r => setTenants(r.data?.data ?? []))
  }, [])

  useEffect(() => {
    setLoading(true)
    load().finally(() => setLoading(false))
  }, [selectedTenantId])

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const openCreate = () => {
    setForm({ name: '', description: '', tenantId: selectedTenantId ?? tenants[0]?.id ?? '' })
    setModal(true)
  }

  const handleCreate = async () => {
    setSaving(true)
    try { await roleGroupApi.create(form); await load(); setModal(false) }
    catch (err: unknown) { setError(apiErrorMessage(err, 'Failed to create')) }
    finally { setSaving(false) }
  }

  const sorted = [...groups].sort((a, b) => {
    let v = 0
    if (sortCol === 'roles') v = a.roles.length - b.roles.length
    else v = (a[sortCol] ?? '').localeCompare(b[sortCol] ?? '')
    return sortDir === 'asc' ? v : -v
  })

  return (
    <div className="page">
      <div className="page-header">
        <h2>RoleGroup Management</h2>
        <button className="btn btn-primary" onClick={openCreate}>+ Create Group</button>
      </div>
      {isGlobalUser && !selectedTenantId && <TenantRequiredBanner />}
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <SortableHeader label="Name" col="name" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Description" col="description" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Tenant" col="tenantName" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Roles" col="roles" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
              </tr>
            </thead>
            <tbody>
              {sorted.map(g => (
                <tr key={g.id} className="clickable-row" onClick={() => navigate(`/rolegroups/${g.id}`)}>
                  <td>{g.name}</td>
                  <td className="text-muted">{g.description}</td>
                  <td className="text-muted">{g.tenantName}</td>
                  <td>{g.roles.length}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {isGlobalUser && (
        <ExpandableCrossTenantSection<RoleGroupDto>
          label="Role Groups in Other Tenants"
          fetchData={platformApi.getAllRoleGroupsAcrossTenants}
          columns={[
            { header: 'Name', render: g => g.name },
            { header: 'Description', render: g => <span className="text-muted">{g.description}</span> },
            { header: 'Roles', render: g => g.roles.length },
          ]}
          getKey={g => g.id}
        />
      )}

      {modal && (
        <Modal title="Create Role Group" onClose={() => setModal(false)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setModal(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={handleCreate} disabled={saving}>{saving ? 'Creating…' : 'Create'}</button>
          </div>
        }>
          <div className="form-group"><label>Name</label><input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
          <div className="form-group"><label>Description</label><input value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} /></div>
          <div className="form-group">
            <label>Tenant</label>
            <select value={form.tenantId} onChange={e => setForm(f => ({ ...f, tenantId: e.target.value }))}>
              {tenants.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </div>
        </Modal>
      )}
    </div>
  )
}
