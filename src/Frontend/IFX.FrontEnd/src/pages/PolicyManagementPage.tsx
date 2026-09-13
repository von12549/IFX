import { apiErrorMessage } from '../api/errors'
import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { policyApi } from '../api/policy'
import { platformApi } from '../api/platform'
import type { PolicyDefinitionDto, TemplateDto, PolicyConditionDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { TenantRequiredBanner } from '../components/shared/TenantRequiredBanner'

type ModalMode = 'create' | 'edit' | null
type TabKey = 'tenant' | 'platform'

interface PolicyForm {
  name: string
  description: string
  resourceType: string
  action: string
  conditions: PolicyConditionDto[]
}

const emptyForm: PolicyForm = { name: '', description: '', resourceType: '', action: '', conditions: [] }

function groupByResourceType(policies: PolicyDefinitionDto[]): Map<string, PolicyDefinitionDto[]> {
  const map = new Map<string, PolicyDefinitionDto[]>()
  for (const p of policies) {
    const key = p.resourceType
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(p)
  }
  return map
}

interface PolicyGroupProps {
  resourceType: string
  policies: PolicyDefinitionDto[]
  readOnly: boolean
  onEdit: (p: PolicyDefinitionDto) => void
  onOverride: (p: PolicyDefinitionDto) => void
  onDelete: (p: PolicyDefinitionDto) => void
}

function PolicyGroup({ resourceType, policies, readOnly, onEdit, onOverride, onDelete }: PolicyGroupProps) {
  const [collapsed, setCollapsed] = useState(false)

  return (
    <>
      <tr className="policy-group-header" onClick={() => setCollapsed(c => !c)} style={{ cursor: 'pointer' }}>
        <td colSpan={5}>
          <strong>{collapsed ? '▶' : '▼'} {resourceType}</strong>
          <span className="text-muted" style={{ marginLeft: 8 }}>({policies.length})</span>
        </td>
        {!readOnly && <td />}
      </tr>
      {!collapsed && policies.map((p, i) => (
        <tr key={p.id ?? `default-${i}`}>
          <td style={{ paddingLeft: '2rem' }}>{p.name}</td>
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
          {!readOnly && (
            <td>
              <div className="btn-group">
                {p.isPlatformDefault ? (
                  <button className="btn btn-ghost btn-sm" onClick={() => onOverride(p)}>Override</button>
                ) : (
                  <>
                    <button className="btn btn-ghost btn-sm" onClick={() => onEdit(p)}>Edit</button>
                    <button className="btn btn-danger btn-sm" onClick={() => onDelete(p)}>Delete</button>
                  </>
                )}
              </div>
            </td>
          )}
        </tr>
      ))}
    </>
  )
}

interface PolicyTableProps {
  policies: PolicyDefinitionDto[]
  readOnly: boolean
  onEdit: (p: PolicyDefinitionDto) => void
  onOverride: (p: PolicyDefinitionDto) => void
  onDelete: (p: PolicyDefinitionDto) => void
}

function PolicyTable({ policies, readOnly, onEdit, onOverride, onDelete }: PolicyTableProps) {
  const grouped = groupByResourceType(policies)
  const resourceTypes = Array.from(grouped.keys()).sort()

  return (
    <div className="table-wrapper">
      <table className="data-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Resource Type</th>
            <th>Action</th>
            <th>Conditions</th>
            <th>Source</th>
            {!readOnly && <th></th>}
          </tr>
        </thead>
        <tbody>
          {resourceTypes.map(rt => (
            <PolicyGroup
              key={rt}
              resourceType={rt}
              policies={grouped.get(rt)!}
              readOnly={readOnly}
              onEdit={onEdit}
              onOverride={onOverride}
              onDelete={onDelete}
            />
          ))}
          {policies.length === 0 && (
            <tr><td colSpan={readOnly ? 5 : 6} className="text-muted text-center">No policies found.</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

export function PolicyManagementPage() {
  const { selectedTenantId, isGlobalUser } = useAuth()
  const [searchParams, setSearchParams] = useSearchParams()
  const [policies, setPolicies] = useState<PolicyDefinitionDto[]>([])
  const [platformPolicies, setPlatformPolicies] = useState<PolicyDefinitionDto[]>([])
  const [templates, setTemplates] = useState<TemplateDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<ModalMode>(null)
  const [form, setForm] = useState<PolicyForm>(emptyForm)
  const [editId, setEditId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState<PolicyDefinitionDto | null>(null)

  const activeTab: TabKey = searchParams.get('tab') === 'platform' ? 'platform' : 'tenant'

  const load = () =>
    Promise.all([
      policyApi.getAll().then(r => setPolicies(r.data?.data ?? [])),
      policyApi.getTemplates().then(r => setTemplates(r.data?.data ?? [])),
      isGlobalUser
        ? platformApi.getPolicies().then(r => setPlatformPolicies(r.data?.data ?? []))
        : Promise.resolve(),
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
    } catch (err: unknown) {
      setError(apiErrorMessage(err, 'Failed to save'))
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

  const visiblePolicies = activeTab === 'platform' ? platformPolicies : policies

  return (
    <div className="page">
      <div className="page-header">
        <h2>Policy Management</h2>
        {activeTab === 'tenant' && (
          <button className="btn btn-primary" onClick={openCreate}>+ Create Policy</button>
        )}
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {isGlobalUser && !selectedTenantId && activeTab === 'tenant' && <TenantRequiredBanner />}

      {isGlobalUser && (
        <div className="tab-bar">
          <button
            className={`tab-btn${activeTab === 'tenant' ? ' active' : ''}`}
            onClick={() => setSearchParams({})}
          >
            Tenant Policies
          </button>
          <button
            className={`tab-btn${activeTab === 'platform' ? ' active' : ''}`}
            onClick={() => setSearchParams({ tab: 'platform' })}
          >
            Platform Policies
          </button>
        </div>
      )}

      {loading ? (
        <div className="loading-inline"><span className="spinner" /></div>
      ) : (
        <PolicyTable
          policies={visiblePolicies}
          readOnly={activeTab === 'platform'}
          onEdit={openEdit}
          onOverride={openOverride}
          onDelete={setConfirmDelete}
        />
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
