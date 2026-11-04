// admin_panel/src/components/dashboard/PendingReportsWidget.tsx
import React from 'react';
import { ShieldAlert, ArrowRight, CheckCircle2 } from 'lucide-react';
import type { ReportItem } from '../../types';

interface PendingReportsWidgetProps {
  reports: ReportItem[];
  onViewAll: () => void;
  onResolve: (reportId: string, action: 'dismiss' | 'action_taken', targetId: string) => void;
}

export const PendingReportsWidget: React.FC<PendingReportsWidgetProps> = ({
  reports,
  onViewAll,
  onResolve,
}) => {
  const pendingReports = reports.filter((r) => r.status === 'pending').slice(0, 5);

  return (
    <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-xs flex flex-col h-full">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-xl bg-amber-50 text-amber-600">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-base font-bold text-slate-900">Moderation Queue</h3>
            <p className="text-xs text-slate-500">Active flags and community reports requiring review</p>
          </div>
        </div>
        <button
          onClick={onViewAll}
          className="text-xs font-bold text-red-600 hover:text-red-700 flex items-center gap-1 hover:underline"
        >
          View All <ArrowRight className="w-3.5 h-3.5" />
        </button>
      </div>

      <div className="flex-1 space-y-3 overflow-y-auto">
        {pendingReports.length === 0 ? (
          <div className="py-10 text-center text-slate-400 text-sm flex flex-col items-center">
            <CheckCircle2 className="w-8 h-8 text-emerald-500 mb-2" />
            Moderation queue is empty. Platform is running clean!
          </div>
        ) : (
          pendingReports.map((report) => (
            <div
              key={report.id}
              className="p-3.5 rounded-xl border border-slate-200 bg-slate-50/50 flex items-center justify-between gap-3"
            >
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-slate-900">{report.reason}</span>
                  <span className="text-[10px] uppercase font-bold px-1.5 py-0.5 rounded-sm bg-slate-200 text-slate-700">
                    {report.reported_type}
                  </span>
                </div>
                {report.details && (
                  <p className="text-xs text-slate-500 truncate mt-0.5 max-w-xs">{report.details}</p>
                )}
              </div>

              <div className="flex items-center gap-2 shrink-0">
                <button
                  onClick={() => onResolve(report.id, 'dismiss', report.target_id)}
                  className="px-2.5 py-1 text-xs font-semibold text-slate-600 hover:text-slate-900 bg-white border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors"
                >
                  Dismiss
                </button>
                <button
                  onClick={() => onResolve(report.id, 'action_taken', report.target_id)}
                  className="px-2.5 py-1 text-xs font-semibold text-white bg-rose-600 rounded-lg hover:bg-rose-700 shadow-xs transition-colors"
                >
                  Take Action
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
