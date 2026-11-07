// admin_panel/src/components/layout/Layout.tsx
import React, { useState } from 'react';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import type { NavigationTab } from './Sidebar';
import type { NotificationItem } from '../../types';

interface LayoutProps {
  currentTab: NavigationTab;
  onSelectTab: (tab: NavigationTab) => void;
  children: React.ReactNode;
  onRefresh?: () => void;
  isRefreshing?: boolean;
  pendingVerificationsCount?: number;
  pendingDeletionRequestsCount?: number;
  criticalRequestsCount?: number;
  pendingReportsCount?: number;
  notifications?: NotificationItem[];
  onMarkNotificationRead?: (id: string) => void;
  onMarkAllNotificationsRead?: () => void;
}

export const Layout: React.FC<LayoutProps> = ({
  currentTab,
  onSelectTab,
  children,
  onRefresh,
  isRefreshing,
  pendingVerificationsCount = 0,
  pendingDeletionRequestsCount = 0,
  criticalRequestsCount = 0,
  pendingReportsCount = 0,
  notifications = [],
  onMarkNotificationRead,
  onMarkAllNotificationsRead,
}) => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const totalAlerts =
    pendingVerificationsCount +
    pendingDeletionRequestsCount +
    criticalRequestsCount +
    pendingReportsCount;

  return (
    <div className="flex h-screen bg-slate-50 font-sans overflow-hidden">
      {/* Left Navigation (Desktop collapsible + Mobile drawer) */}
      <Sidebar
        currentTab={currentTab}
        onSelectTab={onSelectTab}
        pendingVerificationsCount={pendingVerificationsCount}
        pendingDeletionRequestsCount={pendingDeletionRequestsCount}
        criticalRequestsCount={criticalRequestsCount}
        pendingReportsCount={pendingReportsCount}
        mobileOpen={mobileMenuOpen}
        onCloseMobile={() => setMobileMenuOpen(false)}
        collapsed={sidebarCollapsed}
        onToggleCollapse={() => setSidebarCollapsed((prev) => !prev)}
      />

      {/* Main Page Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Header
          currentTab={currentTab}
          onSelectTab={onSelectTab}
          onRefresh={onRefresh}
          isRefreshing={isRefreshing}
          totalAlerts={totalAlerts}
          pendingVerificationsCount={pendingVerificationsCount}
          pendingDeletionRequestsCount={pendingDeletionRequestsCount}
          criticalRequestsCount={criticalRequestsCount}
          pendingReportsCount={pendingReportsCount}
          notifications={notifications}
          onMarkNotificationRead={onMarkNotificationRead}
          onMarkAllNotificationsRead={onMarkAllNotificationsRead}
          onOpenMobileMenu={() => setMobileMenuOpen(true)}
        />
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">{children}</main>
      </div>
    </div>
  );
};
