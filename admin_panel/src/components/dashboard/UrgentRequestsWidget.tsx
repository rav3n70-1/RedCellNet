// admin_panel/src/components/dashboard/UrgentRequestsWidget.tsx
import React from 'react';
import { AlertCircle, Clock, MapPin, ArrowRight } from 'lucide-react';
import type { BloodRequest } from '../../types';
import { BloodGroupBadge, UrgencyBadge } from '../common/Badge';

interface UrgentRequestsWidgetProps {
  requests: BloodRequest[];
  onViewAll: () => void;
  onSelectRequest: (request: BloodRequest) => void;
}

export const UrgentRequestsWidget: React.FC<UrgentRequestsWidgetProps> = ({
  requests,
  onViewAll,
  onSelectRequest,
}) => {
  const urgentList = requests
    .filter(
      (r) =>
        (r.status === 'Open' || r.status === 'Partially Fulfilled') &&
        (r.urgency_level === 'Critical' || r.urgency_level === 'High')
    )
    .slice(0, 5);

  return (
    <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-xs flex flex-col h-full">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-xl bg-rose-50 text-rose-600">
            <AlertCircle className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-base font-bold text-slate-900">Urgent Emergencies</h3>
            <p className="text-xs text-slate-500">Critical blood requirements requiring immediate attention</p>
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
        {urgentList.length === 0 ? (
          <div className="py-10 text-center text-slate-400 text-sm">
            No critical emergencies at this time. All urgent requests resolved! 🎉
          </div>
        ) : (
          urgentList.map((req) => (
            <div
              key={req.id}
              onClick={() => onSelectRequest(req)}
              className="p-3.5 rounded-xl border border-slate-200 hover:border-red-300 hover:shadow-xs transition-all cursor-pointer bg-slate-50/50 flex items-center justify-between gap-3"
            >
              <div className="flex items-center gap-3 min-w-0">
                <BloodGroupBadge bloodType={req.required_blood_type} size="md" />
                <div className="min-w-0">
                  <h4 className="text-sm font-bold text-slate-900 truncate">{req.hospital_name}</h4>
                  <div className="flex items-center gap-3 text-xs text-slate-500 mt-0.5">
                    {req.city && (
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-slate-400" />
                        {req.city}
                      </span>
                    )}
                    <span className="flex items-center gap-1">
                      <Clock className="w-3 h-3 text-slate-400" />
                      {req.remaining_units} unit(s) needed
                    </span>
                  </div>
                </div>
              </div>
              <UrgencyBadge level={req.urgency_level} />
            </div>
          ))
        )}
      </div>
    </div>
  );
};
