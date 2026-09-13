import { apiErrorMessage } from '../api/errors'
import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { permissionApi } from '../api/permission'
import { useAuth } from '../contexts/AuthContext'
import type { CreatePermissionRequest, PermissionDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { SortableHeader } from '../components/shared/SortableHeader'

type SortCol = 'name' | 'description'
type TabKey = 'tenant' | 'platform'

function sortPerms(perms: PermissionDto[], col: SortCol, dir: 'asc' | 'desc') {
  return [...perms].sort((a, b) => {
    const v = (a[col] ?? '').localeCompare(b[col] ?? '')
    return dir === 'asc' ? v : -v
  })
}

interface PermissionTableProps {
  perms: PermissionDto[]
  sortCol: SortCol
  sortDir: 'asc' | 'desc'
  onSort: (col: string) => void
  onEdit: (p: PermissionDto) => void
  onDelete: (id: string) => void
}

function PermissionTable({ perms, sortCol, sortDir, onSort, onEdit, onDelete }: PermissionTableProps) {
  const sorted = sortPerms(perms, sortCol, sortDir)
  return (
    <div className="table-wrapper">
      <table className="data-table">
        <thead>
          <tr>
            <SortableHeader label="Name" col="name" sortCol={sortCol} sortDir={sortDir} onSort={onSort} />
            <SortableHeader label="Description" col="description" sortCol={sortCol} sortDir={sortDir} onSort={onSort} />
            <th></th>
          </tr>
        </thead>
        <tbody>
          {sorted.map(p => (
            <tr key={p.id}>
              <td>{p.name}</td>
              <td className="text-muted">{p.description}</td>
              <td>
                <div className="btn-group">
                  <button className="btn btn-ghost btn-sm" onClick={() => onEdit(p)}>Edit</button>
                  <button className="btn btn-danger btn-sm" onClick={() => onDelete(p.id)}>Delete</button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function PermissionManagementPage() {
  const { isGlobalUser } = useAuth()
  const [searchParams, setSearchParams] = useSearchParams()
  const [perms, setPerms] = useState<PermissionDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [form, setForm] = useState<CreatePermissionRequest>({ name: '', description: '' })
  const [editId, setEditId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null)
  const [sortCol, setSortCol] = useState<SortCol>('name')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')

  const activeTab: TabKey = searchParams.get('tab') === 'platform' ? 'platform' : 'tenant'

  const load = () => permissionApi.getAll().then(r => setPerms(r.data?.data ?? [])).catch(() => setError('Failed to load permissions'))

  useEffect(() => { load().finally(() => setLoading(false)) }, [])

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const openEdit = (p: PermissionDto) => { setForm({ name: p.name, description: p.description }); setEditId(p.id); setModal('edit') }
  const openCreate = () => { setForm({ name: '', description: '' }); setEditId(null); setModal('create') }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (modal === 'create') await permissionApi.create(form)
      else if (editId) await permissionApi.update(editId, form)
      await load(); setModal(null)
    } catch (err: unknown) { setError(apiErrorMessage(err, 'Failed to save')) }
    finally { setSaving(false) }
  }

  const handleDelete = async (id: string) => {
    await permissionApi.delete(id); await load(); setConfirmDelete(null)
  }

  const tenantPerms = perms.filter(p => p.scope === 'Tenant')
  const platformPerms = perms.filter(p => p.scope === 'Platform')
  const visiblePerms = isGlobalUser ? (activeTab === 'platform' ? platformPerms : tenantPerms) : tenantPerms

  return (
    <div className="page">
      <div className="page-header">
        <h2>Permission Management</h2>
        <button className="btn btn-primary" onClick={openCreate}>+ Create Permission</button>
      </div>
      {error && <div className="alert alert-error">{error}</div>}

      {isGlobalUser && (
        <div className="tab-bar">
          <button
            className={`tab-btn${activeTab === 'tenant' ? ' active' : ''}`}
            onClick={() => setSearchParams({})}
          >
            Tenant Permissions
          </button>
          <button
            className={`tab-btn${activeTab === 'platform' ? ' active' : ''}`}
            onClick={() => setSearchParams({ tab: 'platform' })}
          >
            Platform Permissions
          </button>
        </div>
      )}

      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <PermissionTable
          perms={visiblePerms}
          sortCol={sortCol}
          sortDir={sortDir}
          onSort={toggleSort}
          onEdit={openEdit}
          onDelete={setConfirmDelete}
        />
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
