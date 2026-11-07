// admin_panel/src/components/layout/Header.tsx
import React, { useState, useRef, useEffect } from 'react';
import {
  Bell,
  RefreshCw,
  Radio,
  Menu,
  ShieldCheck,
  UserX,
  AlertTriangle,
  ShieldAlert,
  CheckCheck,
  Clock,
  ChevronRight,
} from 'lucide-react';
import type { NavigationTab } from './Sidebar';
import type { NotificationItem } from '../../types';

interface HeaderProps {
  currentTab: NavigationTab;
  onSelectTab?: (tab: NavigationTab) => void;
  onRefresh?: () => void;
  isRefreshing?: boolean;
  totalAlerts?: number;
  pendingVerificationsCount?: number;
  pendingDeletionRequestsCount?: number;
  criticalRequestsCount?: number;
  pendingReportsCount?: number;
  notifications?: NotificationItem[];
  onMarkNotificationRead?: (id: string) => void;
  onMarkAllNotificationsRead?: () => void;
  onOpenMobileMenu?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  currentTab,
  onSelectTab,
  onRefresh,
  isRefreshing = false,
  totalAlerts = 0,
  pendingVerificationsCount = 0,
  pendingDeletionRequestsCount = 0,
  criticalRequestsCount = 0,
  pendingReportsCount = 0,
  notifications = [],
  onMarkNotificationRead,
  onMarkAllNotificationsRead,
  onOpenMobileMenu,
}) => {
  const [notifOpen, setNotifOpen] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (popoverRef.current && !popoverRef.current.contains(e.target as Node)) {
        setNotifOpen(false);
      }
    };
    if (notifOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [notifOpen]);

  const titles: Record<NavigationTab, { title: string; desc: string }> = {
    dashboard: {
      title: 'Operations Dashboard',
      desc: 'Real-time overview of blood requests, donor availability, and system metrics.',
    },
    donors: {
      title: 'Donor & User Management',
      desc: 'Verify laboratory blood certificates, approve account deletion requests, and manage roles.',
    },
    requests: {
      title: 'Blood Requests & Emergency Dispatch',
      desc: 'Track urgent transfusions, coordinate donor offers atomically, and monitor live donor GPS.',
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
  const unreadNotifsCount = notifications.filter((n) => !n.is_read).length;
  const combinedBadgeCount = totalAlerts + unreadNotifsCount;

  const handleNavigateFromAlert = (tab: NavigationTab) => {
    if (onSelectTab) onSelectTab(tab);
    setNotifOpen(false);
  };

  return (
    <header className="min-h-16 sm:h-20 bg-white border-b border-slate-200 px-4 sm:px-8 py-3 flex items-center justify-between gap-3 shrink-0 relative z-30">
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
          <p className="hidden sm:block text-xs text-slate-500 font-medium truncate">
            {current.desc}
          </p>
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

        {/* Interactive Staff Notifications & Triage Bell */}
        <div className="relative" ref={popoverRef}>
          <button
            type="button"
            onClick={() => setNotifOpen((prev) => !prev)}
            title="Staff Notifications & Action Queue"
            className={`p-2.5 rounded-xl border transition-all relative ${
              notifOpen
                ? 'bg-red-50 border-red-200 text-red-600'
                : 'text-slate-600 bg-slate-50 border-slate-200 hover:bg-slate-100 hover:text-slate-900'
            }`}
          >
            <Bell className="w-4 h-4" />
            {combinedBadgeCount > 0 && (
              <span className="absolute -top-1.5 -right-1.5 min-w-5 h-5 px-1 bg-rose-600 text-white rounded-full text-[10px] font-bold flex items-center justify-center ring-2 ring-white">
                {combinedBadgeCount > 99 ? '99+' : combinedBadgeCount}
              </span>
            )}
          </button>

          {notifOpen && (
            <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-white rounded-2xl shadow-2xl border border-slate-200 overflow-hidden z-50 animate-in fade-in slide-in-from-top-2 duration-150">
              <div className="p-4 bg-slate-900 text-white flex items-center justify-between">
                <div>
                  <h3 className="text-xs font-black uppercase tracking-wider">
                    Staff Alert & Notification Center
                  </h3>
                  <p className="text-[11px] text-slate-400 mt-0.5">
                    {totalAlerts} queued triage item(s) • {unreadNotifsCount} unread alert(s)
                  </p>
                </div>
                {unreadNotifsCount > 0 && onMarkAllNotificationsRead && (
                  <button
                    type="button"
                    onClick={onMarkAllNotificationsRead}
                    className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-[11px] font-bold text-emerald-400 transition-colors"
                  >
                    <CheckCheck className="w-3.5 h-3.5" />
                    Mark All Read
                  </button>
                )}
              </div>

              {/* Live Operational Action Queue */}
              <div className="p-3 bg-slate-50 border-b border-slate-200 space-y-1.5">
                <div className="text-[10px] font-black uppercase tracking-wider text-slate-400 px-1">
                  Live Triage Queues
                </div>
                <div className="grid grid-cols-2 gap-1.5">
                  <button
                    type="button"
                    onClick={() => handleNavigateFromAlert('donors')}
                    className={`p-2.5 rounded-xl border text-left transition-all flex items-center justify-between ${
                      pendingDeletionRequestsCount > 0
                        ? 'bg-rose-50 border-rose-200 text-rose-900 hover:bg-rose-100'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-1 text-[11px] font-bold">
                        <UserX className="w-3.5 h-3.5 text-rose-600 shrink-0" />
                        <span className="truncate">Deletions</span>
                      </div>
                      <div className="text-sm font-black mt-0.5">
                        {pendingDeletionRequestsCount}
                      </div>
                    </div>
                    <ChevronRight className="w-3.5 h-3.5 opacity-50 shrink-0" />
                  </button>

                  <button
                    type="button"
                    onClick={() => handleNavigateFromAlert('donors')}
                    className={`p-2.5 rounded-xl border text-left transition-all flex items-center justify-between ${
                      pendingVerificationsCount > 0
                        ? 'bg-amber-50 border-amber-200 text-amber-900 hover:bg-amber-100'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-1 text-[11px] font-bold">
                        <ShieldCheck className="w-3.5 h-3.5 text-amber-600 shrink-0" />
                        <span className="truncate">Lab Reviews</span>
                      </div>
                      <div className="text-sm font-black mt-0.5">{pendingVerificationsCount}</div>
                    </div>
                    <ChevronRight className="w-3.5 h-3.5 opacity-50 shrink-0" />
                  </button>

                  <button
                    type="button"
                    onClick={() => handleNavigateFromAlert('requests')}
                    className={`p-2.5 rounded-xl border text-left transition-all flex items-center justify-between ${
                      criticalRequestsCount > 0
                        ? 'bg-red-50 border-red-200 text-red-900 hover:bg-red-100'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-1 text-[11px] font-bold">
                        <AlertTriangle className="w-3.5 h-3.5 text-red-600 shrink-0" />
                        <span className="truncate">Critical SOS</span>
                      </div>
                      <div className="text-sm font-black mt-0.5">{criticalRequestsCount}</div>
                    </div>
                    <ChevronRight className="w-3.5 h-3.5 opacity-50 shrink-0" />
                  </button>

                  <button
                    type="button"
                    onClick={() => handleNavigateFromAlert('reports')}
                    className={`p-2.5 rounded-xl border text-left transition-all flex items-center justify-between ${
                      pendingReportsCount > 0
                        ? 'bg-purple-50 border-purple-200 text-purple-900 hover:bg-purple-100'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-1 text-[11px] font-bold">
                        <ShieldAlert className="w-3.5 h-3.5 text-purple-600 shrink-0" />
                        <span className="truncate">Moderation</span>
                      </div>
                      <div className="text-sm font-black mt-0.5">{pendingReportsCount}</div>
                    </div>
                    <ChevronRight className="w-3.5 h-3.5 opacity-50 shrink-0" />
                  </button>
                </div>
              </div>

              {/* Staff Notifications Feed */}
              <div className="max-h-72 overflow-y-auto divide-y divide-slate-100">
                {notifications.length === 0 ? (
                  <div className="p-6 text-center text-xs text-slate-400">
                    No direct notifications yet. Real-time system events will appear here.
                  </div>
                ) : (
                  notifications.slice(0, 20).map((n) => (
                    <div
                      key={n.id}
                      onClick={() => {
                        if (!n.is_read && onMarkNotificationRead) {
                          onMarkNotificationRead(n.id);
                        }
                        if (n.type?.includes('deletion') || n.type?.includes('verification')) {
                          handleNavigateFromAlert('donors');
                        } else if (n.type?.includes('request')) {
                          handleNavigateFromAlert('requests');
                        } else if (n.type?.includes('report')) {
                          handleNavigateFromAlert('reports');
                        }
                      }}
                      className={`p-3.5 text-xs cursor-pointer transition-colors hover:bg-slate-50 flex items-start gap-2.5 ${
                        !n.is_read ? 'bg-red-50/40' : 'bg-white'
                      }`}
                    >
                      <div
                        className={`w-2 h-2 rounded-full mt-1.5 shrink-0 ${
                          !n.is_read ? 'bg-red-600' : 'bg-slate-300'
                        }`}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="font-bold text-slate-900 truncate">{n.title}</div>
                        <p className="text-slate-600 text-[11px] mt-0.5 line-clamp-2">{n.body}</p>
                        {n.created_at && (
                          <div className="flex items-center gap-1 text-[10px] text-slate-400 mt-1">
                            <Clock className="w-3 h-3" />
                            <span>{new Date(n.created_at).toLocaleString()}</span>
                          </div>
                        )}
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};
