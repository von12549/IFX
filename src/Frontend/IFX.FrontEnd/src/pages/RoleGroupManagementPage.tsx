import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { roleGroupApi } from '../api/roleGroup'
import type { CreateRoleGroupRequest, RoleGroupDto } from '../types/api'
import { Modal } from '../components/shared/Modal'

export function RoleGroupManagementPage() {
  const [groups, setGroups] = useState<RoleGroupDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState<CreateRoleGroupRequest>({ name: '', description: '' })
  const [saving, setSaving] = useState(false)
  const navigate = useNavigate()

  const load = () => roleGroupApi.getAll().then(r => setGroups(r.data?.data ?? [])).catch(() => setError('Failed to load role groups'))

  useEffect(() => { load().finally(() => setLoading(false)) }, [])

  const handleCreate = async () => {
    setSaving(true)
    try { await roleGroupApi.create(form); await load(); setModal(false); setForm({ name: '', description: '' }) }
    catch (err: any) { setError(err.response?.data?.error || 'Failed to create') }
    finally { setSaving(false) }
  }

  return (
    <div className="page">
      <div className="page-header">
        <h2>RoleGroup Management</h2>
        <button className="btn btn-primary" onClick={() => setModal(true)}>+ Create Group</button>
      </div>
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead><tr><th>Name</th><th>Description</th><th>Roles</th></tr></thead>
            <tbody>
              {groups.map(g => (
                <tr key={g.id} className="clickable-row" onClick={() => navigate(`/rolegroups/${g.id}`)}>
                  <td>{g.name}</td>
                  <td className="text-muted">{g.description}</td>
                  <td>{g.roles.length}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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
        </Modal>
      )}
    </div>
  )
}
