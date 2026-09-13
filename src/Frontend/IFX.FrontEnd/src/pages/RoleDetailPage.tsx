import { apiErrorMessage } from '../api/errors'
import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { roleApi } from '../api/role'
import { permissionApi } from '../api/permission'
import type { PermissionDto, RoleDetailDto } from '../types/api'
import { Chip } from '../components/shared/Chip'
import { Modal } from '../components/shared/Modal'

export function RoleDetailPage() {
  const { roleId } = useParams<{ roleId: string }>()
  const navigate = useNavigate()
  const [role, setRole] = useState<RoleDetailDto | null>(null)
  const [allPerms, setAllPerms] = useState<PermissionDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState({ name: '', description: '', tenantId: '' })
  const [modal, setModal] = useState(false)
  const [selected, setSelected] = useState<string[]>([])
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)

  const load = () =>
    roleApi.getById(roleId!).then(r => {
      const data = r.data?.data
      setRole(data ?? null)
      setForm({ name: data?.name ?? '', description: data?.description ?? '', tenantId: data?.tenantId ?? '' })
    }).catch(() => setError('Role not found'))

  useEffect(() => {
    Promise.all([load(), permissionApi.getAll().then(r => setAllPerms(r.data?.data ?? []))])
      .finally(() => setLoading(false))
  }, [roleId])

  const handleSave = async () => {
    setSaving(true)
    try { await roleApi.update(roleId!, form); await load(); setEditing(false) }
    catch (err: unknown) { setError(apiErrorMessage(err, 'Failed to update')) }
    finally { setSaving(false) }
  }

  const removePermission = async (permId: string) => {
    await roleApi.removePermission(roleId!, permId); await load()
  }

  const handleAssign = async () => {
    setSaving(true)
    try { await roleApi.assignPermissions(roleId!, selected); await load(); setModal(false); setSelected([]) }
    finally { setSaving(false) }
  }

  const handleDelete = async () => {
    await roleApi.delete(roleId!); navigate('/roles')
  }

  if (loading) return <div className="loading-inline"><span className="spinner" /></div>
  if (error || !role) return <div className="alert alert-error">{error || 'Role not found'}</div>

  const assignable = allPerms
    .filter(p => p.scope === 'Tenant')
    .filter(p => !role.permissions.some(rp => rp.id === p.id))

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <button className="btn-back" onClick={() => navigate('/roles')}>← Roles</button>
          {editing
            ? <input className="inline-title-input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            : <h2>{role.name}</h2>}
        </div>
        <div className="btn-group">
          {editing ? (
            <>
              <button className="btn btn-ghost" onClick={() => setEditing(false)} disabled={saving}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
            </>
          ) : (
            <>
              <button className="btn btn-secondary" onClick={() => setEditing(true)}>Edit</button>
              <button className="btn btn-danger" onClick={() => setConfirmDelete(true)}>Delete</button>
            </>
          )}
        </div>
      </div>

      <div className="detail-card">
        <div className="form-group">
          <label>Description</label>
          {editing
            ? <input value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
            : <p className="field-value">{role.description || '—'}</p>}
        </div>

        <div className="detail-section">
          <div className="detail-section-header">
            <h3>Permissions</h3>
            <button className="btn btn-secondary btn-sm" onClick={() => { setModal(true); setSelected([]) }}>Assign Permissions</button>
          </div>
          <div className="chip-list">
            {role.permissions.length ? role.permissions.map(p => (
              <Chip key={p.id} label={p.name} onRemove={() => removePermission(p.id)} />
            )) : <span className="text-muted">No permissions assigned</span>}
          </div>
        </div>
      </div>

      {modal && (
        <Modal title="Assign Permissions" onClose={() => setModal(false)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setModal(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={handleAssign} disabled={saving || !selected.length}>{saving ? 'Assigning…' : 'Assign'}</button>
          </div>
        }>
          <div className="select-list">
            {assignable.map(p => (
              <label key={p.id} className="select-item">
                <input type="checkbox" checked={selected.includes(p.id)} onChange={() => setSelected(s => s.includes(p.id) ? s.filter(x => x !== p.id) : [...s, p.id])} />
                <div><div className="select-item-name">{p.name}</div><div className="select-item-desc">{p.description}</div></div>
              </label>
            ))}
            {assignable.length === 0 && <p className="text-muted">All permissions already assigned.</p>}
          </div>
        </Modal>
      )}

      {confirmDelete && (
        <Modal title="Delete Role" onClose={() => setConfirmDelete(false)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setConfirmDelete(false)}>Cancel</button>
            <button className="btn btn-danger" onClick={handleDelete}>Delete</button>
          </div>
        }>
          <p>Are you sure you want to delete <strong>{role.name}</strong>? This cannot be undone.</p>
        </Modal>
      )}
    </div>
  )
}
