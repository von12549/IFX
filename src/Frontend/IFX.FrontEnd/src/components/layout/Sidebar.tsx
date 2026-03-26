import { NavLink } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'

const nav = [
  { to: '/idp', label: 'IdP Management' },
  { to: '/users', label: 'User Management' },
  { to: '/rolegroups', label: 'RoleGroup Management' },
  { to: '/roles', label: 'Role Management' },
  { to: '/permissions', label: 'Permission Management' },
  { to: '/tenants', label: 'Tenant Management' },
  { to: '/departments', label: 'Department Management' },
  { to: '/policies', label: 'Policy Management' },
]

const platformNav = [
  { to: '/globalroles', label: 'Global Roles' },
  { to: '/policies?tab=platform', label: 'Platform Policies' },
  { to: '/permissions?tab=platform', label: 'Platform Permissions' },
]

export function Sidebar() {
  const { isGlobalUser } = useAuth()

  return (
    <aside className="sidebar">
      <div className="sidebar-section-label">Management</div>
      <nav>
        {nav.map(item => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) => `sidebar-link${isActive ? ' active' : ''}`}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
      {isGlobalUser && (
        <>
          <div className="sidebar-section-label">Platform</div>
          <nav>
            {platformNav.map(item => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) => `sidebar-link${isActive ? ' active' : ''}`}
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </>
      )}
    </aside>
  )
}
