import { NavLink } from 'react-router-dom'

const nav = [
  { to: '/idp', label: 'IdP Management' },
  { to: '/users', label: 'User Management' },
  { to: '/rolegroups', label: 'RoleGroup Management' },
  { to: '/roles', label: 'Role Management' },
  { to: '/permissions', label: 'Permission Management' },
]

export function Sidebar() {
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
    </aside>
  )
}
