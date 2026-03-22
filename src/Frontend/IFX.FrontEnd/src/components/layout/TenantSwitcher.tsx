import { useAuth } from '../../contexts/AuthContext'

export function TenantSwitcher() {
  const { user, selectedTenantId, setSelectedTenantId } = useAuth()

  if (!user || !user.tenants?.length) return null

  const current = user.tenants.find(t => t.id === selectedTenantId) ?? user.tenants[0]

  if (user.tenants.length === 1) {
    return (
      <div className="tenant-switcher tenant-switcher-single">
        <span className="tenant-switcher-icon">🏢</span>
        <span className="tenant-switcher-name">{current.name}</span>
      </div>
    )
  }

  return (
    <div className="tenant-switcher">
      <span className="tenant-switcher-icon">🏢</span>
      <select
        className="tenant-switcher-select"
        value={selectedTenantId ?? current.id}
        onChange={e => setSelectedTenantId(e.target.value)}
      >
        {user.tenants.map(t => (
          <option key={t.id} value={t.id}>
            {t.name}{t.id === user.primaryTenantId ? ' ★' : ''}
          </option>
        ))}
      </select>
    </div>
  )
}
