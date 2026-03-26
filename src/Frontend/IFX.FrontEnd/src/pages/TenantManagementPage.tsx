import { useEffect, useState } from 'react'
import { tenantApi } from '../api/tenant'
import { useAuth } from '../contexts/AuthContext'
import type { CreateTenantRequest, TenantDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { SortableHeader } from '../components/shared/SortableHeader'
import { TenantRequiredBanner } from '../components/shared/TenantRequiredBanner'
import { ExpandableCrossTenantSection } from '../components/shared/ExpandableCrossTenantSection'

type SortCol = 'name' | 'description'

export function TenantManagementPage() {
  const { isGlobalUser, selectedTenantId, user } = useAuth()
  const [tenants, setTenants] = useState<TenantDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(false)
  const [editTenant, setEditTenant] = useState<TenantDto | null>(null)
  const [form, setForm] = useState<CreateTenantRequest>({ name: '', description: '' })
  const [saving, setSaving] = useState(false)
  const [sortCol, setSortCol] = useState<SortCol>('name')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')

  const load = () =>
    tenantApi.getAll().then(r => setTenants(r.data?.data ?? [])).catch(() => setError('Failed to load tenants'))

  useEffect(() => { load().finally(() => setLoading(false)) }, [])

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const openCreate = () => {
    setEditTenant(null)
    setForm({ name: '', description: '' })
    setModal(true)
  }

  const openEdit = (t: TenantDto) => {
    setEditTenant(t)
    setForm({ name: t.name, description: t.description })
    setModal(true)
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (editTenant) {
        await tenantApi.update(editTenant.id, form)
      } else {
        await tenantApi.create(form)
      }
      await load()
      setModal(false)
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (t: TenantDto) => {
    if (!confirm(`Delete tenant "${t.name}"?`)) return
    try {
      await tenantApi.delete(t.id)
      await load()
    } catch {
      setError('Failed to delete tenant')
    }
  }

  // Tenant-only users see only their own tenants
  const ownTenantIds = new Set(user?.tenants.map(t => t.id) ?? [])
  const primaryTenants = isGlobalUser
    ? (selectedTenantId ? tenants.filter(t => t.id === selectedTenantId) : tenants)
    : tenants.filter(t => ownTenantIds.has(t.id))
  const otherTenants = isGlobalUser && selectedTenantId
    ? tenants.filter(t => t.id !== selectedTenantId)
    : []

  const sorted = [...primaryTenants].sort((a, b) => {
    const v = (a[sortCol] ?? '').localeCompare(b[sortCol] ?? '')
    return sortDir === 'asc' ? v : -v
  })

  return (
    <div className="page">
      <div className="page-header">
        <h2>Tenant Management</h2>
        {isGlobalUser && (
          <button className="btn btn-primary" onClick={openCreate}>+ Create Tenant</button>
        )}
        {!isGlobalUser && (
          <span className="badge badge-info">You can view your tenant details here.</span>
        )}
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
                {isGlobalUser && <th>Actions</th>}
              </tr>
            </thead>
            <tbody>
              {sorted.map(t => (
                <tr key={t.id}>
                  <td>{t.name}</td>
                  <td className="text-muted">{t.description}</td>
                  {isGlobalUser && (
                    <td>
                      <div className="btn-group">
                        <button className="btn btn-sm btn-ghost" onClick={() => openEdit(t)}>Edit</button>
                        <button className="btn btn-sm btn-danger" onClick={() => handleDelete(t)}>Delete</button>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {isGlobalUser && otherTenants.length > 0 && (
        <ExpandableCrossTenantSection<TenantDto>
          label="Other Tenants"
          fetchData={() => Promise.resolve({
            data: {
              data: {
                tenants: [{ tenantId: 'all', tenantName: 'All Tenants', items: otherTenants }]
              }
            }
          })}
          columns={[
            { header: 'Name', render: t => t.name },
            { header: 'Description', render: t => <span className="text-muted">{t.description}</span> },
            {
              header: 'Actions', render: t => (
                <div className="btn-group">
                  <button className="btn btn-sm btn-ghost" onClick={() => openEdit(t)}>Edit</button>
                  <button className="btn btn-sm btn-danger" onClick={() => handleDelete(t)}>Delete</button>
                </div>
              )
            },
          ]}
          getKey={t => t.id}
        />
      )}

      {modal && (
        <Modal
          title={editTenant ? 'Edit Tenant' : 'Create Tenant'}
          onClose={() => setModal(false)}
          footer={
            <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
                {saving ? 'Saving…' : editTenant ? 'Save' : 'Create'}
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
        </Modal>
      )}
    </div>
  )
}
