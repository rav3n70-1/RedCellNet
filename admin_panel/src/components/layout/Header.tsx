// admin_panel/src/components/layout/Header.tsx
import React from 'react';
import { Bell, RefreshCw, Radio, Menu } from 'lucide-react';
import type { NavigationTab } from './Sidebar';

interface HeaderProps {
  currentTab: NavigationTab;
  onRefresh?: () => void;
  isRefreshing?: boolean;
  totalAlerts?: number;
  onOpenMobileMenu?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  currentTab,
  onRefresh,
  isRefreshing = false,
  totalAlerts = 0,
  onOpenMobileMenu,
}) => {
  const titles: Record<NavigationTab, { title: string; desc: string }> = {
    dashboard: {
      title: 'Operations Dashboard',
      desc: 'Real-time overview of blood requests, donor availability, and system metrics.',
    },
    donors: {
      title: 'Donor & User Management',
      desc: 'Verify laboratory blood certificates, inspect user activity, and manage roles.',
    },
    requests: {
      title: 'Blood Requests & Emergency Dispatch',
      desc: 'Track urgent transfusions, coordinate donor offers atomically, and verify hospital cases.',
    },
    facilities: {
      title: 'Certified Blood Banks & Centers',
      desc: 'Manage verified hospital collection facilities, inventory levels, and coordinates.',
    },
    content: {
      title: 'Health Guides & Articles',
      desc: 'Publish and organize bilingual educational content with medical source attributions.',
    },
    reports: {
      title: 'Safety Reports & Moderation Queue',
      desc: 'Investigate community flags, inspect targets, and resolve reported content.',
    },
    broadcast: {
      title: 'Broadcast & Direct Notifications',
      desc: 'Dispatch targeted blood shortage banners or send direct notifications to users.',
    },
    analytics: {
      title: 'Platform Analytics & Supply Funnel',
      desc: 'Monitor blood group demand vs supply, fulfillment conversion, and regional volume.',
    },
    audit_logs: {
      title: 'Staff Governance & Audit Logs',
      desc: 'Immutable record of administrative verifications, role updates, and moderation actions.',
    },
  };

  const current = titles[currentTab];

  return (
    <header className="min-h-16 sm:h-20 bg-white border-b border-slate-200 px-4 sm:px-8 py-3 flex items-center justify-between gap-3 shrink-0">
      <div className="flex items-center gap-3 min-w-0">
        {onOpenMobileMenu && (
          <button
            type="button"
            onClick={onOpenMobileMenu}
            className="lg:hidden p-2 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-xl transition-colors shrink-0"
            aria-label="Open navigation menu"
          >
            <Menu className="w-5 h-5" />
          </button>
        )}
        <div className="min-w-0">
          <h2 className="text-base sm:text-xl font-extrabold text-slate-900 tracking-tight truncate">
            {current.title}
          </h2>
          <p className="hidden sm:block text-xs text-slate-500 font-medium truncate">{current.desc}</p>
        </div>
      </div>

      <div className="flex items-center gap-2 sm:gap-4 shrink-0">
        {/* Supabase Realtime Active Status */}
        <div className="hidden md:flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-semibold">
          <Radio className="w-3.5 h-3.5 animate-pulse text-emerald-500" />
          <span>Realtime Live</span>
        </div>

        {/* Refresh Button */}
        {onRefresh && (
          <button
            onClick={onRefresh}
            disabled={isRefreshing}
            title="Refresh Data"
            className="p-2.5 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-xl transition-all"
          >
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin text-red-600' : ''}`} />
          </button>
        )}

        {/* Alerts Bell */}
        <div className="relative">
          <div className="p-2.5 text-slate-600 rounded-xl bg-slate-50 border border-slate-200">
            <Bell className="w-4 h-4" />
          </div>
          {totalAlerts > 0 && (
            <span className="absolute -top-1 -right-1 w-5 h-5 bg-rose-600 text-white rounded-full text-[10px] font-bold flex items-center justify-center ring-2 ring-white">
              {totalAlerts > 99 ? '99+' : totalAlerts}
            </span>
          )}
        </div>
      </div>
    </header>
  );
};
