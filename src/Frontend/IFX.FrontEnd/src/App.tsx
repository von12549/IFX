import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import { AppLayout } from './components/layout/AppLayout'
import { ProtectedRoute } from './components/shared/ProtectedRoute'
import { LoginPage } from './pages/auth/LoginPage'
import { RegisterPage } from './pages/auth/RegisterPage'
import { CallbackPage } from './pages/auth/CallbackPage'
import { UserProfilePage } from './pages/UserProfilePage'
import { IdpManagementPage } from './pages/IdpManagementPage'
import { UserManagementPage } from './pages/UserManagementPage'
import { UserDetailPage } from './pages/UserDetailPage'
import { RoleGroupManagementPage } from './pages/RoleGroupManagementPage'
import { RoleGroupDetailPage } from './pages/RoleGroupDetailPage'
import { RoleManagementPage } from './pages/RoleManagementPage'
import { RoleDetailPage } from './pages/RoleDetailPage'
import { PermissionManagementPage } from './pages/PermissionManagementPage'
import { TenantManagementPage } from './pages/TenantManagementPage'
import { DepartmentManagementPage } from './pages/DepartmentManagementPage'
import { PolicyManagementPage } from './pages/PolicyManagementPage'
import { GlobalRolesPage } from './pages/GlobalRolesPage'

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/callback" element={<CallbackPage />} />

          <Route element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
            <Route path="/profile" element={<UserProfilePage />} />
            <Route path="/idp" element={<IdpManagementPage />} />
            <Route path="/users" element={<UserManagementPage />} />
            <Route path="/users/:userId" element={<UserDetailPage />} />
            <Route path="/rolegroups" element={<RoleGroupManagementPage />} />
            <Route path="/rolegroups/:roleGroupId" element={<RoleGroupDetailPage />} />
            <Route path="/roles" element={<RoleManagementPage />} />
            <Route path="/roles/:roleId" element={<RoleDetailPage />} />
            <Route path="/permissions" element={<PermissionManagementPage />} />
            <Route path="/tenants" element={<TenantManagementPage />} />
            <Route path="/departments" element={<DepartmentManagementPage />} />
            <Route path="/policies" element={<PolicyManagementPage />} />
            <Route path="/globalroles" element={<GlobalRolesPage />} />
          </Route>

          <Route path="/" element={<Navigate to="/profile" replace />} />
          <Route path="*" element={<Navigate to="/profile" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
