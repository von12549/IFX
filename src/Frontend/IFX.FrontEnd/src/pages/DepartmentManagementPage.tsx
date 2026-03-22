import { useEffect, useState } from 'react'
import { departmentApi } from '../api/department'
import { tenantApi } from '../api/tenant'
import type { CreateDepartmentRequest, DepartmentDto, TenantDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { SortableHeader } from '../components/shared/SortableHeader'

type SortCol = 'name' | 'description' | 'tenantName'

export function DepartmentManagementPage() {
  const [departments, setDepartments] = useState<DepartmentDto[]>([])
  const [tenants, setTenants] = useState<TenantDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(false)
  const [editDept, setEditDept] = useState<DepartmentDto | null>(null)
  const [form, setForm] = useState<CreateDepartmentRequest>({ name: '', description: '', tenantId: '' })
  const [saving, setSaving] = useState(false)
  const [sortCol, setSortCol] = useState<SortCol>('name')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const [filterTenantId, setFilterTenantId] = useState<string>('')

  const loadDepts = (tenantId?: string) =>
    departmentApi.getAll(tenantId || undefined)
      .then(r => setDepartments(r.data?.data ?? []))
      .catch(() => setError('Failed to load departments'))

  const loadTenants = () =>
    tenantApi.getAll().then(r => setTenants(r.data?.data ?? []))

  useEffect(() => {
    Promise.all([loadDepts(), loadTenants()]).finally(() => setLoading(false))
  }, [])

  const handleFilterChange = (tenantId: string) => {
    setFilterTenantId(tenantId)
    loadDepts(tenantId || undefined)
  }

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const openCreate = () => {
    setEditDept(null)
    setForm({ name: '', description: '', tenantId: tenants[0]?.id ?? '' })
    setModal(true)
  }

  const openEdit = (d: DepartmentDto) => {
    setEditDept(d)
    setForm({ name: d.name, description: d.description, tenantId: d.tenantId })
    setModal(true)
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (editDept) {
        await departmentApi.update(editDept.id, { name: form.name, description: form.description })
      } else {
        await departmentApi.create(form)
      }
      await loadDepts(filterTenantId || undefined)
      setModal(false)
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (d: DepartmentDto) => {
    if (!confirm(`Delete department "${d.name}"?`)) return
    try {
      await departmentApi.delete(d.id)
      await loadDepts(filterTenantId || undefined)
    } catch {
      setError('Failed to delete department')
    }
  }

  const sorted = [...departments].sort((a, b) => {
    const v = (a[sortCol] ?? '').localeCompare(b[sortCol] ?? '')
    return sortDir === 'asc' ? v : -v
  })

  return (
    <div className="page">
      <div className="page-header">
        <h2>Department Management</h2>
        <button className="btn btn-primary" onClick={openCreate} disabled={tenants.length === 0}>
          + Create Department
        </button>
      </div>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="filter-bar">
        <label>Filter by Tenant:</label>
        <select value={filterTenantId} onChange={e => handleFilterChange(e.target.value)}>
          <option value="">All Tenants</option>
          {tenants.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
        </select>
      </div>

      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <SortableHeader label="Name" col="name" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Description" col="description" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Tenant" col="tenantName" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {sorted.map(d => (
                <tr key={d.id}>
                  <td>{d.name}</td>
                  <td className="text-muted">{d.description}</td>
                  <td>{d.tenantName}</td>
                  <td>
                    <div className="btn-group">
                      <button className="btn btn-sm btn-ghost" onClick={() => openEdit(d)}>Edit</button>
                      <button className="btn btn-sm btn-danger" onClick={() => handleDelete(d)}>Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {modal && (
        <Modal
          title={editDept ? 'Edit Department' : 'Create Department'}
          onClose={() => setModal(false)}
          footer={
            <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
                {saving ? 'Saving…' : editDept ? 'Save' : 'Create'}
              </button>
            </div>
          }
        >
          <div className="form-group">
            <label>Name</label>
            <input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
          </div>
          <div className="form-group">
            <label>Description</label>
            <input value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
          </div>
          {!editDept && (
            <div className="form-group">
              <label>Tenant</label>
              <select value={form.tenantId} onChange={e => setForm(f => ({ ...f, tenantId: e.target.value }))}>
                {tenants.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
              </select>
            </div>
          )}
        </Modal>
      )}
    </div>
  )
}
