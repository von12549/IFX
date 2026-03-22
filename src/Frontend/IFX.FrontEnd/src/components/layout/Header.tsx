import { useAuth } from '../../contexts/AuthContext'
import { UserMenu } from './UserMenu'
import { TenantSwitcher } from './TenantSwitcher'

export function Header() {
  const { isAuthenticated } = useAuth()

  return (
    <header className="header">
      <div className="header-left">
        <svg className="ifx-icon" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" aria-label="IFX">
          <polygon points="20,2 38,36 2,36" fill="none" stroke="#6366f1" strokeWidth="3" />
          <line x1="20" y1="14" x2="20" y2="28" stroke="#6366f1" strokeWidth="2.5" />
          <line x1="13" y1="28" x2="27" y2="28" stroke="#6366f1" strokeWidth="2.5" />
        </svg>
      </div>
      <div className="header-center">
        <span className="header-title">IFX</span>
      </div>
      <div className="header-right">
        {isAuthenticated && <TenantSwitcher />}
        {isAuthenticated && <UserMenu />}
      </div>
    </header>
  )
}
