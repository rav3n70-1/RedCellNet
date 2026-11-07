// admin_panel/src/pages/AnalyticsPage.tsx
import React, { useMemo } from 'react';
import {
  BarChart3,
  CheckCircle2,
  MapPin,
  ShieldCheck,
  AlertTriangle,
  Droplets,
} from 'lucide-react';
import type { BloodGroup, BloodRequest, DonationCenter, UserProfile } from '../types';
import { BloodGroupBadge } from '../components/common/Badge';

interface AnalyticsPageProps {
  donors: UserProfile[];
  requests: BloodRequest[];
  facilities: DonationCenter[];
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

export const AnalyticsPage: React.FC<AnalyticsPageProps> = ({
  donors,
  requests,
  facilities,
}) => {
  // 1. Blood group demand vs supply matrix
  const matrix = useMemo(() => {
    return BLOOD_GROUPS.map((bg) => {
      const totalDonors = donors.filter((d) => d.blood_type === bg && !d.is_banned).length;
      const availableDonors = donors.filter(
        (d) => d.blood_type === bg && Boolean(d.is_available_to_donate) && !d.is_banned
      ).length;
      const verifiedDonors = donors.filter(
        (d) => d.blood_type === bg && d.verification_status === 'verified' && !d.is_banned
      ).length;
      const activeRequests = requests.filter(
        (r) =>
          r.required_blood_type === bg &&
          (r.status === 'Open' || r.status === 'Partially Fulfilled')
      );
      const unitsNeeded = activeRequests.reduce((acc, r) => acc + (r.remaining_units || 0), 0);
      const centerInventoryUnits = facilities.reduce(
        (acc, f) => acc + (Number(f.blood_inventory?.[bg]) || 0),
        0
      );

      return {
        bloodGroup: bg,
        totalDonors,
        availableDonors,
        verifiedDonors,
        openRequestCount: activeRequests.length,
        unitsNeeded,
        centerInventoryUnits,
        isDeficit: unitsNeeded > availableDonors + centerInventoryUnits,
      };
    });
  }, [donors, requests, facilities]);

  // 2. Request Fulfillment Funnel
  const fulfillmentStats = useMemo(() => {
    const total = requests.length;
    const withOffers = requests.filter((r) => (r.offers?.length || 0) > 0).length;
    const partial = requests.filter((r) => r.status === 'Partially Fulfilled').length;
    const fulfilled = requests.filter((r) => r.status === 'Fulfilled').length;
    const expired = requests.filter((r) => r.status === 'Expired').length;
    const cancelled = requests.filter((r) => r.status === 'Cancelled').length;
    const rate = total > 0 ? Math.round((fulfilled / total) * 100) : 0;
    return { total, withOffers, partial, fulfilled, expired, cancelled, rate };
  }, [requests]);

  // 3. Donor Verification Funnel
  const donorFunnel = useMemo(() => {
    const total = donors.length;
    const bloodDeclared = donors.filter((d) => Boolean(d.blood_type)).length;
    const docSubmitted = donors.filter(
      (d) => d.verification_status === 'pending' || d.verification_status === 'verified'
    ).length;
    const verified = donors.filter((d) => d.verification_status === 'verified').length;
    const availableNow = donors.filter(
      (d) => Boolean(d.is_available_to_donate) && !d.is_banned
    ).length;
    return { total, bloodDeclared, docSubmitted, verified, availableNow };
  }, [donors]);

  // 4. City Request Distribution
  const cityStats = useMemo(() => {
    const map = new Map<string, { total: number; active: number; fulfilled: number }>();
    for (const r of requests) {
      const city = (r.city || 'Unspecified').trim() || 'Unspecified';
      const entry = map.get(city) || { total: 0, active: 0, fulfilled: 0 };
      entry.total += 1;
      if (r.status === 'Open' || r.status === 'Partially Fulfilled') entry.active += 1;
      if (r.status === 'Fulfilled') entry.fulfilled += 1;
      map.set(city, entry);
    }
    return Array.from(map.entries())
      .map(([city, stats]) => ({ city, ...stats }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 10);
  }, [requests]);

  return (
    <div className="space-y-6">
      {/* Top Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-slate-400">
            <span>Overall Fulfillment Rate</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-3xl font-black text-slate-900 mt-2">{fulfillmentStats.rate}%</div>
          <p className="text-xs text-slate-500 mt-1">
            {fulfillmentStats.fulfilled} fulfilled out of {fulfillmentStats.total} total requests
          </p>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-slate-400">
            <span>Verified Donor Share</span>
            <ShieldCheck className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-3xl font-black text-slate-900 mt-2">
            {donorFunnel.total > 0
              ? Math.round((donorFunnel.verified / donorFunnel.total) * 100)
              : 0}
            %
          </div>
          <p className="text-xs text-slate-500 mt-1">
            {donorFunnel.verified} shield-verified of {donorFunnel.total} users
          </p>
        </div>

        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-slate-400">
            <span>Shortage Alert Groups</span>
            <AlertTriangle className="w-4 h-4 text-rose-600" />
          </div>
          <div className="text-3xl font-black text-slate-900 mt-2">
            {matrix.filter((m) => m.isDeficit).length}
          </div>
          <p className="text-xs text-slate-500 mt-1">
            Blood groups where open unit demand exceeds active supply
          </p>
        </div>
      </div>

      {/* Blood Group Supply vs Demand Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div>
            <h3 className="text-base font-bold text-slate-900 flex items-center gap-2">
              <Droplets className="w-4 h-4 text-red-600" />
              Blood Group Supply vs Hospital Demand Matrix
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Live comparison of available community donors, blood bank stock, and open transfusion
              requests.
            </p>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase font-bold text-[11px]">
              <tr>
                <th className="py-3 px-5">Blood Group</th>
                <th className="py-3 px-4">Registered Donors</th>
                <th className="py-3 px-4">Verified Donors</th>
                <th className="py-3 px-4">Available Now</th>
                <th className="py-3 px-4">Center Stock (Units)</th>
                <th className="py-3 px-4">Open Requests</th>
                <th className="py-3 px-4">Units Needed</th>
                <th className="py-3 px-5 text-right">Balance Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {matrix.map((row) => (
                <tr key={row.bloodGroup} className="hover:bg-slate-50/60">
                  <td className="py-3 px-5">
                    <BloodGroupBadge bloodType={row.bloodGroup} size="sm" />
                  </td>
                  <td className="py-3 px-4 font-semibold text-slate-700">{row.totalDonors}</td>
                  <td className="py-3 px-4 font-semibold text-emerald-700">{row.verifiedDonors}</td>
                  <td className="py-3 px-4 font-bold text-blue-700">{row.availableDonors}</td>
                  <td className="py-3 px-4 font-semibold text-slate-700">
                    {row.centerInventoryUnits}
                  </td>
                  <td className="py-3 px-4 font-semibold text-slate-800">{row.openRequestCount}</td>
                  <td className="py-3 px-4 font-extrabold text-rose-700">{row.unitsNeeded}</td>
                  <td className="py-3 px-5 text-right">
                    {row.isDeficit ? (
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-rose-100 text-rose-800 font-bold text-[11px]">
                        Shortage Alert
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 font-semibold text-[11px]">
                        Healthy Reserve
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Funnels + City Breakdown */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Funnels */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-xs space-y-6">
          <div>
            <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 mb-3">
              <BarChart3 className="w-4 h-4 text-red-600" />
              Donor Readiness Funnel
            </h3>
            <div className="space-y-2.5 text-xs">
              {[
                { label: 'Total Registered Users', val: donorFunnel.total },
                { label: 'Blood Group Declared', val: donorFunnel.bloodDeclared },
                { label: 'Verification Submitted / Approved', val: donorFunnel.docSubmitted },
                { label: 'Shield-Verified Donors', val: donorFunnel.verified },
                { label: 'Eligible & Available Today', val: donorFunnel.availableNow },
              ].map((step) => {
                const pct =
                  donorFunnel.total > 0 ? Math.round((step.val / donorFunnel.total) * 100) : 0;
                return (
                  <div key={step.label}>
                    <div className="flex justify-between font-semibold text-slate-700 mb-1">
                      <span>{step.label}</span>
                      <span>
                        {step.val} ({pct}%)
                      </span>
                    </div>
                    <div className="w-full h-2 bg-slate-100 rounded-full overflow-hidden">
                      <div
                        style={{ width: `${pct}%` }}
                        className="h-full bg-red-600 rounded-full transition-all"
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="pt-4 border-t border-slate-100">
            <h4 className="text-sm font-bold text-slate-900 mb-3">Request Outcome Breakdown</h4>
            <div className="grid grid-cols-3 gap-2.5 text-xs">
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200">
                <span className="text-slate-400 block">Received Offers</span>
                <span className="text-base font-black text-slate-900">
                  {fulfillmentStats.withOffers}
                </span>
              </div>
              <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200">
                <span className="text-emerald-700 block">Fulfilled</span>
                <span className="text-base font-black text-emerald-900">
                  {fulfillmentStats.fulfilled}
                </span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-50 border border-zinc-200">
                <span className="text-zinc-500 block">Expired / Cancelled</span>
                <span className="text-base font-black text-zinc-800">
                  {fulfillmentStats.expired + fulfillmentStats.cancelled}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Regional City Breakdown */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-xs">
          <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2 mb-4">
            <MapPin className="w-4 h-4 text-red-600" />
            Regional Request Distribution (Top Cities)
          </h3>

          {cityStats.length === 0 ? (
            <div className="py-12 text-center text-xs text-slate-400">
              No regional request data recorded yet.
            </div>
          ) : (
            <div className="space-y-3">
              {cityStats.map((item) => (
                <div
                  key={item.city}
                  className="p-3.5 rounded-xl border border-slate-200 bg-slate-50/50 flex items-center justify-between text-xs"
                >
                  <div>
                    <div className="font-bold text-slate-900">{item.city}</div>
                    <div className="text-[11px] text-slate-500 mt-0.5">
                      {item.active} active • {item.fulfilled} fulfilled
                    </div>
                  </div>
                  <span className="px-2.5 py-1 rounded-lg bg-white border border-slate-200 font-extrabold text-slate-800">
                    {item.total} total
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

