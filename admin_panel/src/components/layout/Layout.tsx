// admin_panel/src/components/layout/Layout.tsx
import React from 'react';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import type { NavigationTab } from './Sidebar';

interface LayoutProps {
  currentTab: NavigationTab;
  onSelectTab: (tab: NavigationTab) => void;
  children: React.ReactNode;
  onRefresh?: () => void;
  isRefreshing?: boolean;
  pendingVerificationsCount?: number;
  criticalRequestsCount?: number;
  pendingReportsCount?: number;
}

export const Layout: React.FC<LayoutProps> = ({
  currentTab,
  onSelectTab,
  children,
  onRefresh,
  isRefreshing,
  pendingVerificationsCount = 0,
  criticalRequestsCount = 0,
  pendingReportsCount = 0,
}) => {
  const totalAlerts = pendingVerificationsCount + criticalRequestsCount + pendingReportsCount;

  return (
    <div className="flex h-screen bg-slate-50 font-sans overflow-hidden">
      {/* Fixed Left Navigation */}
      <Sidebar
        currentTab={currentTab}
        onSelectTab={onSelectTab}
        pendingVerificationsCount={pendingVerificationsCount}
        criticalRequestsCount={criticalRequestsCount}
        pendingReportsCount={pendingReportsCount}
      />

      {/* Main Page Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Header
          currentTab={currentTab}
          onRefresh={onRefresh}
          isRefreshing={isRefreshing}
          totalAlerts={totalAlerts}
        />
        <main className="flex-1 overflow-y-auto p-8">{children}</main>
      </div>
    </div>
  );
};
