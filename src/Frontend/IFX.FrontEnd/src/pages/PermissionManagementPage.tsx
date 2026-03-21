import { useEffect, useState } from 'react'
import { permissionApi } from '../api/permission'
import type { CreatePermissionRequest, PermissionDto } from '../types/api'
import { Modal } from '../components/shared/Modal'

export function PermissionManagementPage() {
  const [perms, setPerms] = useState<PermissionDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [form, setForm] = useState<CreatePermissionRequest>({ name: '', description: '' })
  const [editId, setEditId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null)

  const load = () => permissionApi.getAll().then(r => setPerms(r.data?.data ?? [])).catch(() => setError('Failed to load permissions'))

  useEffect(() => { load().finally(() => setLoading(false)) }, [])

  const openEdit = (p: PermissionDto) => { setForm({ name: p.name, description: p.description }); setEditId(p.id); setModal('edit') }
  const openCreate = () => { setForm({ name: '', description: '' }); setEditId(null); setModal('create') }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (modal === 'create') await permissionApi.create(form)
      else if (editId) await permissionApi.update(editId, form)
      await load(); setModal(null)
    } catch (err: any) { setError(err.response?.data?.error || 'Failed to save') }
    finally { setSaving(false) }
  }

  const handleDelete = async (id: string) => {
    await permissionApi.delete(id); await load(); setConfirmDelete(null)
  }

  return (
    <div className="page">
      <div className="page-header">
        <h2>Permission Management</h2>
        <button className="btn btn-primary" onClick={openCreate}>+ Create Permission</button>
      </div>
      {error && <div className="alert alert-error">{error}</div>}
      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead><tr><th>Name</th><th>Description</th><th></th></tr></thead>
            <tbody>
              {perms.map(p => (
                <tr key={p.id}>
                  <td>{p.name}</td>
                  <td className="text-muted">{p.description}</td>
                  <td>
                    <div className="btn-group">
                      <button className="btn btn-ghost btn-sm" onClick={() => openEdit(p)}>Edit</button>
                      <button className="btn btn-danger btn-sm" onClick={() => setConfirmDelete(p.id)}>Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {modal && (
        <Modal title={modal === 'create' ? 'Create Permission' : 'Edit Permission'} onClose={() => setModal(null)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setModal(null)}>Cancel</button>
            <button className="btn btn-primary" onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
          </div>
        }>
          <div className="form-group"><label>Name</label><input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
          <div className="form-group"><label>Description</label><input value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} /></div>
        </Modal>
      )}

      {confirmDelete && (
        <Modal title="Delete Permission" onClose={() => setConfirmDelete(null)} footer={
          <div className="btn-group">
            <button className="btn btn-ghost" onClick={() => setConfirmDelete(null)}>Cancel</button>
            <button className="btn btn-danger" onClick={() => handleDelete(confirmDelete)}>Delete</button>
          </div>
        }>
          <p>Are you sure you want to delete this permission? This cannot be undone.</p>
        </Modal>
      )}
    </div>
  )
}
