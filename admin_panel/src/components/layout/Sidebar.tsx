// admin_panel/src/components/layout/Sidebar.tsx
import React from 'react';
import {
  LayoutDashboard,
  Users,
  Droplets,
  Building2,
  BookOpen,
  ShieldAlert,
  Send,
  BarChart3,
  ClipboardList,
  LogOut,
  Activity,
  X,
  PanelLeftClose,
  PanelLeftOpen,
  UserX,
  ShieldCheck,
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';

export type NavigationTab =
  | 'dashboard'
  | 'donors'
  | 'requests'
  | 'facilities'
  | 'content'
  | 'reports'
  | 'broadcast'
  | 'analytics'
  | 'audit_logs';

interface SidebarProps {
  currentTab: NavigationTab;
  onSelectTab: (tab: NavigationTab) => void;
  pendingVerificationsCount?: number;
  pendingDeletionRequestsCount?: number;
  criticalRequestsCount?: number;
  pendingReportsCount?: number;
  mobileOpen?: boolean;
  onCloseMobile?: () => void;
  collapsed?: boolean;
  onToggleCollapse?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  pendingVerificationsCount = 0,
  pendingDeletionRequestsCount = 0,
  criticalRequestsCount = 0,
  pendingReportsCount = 0,
  mobileOpen = false,
  onCloseMobile,
  collapsed = false,
  onToggleCollapse,
}) => {
  const { user, profile, signOut } = useAuth();

  const totalDonorQueue = pendingVerificationsCount + pendingDeletionRequestsCount;

  const navItems = [
    {
      id: 'dashboard' as NavigationTab,
      label: 'Dashboard',
      icon: LayoutDashboard,
    },
    {
      id: 'donors' as NavigationTab,
      label: 'Donors & Users',
      icon: Users,
      badge: totalDonorQueue > 0 ? totalDonorQueue : undefined,
      badgeColor:
        pendingDeletionRequestsCount > 0
          ? 'bg-rose-600 text-white'
          : 'bg-amber-500 text-white',
    },
    {
      id: 'requests' as NavigationTab,
      label: 'Blood Requests',
      icon: Droplets,
      badge: criticalRequestsCount > 0 ? criticalRequestsCount : undefined,
      badgeColor: 'bg-rose-600 text-white',
    },
    {
      id: 'facilities' as NavigationTab,
      label: 'Blood Banks',
      icon: Building2,
    },
    {
      id: 'content' as NavigationTab,
      label: 'Health Guides',
      icon: BookOpen,
    },
    {
      id: 'reports' as NavigationTab,
      label: 'Safety Reports',
      icon: ShieldAlert,
      badge: pendingReportsCount > 0 ? pendingReportsCount : undefined,
      badgeColor: 'bg-rose-500 text-white',
    },
    {
      id: 'broadcast' as NavigationTab,
      label: 'Broadcast & Direct',
      icon: Send,
    },
    {
      id: 'analytics' as NavigationTab,
      label: 'Analytics & Funnel',
      icon: BarChart3,
    },
    {
      id: 'audit_logs' as NavigationTab,
      label: 'Audit Logs',
      icon: ClipboardList,
    },
  ];

  const handleSelect = (tab: NavigationTab) => {
    onSelectTab(tab);
    if (onCloseMobile) onCloseMobile();
  };

  const roleBadgeLabel = profile?.role === 'admin' ? 'Admin' : 'Moderator';

  const renderSidebarContent = (isMobileDrawer: boolean) => {
    const isCompact = !isMobileDrawer && collapsed;
    return (
      <aside
        className={`${
          isCompact ? 'w-20' : 'w-64'
        } bg-slate-900 text-slate-300 flex flex-col shrink-0 h-full border-r border-slate-800 select-none transition-all duration-200`}
      >
        {/* Brand Header */}
        <div
          className={`${
            isCompact ? 'p-4 justify-center' : 'p-5 justify-between'
          } border-b border-slate-800/80 flex items-center`}
        >
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-red-600 to-rose-500 flex items-center justify-center text-white shadow-lg shadow-red-900/40 shrink-0">
              <Activity className="w-6 h-6 stroke-[2.5]" />
            </div>
            {!isCompact && (
              <div className="min-w-0">
                <h1 className="text-base font-extrabold text-white tracking-tight flex items-center gap-1.5">
                  RedCellNet
                  <span className="text-[10px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded-sm bg-red-500/20 text-red-400 border border-red-500/30">
                    {roleBadgeLabel}
                  </span>
                </h1>
                <p className="text-[11px] text-slate-400 font-medium truncate">
                  Staff Operations Hub
                </p>
              </div>
            )}
          </div>
          {isMobileDrawer && onCloseMobile ? (
            <button
              type="button"
              onClick={onCloseMobile}
              className="lg:hidden p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg"
              aria-label="Close navigation menu"
            >
              <X className="w-5 h-5" />
            </button>
          ) : (
            onToggleCollapse &&
            !isCompact && (
              <button
                type="button"
                onClick={onToggleCollapse}
                title="Collapse sidebar"
                className="hidden lg:inline-flex p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
              >
                <PanelLeftClose className="w-4 h-4" />
              </button>
            )
          )}
        </div>

        {isCompact && onToggleCollapse && (
          <div className="px-3 pt-3 flex justify-center">
            <button
              type="button"
              onClick={onToggleCollapse}
              title="Expand sidebar"
              className="p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-xl transition-colors"
            >
              <PanelLeftOpen className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* Navigation List */}
        <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          {!isCompact && (
            <div className="px-3 pb-2 text-[11px] font-bold uppercase tracking-wider text-slate-500">
              Operations & Governance
            </div>
          )}
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => handleSelect(item.id)}
                title={isCompact ? item.label : undefined}
                className={`w-full flex items-center ${
                  isCompact ? 'justify-center px-2 py-3' : 'justify-between px-3.5 py-2.5'
                } rounded-xl font-medium text-sm transition-all duration-150 group relative ${
                  isActive
                    ? 'bg-red-600 text-white shadow-md shadow-red-900/30 font-semibold'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
                }`}
              >
                <div className="flex items-center gap-3">
                  <Icon
                    className={`w-5 h-5 transition-colors shrink-0 ${
                      isActive ? 'text-white' : 'text-slate-400 group-hover:text-slate-200'
                    }`}
                  />
                  {!isCompact && <span>{item.label}</span>}
                </div>
                {item.badge !== undefined && !isCompact && (
                  <span
                    className={`text-[11px] font-bold px-2 py-0.5 rounded-full shadow-xs ${
                      isActive
                        ? 'bg-white/20 text-white'
                        : item.badgeColor || 'bg-slate-700 text-slate-300'
                    }`}
                  >
                    {item.badge}
                  </span>
                )}
                {item.badge !== undefined && isCompact && (
                  <span className="absolute top-1.5 right-1.5 w-4 h-4 rounded-full bg-rose-500 text-white text-[9px] font-black flex items-center justify-center">
                    {item.badge > 9 ? '9+' : item.badge}
                  </span>
                )}
              </button>
            );
          })}

          {/* Live Staff Triage Summary Card */}
          {!isCompact &&
            (pendingVerificationsCount > 0 ||
              pendingDeletionRequestsCount > 0 ||
              criticalRequestsCount > 0) && (
              <div className="mt-5 mx-1 p-3 rounded-2xl bg-slate-800/70 border border-slate-700/80 space-y-2">
                <div className="text-[10px] font-black uppercase tracking-wider text-slate-400">
                  Live Action Queue
                </div>
                {pendingDeletionRequestsCount > 0 && (
                  <button
                    type="button"
                    onClick={() => handleSelect('donors')}
                    className="w-full flex items-center justify-between text-xs text-rose-300 hover:text-white py-1 transition-colors"
                  >
                    <span className="flex items-center gap-1.5 font-semibold">
                      <UserX className="w-3.5 h-3.5 text-rose-400" />
                      Deletion Approvals
                    </span>
                    <span className="px-1.5 py-0.5 rounded bg-rose-500/20 text-rose-300 font-black text-[10px]">
                      {pendingDeletionRequestsCount}
                    </span>
                  </button>
                )}
                {pendingVerificationsCount > 0 && (
                  <button
                    type="button"
                    onClick={() => handleSelect('donors')}
                    className="w-full flex items-center justify-between text-xs text-amber-300 hover:text-white py-1 transition-colors"
                  >
                    <span className="flex items-center gap-1.5 font-semibold">
                      <ShieldCheck className="w-3.5 h-3.5 text-amber-400" />
                      Lab Verifications
                    </span>
                    <span className="px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 font-black text-[10px]">
                      {pendingVerificationsCount}
                    </span>
                  </button>
                )}
              </div>
            )}
        </nav>

        {/* User & Sign Out Footer */}
        <div className="p-4 border-t border-slate-800/80 bg-slate-950/40">
          <div className={`flex items-center ${isCompact ? 'justify-center' : 'justify-between'}`}>
            {!isCompact && (
              <div className="flex items-center gap-2.5 overflow-hidden">
                <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-red-400 shrink-0">
                  {(profile?.name || user?.email || 'S').charAt(0).toUpperCase()}
                </div>
                <div className="truncate text-left">
                  <p className="text-xs font-semibold text-white truncate">
                    {profile?.name || 'Staff Member'}
                  </p>
                  <p className="text-[11px] text-slate-400 truncate">{user?.email || ''}</p>
                </div>
              </div>
            )}
            <button
              onClick={signOut}
              title="Sign Out"
              className="p-2 text-slate-400 hover:text-rose-400 hover:bg-slate-800 rounded-lg transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>
    );
  };

  return (
    <>
      {/* Desktop Sidebar */}
      <div className="hidden lg:flex h-full">{renderSidebarContent(false)}</div>

      {/* Mobile Slide-Over Drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden flex">
          <div
            className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs"
            onClick={onCloseMobile}
          />
          <div className="relative z-10 h-full">{renderSidebarContent(true)}</div>
        </div>
      )}
    </>
  );
};
