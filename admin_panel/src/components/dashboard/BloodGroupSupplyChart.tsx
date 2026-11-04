// admin_panel/src/components/dashboard/BloodGroupSupplyChart.tsx
import React from 'react';
import type { BloodGroup, BloodRequest, UserProfile } from '../../types';

interface BloodGroupSupplyChartProps {
  donors: UserProfile[];
  requests: BloodRequest[];
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

export const BloodGroupSupplyChart: React.FC<BloodGroupSupplyChartProps> = ({ donors, requests }) => {
  // Count available donors per group
  const donorCounts = BLOOD_GROUPS.reduce((acc, bg) => {
    acc[bg] = donors.filter((d) => d.blood_type === bg && d.is_available_to_donate).length;
    return acc;
  }, {} as Record<BloodGroup, number>);

  // Count open requests per group
  const requestCounts = BLOOD_GROUPS.reduce((acc, bg) => {
    acc[bg] = requests.filter(
      (r) => r.required_blood_type === bg && (r.status === 'Open' || r.status === 'Partially Fulfilled')
    ).length;
    return acc;
  }, {} as Record<BloodGroup, number>);

  // Find max value for bar scaling
  const maxVal = Math.max(
    ...Object.values(donorCounts),
    ...Object.values(requestCounts),
    5
  );

  return (
    <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-xs">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-base font-bold text-slate-900">Blood Type Supply & Demand</h3>
          <p className="text-xs text-slate-500">Available registered donors vs active hospital requests</p>
        </div>
        <div className="flex items-center gap-4 text-xs font-semibold">
          <div className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-sm bg-emerald-500"></span>
            <span className="text-slate-600">Active Donors</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-sm bg-rose-500"></span>
            <span className="text-slate-600">Pending Requests</span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-4 md:grid-cols-8 gap-3">
        {BLOOD_GROUPS.map((bg) => {
          const donorCount = donorCounts[bg];
          const requestCount = requestCounts[bg];
          const isShortage = requestCount > donorCount;
          const donorHeight = Math.round((donorCount / maxVal) * 100);
          const requestHeight = Math.round((requestCount / maxVal) * 100);

          return (
            <div
              key={bg}
              className={`flex flex-col items-center p-3 rounded-xl border transition-all ${
                isShortage
                  ? 'bg-rose-50/50 border-rose-200 ring-1 ring-rose-300'
                  : 'bg-slate-50/70 border-slate-200 hover:border-slate-300'
              }`}
            >
              <div className="font-extrabold text-sm text-slate-800 mb-2">{bg}</div>

              {/* Vertical Bars */}
              <div className="h-28 w-full flex items-end justify-center gap-1.5 pb-2">
                {/* Donors bar */}
                <div className="w-3.5 bg-slate-200 rounded-t-sm flex flex-col justify-end h-full">
                  <div
                    style={{ height: `${donorHeight}%` }}
                    className="w-full bg-emerald-500 rounded-t-sm transition-all duration-500 min-h-[4px]"
                    title={`${donorCount} available donors`}
                  />
                </div>
                {/* Requests bar */}
                <div className="w-3.5 bg-slate-200 rounded-t-sm flex flex-col justify-end h-full">
                  <div
                    style={{ height: `${requestHeight}%` }}
                    className="w-full bg-rose-500 rounded-t-sm transition-all duration-500 min-h-[4px]"
                    title={`${requestCount} open requests`}
                  />
                </div>
              </div>

              {/* Numbers */}
              <div className="w-full pt-2 border-t border-slate-200/60 flex justify-between text-[11px] font-bold">
                <span className="text-emerald-700" title="Donors">
                  {donorCount}
                </span>
                <span className="text-rose-600" title="Requests">
                  {requestCount}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
