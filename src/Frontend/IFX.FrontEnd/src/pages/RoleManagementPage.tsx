import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { roleApi } from '../api/role'
import type { CreateRoleRequest, RoleDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { SortableHeader } from '../components/shared/SortableHeader'

type SortCol = 'name' | 'description'

export function RoleManagementPage() {
  const [roles, setRoles] = useState<RoleDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState<CreateRoleRequest>({ name: '', description: '' })
  const [saving, setSaving] = useState(false)
  const [sortCol, setSortCol] = useState<SortCol>('name')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const navigate = useNavigate()

  const load = () => roleApi.getAll().then(r => setRoles(r.data?.data ?? [])).catch(() => setError('Failed to load roles'))

  useEffect(() => { load().finally(() => setLoading(false)) }, [])

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const handleCreate = async () => {
    setSaving(true)
    try { await roleApi.create(form); await load(); setModal(false); setForm({ name: '', description: '' }) }
    catch (err: any) { setError(err.response?.data?.error || 'Failed to create role') }
    finally { setSaving(false) }
  }

  const sorted = [...roles].sort((a, b) => {
    const v = (a[sortCol] ?? '').localeCompare(b[sortCol] ?? '')
    return sortDir === 'asc' ? v : -v
  })

  return (
    <div className="page">
      <div className="page-header">
        <h2>Role Management</h2>
        <button className="btn btn-primary" onClick={() => setModal(true)}>+ Create Role</button>
      </div>
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <SortableHeader label="Name" col="name" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Description" col="description" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
              </tr>
            </thead>
            <tbody>
              {sorted.map(r => (
                <tr key={r.id} className="clickable-row" onClick={() => navigate(`/roles/${r.id}`)}>
                  <td>{r.name}</td>
                  <td className="text-muted">{r.description}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {modal && (
        <Modal title="Create Role" onClose={() => setModal(false)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setModal(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={handleCreate} disabled={saving}>{saving ? 'Creating…' : 'Create'}</button>
          </div>
        }>
          <div className="form-group"><label>Name</label><input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
          <div className="form-group"><label>Description</label><input value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} /></div>
        </Modal>
      )}
    </div>
  )
}
