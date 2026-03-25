import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { policyApi } from '../api/policy'
import type { PolicyDefinitionDto, TemplateDto, PolicyConditionDto } from '../types/api'
import { Modal } from '../components/shared/Modal'

type ModalMode = 'create' | 'edit' | null

interface PolicyForm {
  name: string
  description: string
  resourceType: string
  action: string
  conditions: PolicyConditionDto[]
}

const emptyForm: PolicyForm = { name: '', description: '', resourceType: '', action: '', conditions: [] }

export function PolicyManagementPage() {
  const { selectedTenantId } = useAuth()
  const [policies, setPolicies] = useState<PolicyDefinitionDto[]>([])
  const [templates, setTemplates] = useState<TemplateDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<ModalMode>(null)
  const [form, setForm] = useState<PolicyForm>(emptyForm)
  const [editId, setEditId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState<PolicyDefinitionDto | null>(null)

  const load = () =>
    Promise.all([
      policyApi.getAll().then(r => setPolicies(r.data?.data ?? [])),
      policyApi.getTemplates().then(r => setTemplates(r.data?.data ?? [])),
    ]).catch(() => setError('Failed to load policies'))

  useEffect(() => { setLoading(true); load().finally(() => setLoading(false)) }, [selectedTenantId])

  const openCreate = () => { setForm(emptyForm); setEditId(null); setModal('create') }

  const openEdit = (p: PolicyDefinitionDto) => {
    setForm({ name: p.name, description: p.description ?? '', resourceType: p.resourceType, action: p.action, conditions: p.conditions })
    setEditId(p.id)
    setModal('edit')
  }

  const openOverride = (p: PolicyDefinitionDto) => {
    setForm({ name: '', description: '', resourceType: p.resourceType, action: p.action, conditions: p.conditions })
    setEditId(null)
    setModal('create')
  }

  const toggleCondition = (templateName: string) => {
    setForm(f => {
      const exists = f.conditions.some(c => c.templateName === templateName)
      const conditions = exists
        ? f.conditions.filter(c => c.templateName !== templateName)
        : [...f.conditions, { templateName, parameters: null }]
      return { ...f, conditions }
    })
  }

  const handleSave = async () => {
    if (!form.name.trim()) { setError('Name is required.'); return }
    if (form.conditions.length === 0) { setError('At least one condition is required.'); return }
    setSaving(true)
    setError('')
    try {
      if (modal === 'create') {
        await policyApi.create({ name: form.name, description: form.description || null, resourceType: form.resourceType, action: form.action, conditions: form.conditions })
      } else if (editId) {
        await policyApi.update(editId, { name: form.name, description: form.description || null, conditions: form.conditions })
      }
      await load()
      setModal(null)
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (!confirmDelete?.id) return
    try {
      await policyApi.delete(confirmDelete.id)
      await load()
    } catch {
      setError('Failed to delete policy')
    } finally {
      setConfirmDelete(null)
    }
  }

  return (
    <div className="page">
      <div className="page-header">
        <h2>Policy Management</h2>
        <button className="btn btn-primary" onClick={openCreate}>+ Create Policy</button>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {loading ? (
        <div className="loading-inline"><span className="spinner" /></div>
      ) : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Resource Type</th>
                <th>Action</th>
                <th>Conditions</th>
                <th>Source</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {policies.map((p, i) => (
                <tr key={p.id ?? `default-${i}`}>
                  <td>{p.name}</td>
                  <td>{p.resourceType}</td>
                  <td>{p.action}</td>
                  <td>
                    <div className="chip-list">
                      {p.conditions.map(c => (
                        <span key={c.templateName} className="chip">{c.templateName}</span>
                      ))}
                    </div>
                  </td>
                  <td>
                    {p.isPlatformDefault
                      ? <span className="badge badge-info">Platform Default</span>
                      : <span className="badge badge-success">Tenant Override</span>}
                  </td>
                  <td>
                    <div className="btn-group">
                      {p.isPlatformDefault ? (
                        <button className="btn btn-ghost btn-sm" onClick={() => openOverride(p)}>Override</button>
                      ) : (
                        <>
                          <button className="btn btn-ghost btn-sm" onClick={() => openEdit(p)}>Edit</button>
                          <button className="btn btn-danger btn-sm" onClick={() => setConfirmDelete(p)}>Delete</button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {policies.length === 0 && (
                <tr><td colSpan={6} className="text-muted text-center">No policies defined for this tenant.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {modal && (
        <Modal
          title={modal === 'create' ? 'Create Policy' : 'Edit Policy'}
          onClose={() => setModal(null)}
          footer={
            <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setModal(null)}>Cancel</button>
              <button
                className="btn btn-primary"
                onClick={handleSave}
                disabled={saving || form.conditions.length === 0}
              >
                {saving ? 'Saving…' : 'Save'}
              </button>
            </div>
          }
        >
          <div className="form-group">
            <label>Name</label>
            <input
              value={form.name}
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
              placeholder="e.g. Read Own Profile"
            />
          </div>
          <div className="form-group">
            <label>Description <span className="text-muted">(optional)</span></label>
            <input
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
              placeholder="e.g. Allows users to read their own profile."
            />
          </div>
          {modal === 'create' && (
            <>
              <div className="form-group">
                <label>Resource Type</label>
                <input
                  value={form.resourceType}
                  onChange={e => setForm(f => ({ ...f, resourceType: e.target.value }))}
                  placeholder="e.g. user, document"
                />
              </div>
              <div className="form-group">
                <label>Action</label>
                <input
                  value={form.action}
                  onChange={e => setForm(f => ({ ...f, action: e.target.value }))}
                  placeholder="e.g. read, edit, delete"
                />
              </div>
            </>
          )}
          <div className="form-group">
            <label>Conditions</label>
            <div className="checkbox-list">
              {templates.map(t => (
                <label key={t.name} className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={form.conditions.some(c => c.templateName === t.name)}
                    onChange={() => toggleCondition(t.name)}
                  />
                  <span><strong>{t.name}</strong> — {t.description}</span>
                </label>
              ))}
            </div>
            {form.conditions.length === 0 && (
              <p className="field-hint text-warning">Select at least one condition.</p>
            )}
          </div>
        </Modal>
      )}

      {confirmDelete && (
        <Modal
          title="Delete Policy"
          onClose={() => setConfirmDelete(null)}
          footer={
            <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setConfirmDelete(null)}>Cancel</button>
              <button className="btn btn-danger" onClick={handleDelete}>Delete</button>
            </div>
          }
        >
          <p>
            This will revert to the platform default policy for{' '}
            <strong>{confirmDelete.name}</strong> ({confirmDelete.resourceType}/{confirmDelete.action}).
          </p>
        </Modal>
      )}
    </div>
  )
}
