import { Navigate, Route, Routes } from 'react-router-dom';

import { AppShell } from './components/layout/AppShell';
import { DashboardPage } from './pages/DashboardPage';
import { DemoModePage } from './pages/DemoModePage';
import { OnboardingPage } from './pages/OnboardingPage';
import { RbacUsersPage } from './pages/RbacUsersPage';
import { SettingsPage } from './pages/SettingsPage';
import { TenantDetailPage } from './pages/TenantDetailPage';
import { TenantsPage } from './pages/TenantsPage';
import { TestingPage } from './pages/TestingPage';

export default function App() {
  return (
    <Routes>
      <Route element={<AppShell />} path="/">
        <Route element={<DashboardPage />} index />
        <Route element={<TenantsPage />} path="tenants" />
        <Route element={<TenantDetailPage />} path="tenants/:tenant" />
        <Route element={<OnboardingPage />} path="onboarding" />
        <Route element={<RbacUsersPage />} path="rbac-users" />
        <Route element={<TestingPage />} path="testing" />
        <Route element={<DemoModePage />} path="demo" />
        <Route element={<SettingsPage />} path="settings" />
      </Route>
      <Route element={<Navigate replace to="/" />} path="*" />
    </Routes>
  );
}