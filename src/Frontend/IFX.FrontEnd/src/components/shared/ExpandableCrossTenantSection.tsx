import { useState } from 'react'
import type { TenantGroupDto } from '../../types/api'

interface Column<T> {
  header: string
  render: (item: T) => React.ReactNode
}

interface Props<T> {
  label?: string
  fetchData: () => Promise<{ data?: { data?: { tenants: TenantGroupDto<T>[] } } }>
  columns: Column<T>[]
  getKey: (item: T) => string
}

export function ExpandableCrossTenantSection<T>({
  label = 'Other Tenants',
  fetchData,
  columns,
  getKey,
}: Props<T>) {
  const [expanded, setExpanded] = useState(false)
  const [loading, setLoading] = useState(false)
  const [groups, setGroups] = useState<TenantGroupDto<T>[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function handleExpand() {
    if (expanded) {
      setExpanded(false)
      return
    }
    setExpanded(true)
    if (groups !== null) return
    setLoading(true)
    setError(null)
    try {
      const res = await fetchData()
      setGroups(res.data?.data?.tenants ?? [])
    } catch {
      setError('Failed to load cross-tenant data.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="cross-tenant-section">
      <button className="cross-tenant-toggle" onClick={handleExpand} type="button">
        <span className={`toggle-arrow ${expanded ? 'open' : ''}`}>▶</span>
        {label}
        {groups !== null && !loading && (
          <span className="badge badge-secondary" style={{ marginLeft: 8 }}>
            {groups.reduce((n, g) => n + g.items.length, 0)} items across {groups.length} tenant{groups.length !== 1 ? 's' : ''}
          </span>
        )}
      </button>

      {expanded && (
        <div className="cross-tenant-content">
          {loading && <p className="text-muted" style={{ padding: '12px 0' }}>Loading...</p>}
          {error && <p className="text-danger">{error}</p>}
          {groups !== null && groups.length === 0 && (
            <p className="text-muted" style={{ padding: '12px 0' }}>No data found in other tenants.</p>
          )}
          {groups !== null && groups.map(group => (
            <div key={group.tenantId} className="cross-tenant-group">
              <div className="cross-tenant-group-header">{group.tenantName}</div>
              <table className="table">
                <thead>
                  <tr>
                    {columns.map(col => <th key={col.header}>{col.header}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {group.items.map(item => (
                    <tr key={getKey(item)}>
                      {columns.map(col => (
                        <td key={col.header}>{col.render(item)}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
