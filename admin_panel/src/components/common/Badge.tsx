// admin_panel/src/components/common/Badge.tsx
import React from 'react';
import type { BloodGroup, UrgencyLevel, RequestStatus, VerificationStatus } from '../../types';

export const BloodGroupBadge: React.FC<{
  bloodType?: BloodGroup | string | null;
  size?: 'sm' | 'md' | 'lg';
}> = ({ bloodType, size = 'md' }) => {
  const sizeClasses = {
    sm: 'text-xs px-2 py-0.5',
    md: 'text-xs px-2.5 py-1 font-bold',
    lg: 'text-sm px-3 py-1.5 font-black',
  };

  const normalized = (bloodType || '').trim();
  const isUnset = !normalized || normalized.toUpperCase() === 'N/A' || normalized.toUpperCase() === 'UNSET';

  if (isUnset) {
    return (
      <span
        className={`inline-flex items-center justify-center font-semibold rounded-lg bg-slate-100 text-slate-600 border border-slate-200 tracking-wide ${sizeClasses[size]}`}
      >
        Unset
      </span>
    );
  }

  return (
    <span
      className={`inline-flex items-center justify-center font-extrabold rounded-lg bg-red-100 text-red-700 border border-red-200 shadow-xs tracking-wider ${sizeClasses[size]}`}
    >
      <span className="w-1.5 h-1.5 rounded-full bg-red-500 mr-1.5"></span>
      {normalized}
    </span>
  );
};

export const UrgencyBadge: React.FC<{ level?: UrgencyLevel | string }> = ({ level = 'Medium' }) => {
  const styles: Record<string, string> = {
    Critical: 'bg-rose-600 text-white shadow-sm font-bold',
    High: 'bg-amber-100 text-amber-800 border border-amber-300 font-semibold',
    Medium: 'bg-blue-100 text-blue-800 border border-blue-200 font-medium',
    Low: 'bg-slate-100 text-slate-700 border border-slate-200 font-medium',
  };

  const currentStyle = styles[level] || styles.Medium;

  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs uppercase tracking-wider ${currentStyle}`}
    >
      {level}
    </span>
  );
};

export const StatusBadge: React.FC<{ status?: RequestStatus | string }> = ({ status = 'Open' }) => {
  const styles: Record<string, string> = {
    Open: 'bg-emerald-100 text-emerald-800 border-emerald-300',
    'Partially Fulfilled': 'bg-teal-100 text-teal-800 border-teal-300',
    Fulfilled: 'bg-blue-100 text-blue-800 border-blue-300',
    Cancelled: 'bg-slate-100 text-slate-600 border-slate-200',
    Expired: 'bg-zinc-100 text-zinc-600 border-zinc-300',
  };

  const style = styles[status] || 'bg-slate-100 text-slate-700 border-slate-200';

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-semibold border ${style}`}>
      {status}
    </span>
  );
};

export const VerificationBadge: React.FC<{
  status?: VerificationStatus | string | null;
  compact?: boolean;
}> = ({ status = 'unverified', compact = false }) => {
  const normalized = (status || 'unverified').toLowerCase();

  if (normalized === 'verified') {
    return (
      <span
        className={`inline-flex items-center rounded-md bg-emerald-50 text-emerald-700 border border-emerald-200 font-medium ${
          compact ? 'px-1.5 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
        }`}
      >
        <svg className="w-3.5 h-3.5 mr-1 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
          <path
            fillRule="evenodd"
            d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
            clipRule="evenodd"
          />
        </svg>
        Verified by RedCellNet
      </span>
    );
  }

  if (normalized === 'rejected') {
    return (
      <span
        className={`inline-flex items-center rounded-md bg-rose-50 text-rose-700 border border-rose-200 font-medium ${
          compact ? 'px-1.5 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
        }`}
      >
        <span className="w-1.5 h-1.5 rounded-full bg-rose-500 mr-1"></span>
        Rejected
      </span>
    );
  }

  if (normalized === 'pending') {
    return (
      <span
        className={`inline-flex items-center rounded-md bg-amber-50 text-amber-700 border border-amber-200 font-medium ${
          compact ? 'px-1.5 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
        }`}
      >
        <span className="w-1.5 h-1.5 rounded-full bg-amber-500 mr-1.5 animate-pulse"></span>
        Verification Pending
      </span>
    );
  }

  return (
    <span
      className={`inline-flex items-center rounded-md bg-slate-100 text-slate-600 border border-slate-200 font-medium ${
        compact ? 'px-1.5 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
      }`}
    >
      <span className="w-1.5 h-1.5 rounded-full bg-slate-400 mr-1.5"></span>
      Verification Pending
    </span>
  );
};
