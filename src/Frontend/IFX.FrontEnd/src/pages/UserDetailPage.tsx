import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { userManagementApi } from '../api/userManagement'
import { roleApi } from '../api/role'
import { roleGroupApi } from '../api/roleGroup'
import type { RoleDto, RoleGroupDto, UserProfileDto } from '../types/api'
import { Chip } from '../components/shared/Chip'
import { Modal } from '../components/shared/Modal'

export function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>()
  const navigate = useNavigate()
  const [user, setUser] = useState<UserProfileDto | null>(null)
  const [allRoles, setAllRoles] = useState<RoleDto[]>([])
  const [allGroups, setAllGroups] = useState<RoleGroupDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<'role' | 'group' | null>(null)
  const [selected, setSelected] = useState<string[]>([])
  const [saving, setSaving] = useState(false)

  const load = () =>
    userManagementApi.getById(userId!)
      .then(r => setUser(r.data?.data ?? null))
      .catch(() => setError('User not found'))

  useEffect(() => {
    Promise.all([
      load(),
      roleApi.getAll().then(r => setAllRoles(r.data?.data ?? [])),
      roleGroupApi.getAll().then(r => setAllGroups(r.data?.data ?? [])),
    ]).finally(() => setLoading(false))
  }, [userId])

  const removeRole = async (roleId: string) => {
    await userManagementApi.removeRole(userId!, roleId)
    await load()
  }

  const removeGroup = async (groupId: string) => {
    await userManagementApi.removeRoleGroup(userId!, groupId)
    await load()
  }

  const handleAssign = async () => {
    setSaving(true)
    try {
      if (modal === 'role') await userManagementApi.assignRoles(userId!, selected)
      if (modal === 'group') await userManagementApi.assignRoleGroups(userId!, selected)
      await load()
      setModal(null)
      setSelected([])
    } finally { setSaving(false) }
  }

  const toggleSelect = (id: string) =>
    setSelected(s => s.includes(id) ? s.filter(x => x !== id) : [...s, id])

  if (loading) return <div className="loading-inline"><span className="spinner" /></div>
  if (error || !user) return <div className="alert alert-error">{error || 'User not found'}</div>

  const assignableRoles = allRoles.filter(r => !user.roles.some(ur => ur.id === r.id))
  const assignableGroups = allGroups.filter(g => !user.roleGroups.some(ug => ug.id === g.id))

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <button className="btn-back" onClick={() => navigate('/users')}>← Users</button>
          <h2>{user.displayName}</h2>
        </div>
      </div>

      <div className="detail-card">
        <div className="detail-grid">
          <Field label="Email" value={user.email} />
          <Field label="First Name" value={user.firstName} />
          <Field label="Last Name" value={user.lastName} />
          <Field label="Phone" value={user.phoneNumber || '—'} />
          <Field label="Active" value={user.isActive ? 'Yes' : 'No'} />
          <Field label="Email Verified" value={user.emailVerified ? 'Yes' : 'No'} />
          <Field label="Member Since" value={new Date(user.createdAt).toLocaleDateString()} />
        </div>

        <div className="detail-section">
          <div className="detail-section-header">
            <h3>Roles</h3>
            <button className="btn btn-secondary btn-sm" onClick={() => { setModal('role'); setSelected([]) }}>Assign Roles</button>
          </div>
          <div className="chip-list">
            {user.roles.length ? user.roles.map(r => (
              <Chip key={r.id} label={r.name} onRemove={() => removeRole(r.id)} />
            )) : <span className="text-muted">No roles assigned</span>}
          </div>
        </div>

        <div className="detail-section">
          <div className="detail-section-header">
            <h3>Role Groups</h3>
            <button className="btn btn-secondary btn-sm" onClick={() => { setModal('group'); setSelected([]) }}>Assign Groups</button>
          </div>
          <div className="chip-list">
            {user.roleGroups.length ? user.roleGroups.map(g => (
              <Chip key={g.id} label={g.name} onRemove={() => removeGroup(g.id)} />
            )) : <span className="text-muted">No role groups assigned</span>}
          </div>
        </div>
      </div>

      {modal && (
        <Modal
          title={modal === 'role' ? 'Assign Roles' : 'Assign Role Groups'}
          onClose={() => setModal(null)}
          footer={
            <div className="btn-group">
              <button className="btn btn-ghost" onClick={() => setModal(null)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleAssign} disabled={saving || !selected.length}>
                {saving ? 'Assigning…' : 'Assign'}
              </button>
            </div>
          }
        >
          <div className="select-list">
            {(modal === 'role' ? assignableRoles : assignableGroups).map(item => (
              <label key={item.id} className="select-item">
                <input type="checkbox" checked={selected.includes(item.id)} onChange={() => toggleSelect(item.id)} />
                <div>
                  <div className="select-item-name">{item.name}</div>
                  <div className="select-item-desc">{item.description}</div>
                </div>
              </label>
            ))}
            {(modal === 'role' ? assignableRoles : assignableGroups).length === 0 && (
              <p className="text-muted">All {modal === 'role' ? 'roles' : 'groups'} already assigned.</p>
            )}
          </div>
        </Modal>
      )}
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="field-row">
      <span className="field-label">{label}</span>
      <span className="field-value">{value}</span>
    </div>
  )
}
