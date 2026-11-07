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
  criticalRequestsCount?: number;
  pendingReportsCount?: number;
  mobileOpen?: boolean;
  onCloseMobile?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  pendingVerificationsCount = 0,
  criticalRequestsCount = 0,
  pendingReportsCount = 0,
  mobileOpen = false,
  onCloseMobile,
}) => {
  const { user, profile, signOut } = useAuth();

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
      badge: pendingVerificationsCount > 0 ? pendingVerificationsCount : undefined,
      badgeColor: 'bg-amber-500 text-white',
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

  const sidebarContent = (
    <aside className="w-64 bg-slate-900 text-slate-300 flex flex-col shrink-0 h-full border-r border-slate-800 select-none">
      {/* Brand Header */}
      <div className="p-6 border-b border-slate-800/80 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-red-600 to-rose-500 flex items-center justify-center text-white shadow-lg shadow-red-900/40">
            <Activity className="w-6 h-6 stroke-[2.5]" />
          </div>
          <div>
            <h1 className="text-base font-extrabold text-white tracking-tight flex items-center gap-1.5">
              RedCellNet
              <span className="text-[10px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded-sm bg-red-500/20 text-red-400 border border-red-500/30">
                {roleBadgeLabel}
              </span>
            </h1>
            <p className="text-[11px] text-slate-400 font-medium">Emergency Blood Hub</p>
          </div>
        </div>
        {onCloseMobile && (
          <button
            type="button"
            onClick={onCloseMobile}
            className="lg:hidden p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg"
            aria-label="Close navigation menu"
          >
            <X className="w-5 h-5" />
          </button>
        )}
      </div>

      {/* Navigation List */}
      <nav className="flex-1 px-3 py-5 space-y-1 overflow-y-auto">
        <div className="px-3 pb-2 text-[11px] font-bold uppercase tracking-wider text-slate-500">
          Operations & Governance
        </div>
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => handleSelect(item.id)}
              className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl font-medium text-sm transition-all duration-150 group ${
                isActive
                  ? 'bg-red-600 text-white shadow-md shadow-red-900/30 font-semibold'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <div className="flex items-center gap-3">
                <Icon
                  className={`w-5 h-5 transition-colors ${
                    isActive ? 'text-white' : 'text-slate-400 group-hover:text-slate-200'
                  }`}
                />
                <span>{item.label}</span>
              </div>
              {item.badge !== undefined && (
                <span
                  className={`text-[11px] font-bold px-2 py-0.5 rounded-full shadow-xs ${
                    isActive ? 'bg-white/20 text-white' : item.badgeColor || 'bg-slate-700 text-slate-300'
                  }`}
                >
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* User & Sign Out Footer */}
      <div className="p-4 border-t border-slate-800/80 bg-slate-950/40">
        <div className="flex items-center justify-between">
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
          <button
            onClick={signOut}
            title="Sign Out"
            className="p-1.5 text-slate-400 hover:text-rose-400 hover:bg-slate-800 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );

  return (
    <>
      {/* Desktop Sidebar */}
      <div className="hidden lg:flex h-full">{sidebarContent}</div>

      {/* Mobile Slide-Over Drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden flex">
          <div
            className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs"
            onClick={onCloseMobile}
          />
          <div className="relative z-10 h-full">{sidebarContent}</div>
        </div>
      )}
    </>
  );
};
