import { useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { tokenStorage } from '../../api/client'

export function UserMenu() {
  const { user, logout } = useAuth()
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  const ref = useRef<HTMLDivElement>(null)

  const initials = [user?.firstName?.[0], user?.lastName?.[0]].filter(Boolean).join('').toUpperCase() || '?'

  const handleLogout = () => {
    const refreshToken = tokenStorage.getRefreshToken()
    logout()
    // Redirect to Cognito logout (clears Cognito session), fallback to /login
    const logoutUrl = `http://localhost:5010/api/v1/auth/oauth/logout${refreshToken ? `?refresh_token=${encodeURIComponent(refreshToken)}` : ''}`
    window.location.href = logoutUrl
  }

  return (
    <div className="user-menu" ref={ref}>
      <button
        className="user-menu-avatar"
        onClick={() => setOpen(o => !o)}
        aria-label="User menu"
      >
        {initials}
      </button>
      {open && (
        <div className="user-menu-dropdown">
          <div className="user-menu-name">{user?.displayName}</div>
          <div className="user-menu-email">{user?.email}</div>
          <hr className="user-menu-divider" />
          <button onClick={() => { setOpen(false); navigate('/profile') }}>My Profile</button>
          <button onClick={handleLogout}>Logout</button>
        </div>
      )}
    </div>
  )
}
