import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { roleGroupApi } from '../api/roleGroup'
import { roleApi } from '../api/role'
import type { RoleDto, RoleGroupDto } from '../types/api'
import { Chip } from '../components/shared/Chip'
import { Modal } from '../components/shared/Modal'

export function RoleGroupDetailPage() {
  const { roleGroupId } = useParams<{ roleGroupId: string }>()
  const navigate = useNavigate()
  const [group, setGroup] = useState<RoleGroupDto | null>(null)
  const [allRoles, setAllRoles] = useState<RoleDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState({ name: '', description: '' })
  const [modal, setModal] = useState(false)
  const [selected, setSelected] = useState<string[]>([])
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)

  const load = () =>
    roleGroupApi.getAll()
      .then(r => {
        const found = (r.data?.data ?? []).find((g: RoleGroupDto) => g.id === roleGroupId) ?? null
        setGroup(found)
        setForm({ name: found?.name ?? '', description: found?.description ?? '' })
      })
      .catch(() => setError('Role group not found'))

  useEffect(() => {
    Promise.all([load(), roleApi.getAll().then(r => setAllRoles(r.data?.data ?? []))])
      .finally(() => setLoading(false))
  }, [roleGroupId])

  const handleSave = async () => {
    setSaving(true)
    try { await roleGroupApi.update(roleGroupId!, form); await load(); setEditing(false) }
    catch (err: any) { setError(err.response?.data?.error || 'Failed to update') }
    finally { setSaving(false) }
  }

  const removeRole = async (roleId: string) => {
    await roleGroupApi.removeRole(roleGroupId!, roleId); await load()
  }

  const handleAssign = async () => {
    setSaving(true)
    try { await roleGroupApi.assignRoles(roleGroupId!, selected); await load(); setModal(false); setSelected([]) }
    finally { setSaving(false) }
  }

  const handleDelete = async () => {
    await roleGroupApi.delete(roleGroupId!); navigate('/rolegroups')
  }

  if (loading) return <div className="loading-inline"><span className="spinner" /></div>
  if (error || !group) return <div className="alert alert-error">{error || 'Role group not found'}</div>

  const assignable = allRoles.filter(r => !group.roles.some(gr => gr.id === r.id))

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <button className="btn-back" onClick={() => navigate('/rolegroups')}>← Role Groups</button>
          {editing
            ? <input className="inline-title-input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            : <h2>{group.name}</h2>}
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
            : <p className="field-value">{group.description || '—'}</p>}
        </div>

        <div className="detail-section">
          <div className="detail-section-header">
            <h3>Roles</h3>
            <button className="btn btn-secondary btn-sm" onClick={() => { setModal(true); setSelected([]) }}>Assign Roles</button>
          </div>
          <div className="chip-list">
            {group.roles.length ? group.roles.map(r => (
              <Chip key={r.id} label={r.name} onRemove={() => removeRole(r.id)} />
            )) : <span className="text-muted">No roles in this group</span>}
          </div>
        </div>
      </div>

      {modal && (
        <Modal title="Assign Roles" onClose={() => setModal(false)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setModal(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={handleAssign} disabled={saving || !selected.length}>{saving ? 'Assigning…' : 'Assign'}</button>
          </div>
        }>
          <div className="select-list">
            {assignable.map(r => (
              <label key={r.id} className="select-item">
                <input type="checkbox" checked={selected.includes(r.id)} onChange={() => setSelected(s => s.includes(r.id) ? s.filter(x => x !== r.id) : [...s, r.id])} />
                <div><div className="select-item-name">{r.name}</div><div className="select-item-desc">{r.description}</div></div>
              </label>
            ))}
            {assignable.length === 0 && <p className="text-muted">All roles already assigned.</p>}
          </div>
        </Modal>
      )}

      {confirmDelete && (
        <Modal title="Delete Role Group" onClose={() => setConfirmDelete(false)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setConfirmDelete(false)}>Cancel</button>
            <button className="btn btn-danger" onClick={handleDelete}>Delete</button>
          </div>
        }>
          <p>Are you sure you want to delete <strong>{group.name}</strong>? This cannot be undone.</p>
        </Modal>
      )}
    </div>
  )
}
