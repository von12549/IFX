import { useEffect, useState } from 'react'
import { idpApi } from '../api/idp'
import { tenantApi } from '../api/tenant'
import type { CreateIdpRequest, IdpDto, TenantDto } from '../types/api'
import { Modal } from '../components/shared/Modal'
import { SortableHeader } from '../components/shared/SortableHeader'

const IdpTypeLabel: Record<number, string> = { 0: 'Cognito', 1: 'Auth0', 2: 'Generic OIDC' }

const emptyForm = (): CreateIdpRequest => ({
  name: '', issuer: '', authority: '', description: '', loginUrl: '',
  idpType: 0, isPrimary: false, enabled: true, autoProvisionEnabled: false,
  expectedAudiences: '', allowedAlgs: 'RS256', requiredScopes: '', claimMapping: '',
  clockSkewSeconds: 300,
})

type SortCol = 'name' | 'type' | 'issuer' | 'tenantName' | 'isPrimary' | 'enabled' | 'autoProvisionEnabled'

export function IdpManagementPage() {
  const [idps, setIdps] = useState<IdpDto[]>([])
  const [tenants, setTenants] = useState<TenantDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<'create' | 'edit' | null>(null)
  const [form, setForm] = useState<CreateIdpRequest>(emptyForm())
  const [editId, setEditId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [sortCol, setSortCol] = useState<SortCol>('name')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const [filterTenantId, setFilterTenantId] = useState<string>('')

  const load = (tenantId?: string) => idpApi.getAll(tenantId || undefined).then(r => setIdps(r.data?.data ?? [])).catch(() => setError('Failed to load IdPs'))

  useEffect(() => {
    Promise.all([
      load(),
      tenantApi.getAll().then(r => setTenants(r.data?.data ?? [])),
    ]).finally(() => setLoading(false))
  }, [])

  const handleFilterChange = (tenantId: string) => {
    setFilterTenantId(tenantId)
    load(tenantId || undefined)
  }

  const set = (k: keyof CreateIdpRequest) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const value = e.target.type === 'checkbox' ? (e.target as HTMLInputElement).checked
      : e.target.type === 'number' ? Number(e.target.value)
      : e.target.value
    setForm(f => ({ ...f, [k]: value }))
  }

  const openCreate = () => { setForm(emptyForm()); setEditId(null); setModal('create') }
  const openEdit = (idp: IdpDto) => {
    setForm({ name: idp.name, issuer: idp.issuer, authority: idp.authority, description: idp.description,
      loginUrl: idp.loginUrl, idpType: idp.idpType, isPrimary: idp.isPrimary, enabled: idp.enabled,
      autoProvisionEnabled: idp.autoProvisionEnabled, expectedAudiences: idp.expectedAudiences,
      allowedAlgs: idp.allowedAlgs, requiredScopes: idp.requiredScopes, claimMapping: idp.claimMapping,
      clockSkewSeconds: idp.clockSkewSeconds })
    setEditId(idp.id)
    setModal('edit')
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (modal === 'create') await idpApi.create(form)
      else if (editId) await idpApi.update(editId, form)
      await load()
      setModal(null)
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to save')
    } finally { setSaving(false) }
  }

  const toggleSort = (col: string) => {
    const c = col as SortCol
    if (sortCol === c) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortCol(c); setSortDir('asc') }
  }

  const sorted = [...idps].sort((a, b) => {
    let v = 0
    if (sortCol === 'type') v = (IdpTypeLabel[a.idpType] ?? '').localeCompare(IdpTypeLabel[b.idpType] ?? '')
    else if (sortCol === 'isPrimary') v = Number(a.isPrimary) - Number(b.isPrimary)
    else if (sortCol === 'enabled') v = Number(a.enabled) - Number(b.enabled)
    else if (sortCol === 'autoProvisionEnabled') v = Number(a.autoProvisionEnabled) - Number(b.autoProvisionEnabled)
    else v = (a[sortCol as 'name' | 'issuer' | 'tenantName'] ?? '').localeCompare(b[sortCol as 'name' | 'issuer' | 'tenantName'] ?? '')
    return sortDir === 'asc' ? v : -v
  })

  return (
    <div className="page">
      <div className="page-header">
        <h2>IdP Management</h2>
        <button className="btn btn-primary" onClick={openCreate}>+ Create IdP</button>
      </div>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="filter-bar">
        <label>Filter by Tenant:</label>
        <select value={filterTenantId} onChange={e => handleFilterChange(e.target.value)}>
          <option value="">— Select Tenant —</option>
          {tenants.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
        </select>
      </div>

      {loading ? <div className="loading-inline"><span className="spinner" /></div> : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <SortableHeader label="Name" col="name" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Type" col="type" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Issuer" col="issuer" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Tenant" col="tenantName" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Primary" col="isPrimary" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Enabled" col="enabled" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <SortableHeader label="Auto-Provision" col="autoProvisionEnabled" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
                <th></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map(idp => (
                <tr key={idp.id}>
                  <td>{idp.name}</td>
                  <td>{IdpTypeLabel[idp.idpType] ?? idp.idpType}</td>
                  <td className="text-muted text-sm">{idp.issuer}</td>
                  <td className="text-muted">{idp.tenantName}</td>
                  <td><span className={`badge ${idp.isPrimary ? 'badge-success' : 'badge-muted'}`}>{idp.isPrimary ? 'Yes' : 'No'}</span></td>
                  <td><span className={`badge ${idp.enabled ? 'badge-success' : 'badge-muted'}`}>{idp.enabled ? 'Yes' : 'No'}</span></td>
                  <td><span className={`badge ${idp.autoProvisionEnabled ? 'badge-success' : 'badge-muted'}`}>{idp.autoProvisionEnabled ? 'Yes' : 'No'}</span></td>
                  <td><button className="btn btn-ghost btn-sm" onClick={() => openEdit(idp)}>Edit</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {modal && (
        <Modal
          title={modal === 'create' ? 'Create Identity Provider' : 'Edit Identity Provider'}
          onClose={() => setModal(null)}
          footer={
            <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setModal(null)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
            </div>
          }
        >
          <div className="form-grid">
            <div className="form-group"><label>Name</label><input value={form.name} onChange={set('name')} /></div>
            <div className="form-group"><label>Type</label>
              <select value={form.idpType} onChange={set('idpType')}>
                <option value={0}>Cognito</option><option value={1}>Auth0</option><option value={2}>Generic OIDC</option>
              </select>
            </div>
            <div className="form-group form-full"><label>Issuer</label><input value={form.issuer} onChange={set('issuer')} /></div>
            <div className="form-group form-full"><label>Authority</label><input value={form.authority} onChange={set('authority')} /></div>
            <div className="form-group form-full"><label>Description</label><input value={form.description} onChange={set('description')} /></div>
            <div className="form-group form-full"><label>Login URL</label><input value={form.loginUrl} onChange={set('loginUrl')} /></div>
            <div className="form-group"><label>Expected Audiences</label><input value={form.expectedAudiences} onChange={set('expectedAudiences')} /></div>
            <div className="form-group"><label>Allowed Algs</label><input value={form.allowedAlgs} onChange={set('allowedAlgs')} /></div>
            <div className="form-group"><label>Required Scopes</label><input value={form.requiredScopes} onChange={set('requiredScopes')} /></div>
            <div className="form-group"><label>Clock Skew (s)</label><input type="number" value={form.clockSkewSeconds} onChange={set('clockSkewSeconds')} /></div>
            <div className="form-check"><label><input type="checkbox" checked={form.isPrimary} onChange={set('isPrimary')} /> Primary</label></div>
            <div className="form-check"><label><input type="checkbox" checked={form.enabled} onChange={set('enabled')} /> Enabled</label></div>
            <div className="form-check"><label><input type="checkbox" checked={form.autoProvisionEnabled} onChange={set('autoProvisionEnabled')} /> Auto-Provision</label></div>
          </div>
        </Modal>
      )}
    </div>
  )
}
