// admin_panel/src/components/common/StatCard.tsx
import React from 'react';
import type { LucideIcon } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: LucideIcon;
  color?: 'red' | 'blue' | 'emerald' | 'amber' | 'purple' | 'slate';
  trend?: {
    value: string;
    isPositive: boolean;
  };
  onClick?: () => void;
}

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  subtitle,
  icon: Icon,
  color = 'red',
  trend,
  onClick,
}) => {
  const colorMap = {
    red: {
      bg: 'bg-red-50 text-red-600 border-red-100',
      iconBg: 'bg-red-500 text-white shadow-red-200',
      border: 'hover:border-red-300',
    },
    blue: {
      bg: 'bg-blue-50 text-blue-600 border-blue-100',
      iconBg: 'bg-blue-500 text-white shadow-blue-200',
      border: 'hover:border-blue-300',
    },
    emerald: {
      bg: 'bg-emerald-50 text-emerald-600 border-emerald-100',
      iconBg: 'bg-emerald-500 text-white shadow-emerald-200',
      border: 'hover:border-emerald-300',
    },
    amber: {
      bg: 'bg-amber-50 text-amber-600 border-amber-100',
      iconBg: 'bg-amber-500 text-white shadow-amber-200',
      border: 'hover:border-amber-300',
    },
    purple: {
      bg: 'bg-purple-50 text-purple-600 border-purple-100',
      iconBg: 'bg-purple-500 text-white shadow-purple-200',
      border: 'hover:border-purple-300',
    },
    slate: {
      bg: 'bg-slate-50 text-slate-600 border-slate-100',
      iconBg: 'bg-slate-700 text-white shadow-slate-200',
      border: 'hover:border-slate-300',
    },
  };

  const scheme = colorMap[color];

  return (
    <div
      onClick={onClick}
      className={`bg-white rounded-2xl p-5 border border-slate-200 shadow-xs hover:shadow-md transition-all duration-200 ${
        onClick ? 'cursor-pointer ' + scheme.border : ''
      }`}
    >
      <div className="flex items-center justify-between">
        <span className="text-xs font-bold uppercase tracking-wider text-slate-500">{title}</span>
        <div className={`p-2.5 rounded-xl shadow-xs ${scheme.iconBg}`}>
          <Icon className="w-5 h-5" />
        </div>
      </div>

      <div className="mt-3 flex items-baseline gap-2">
        <span className="text-3xl font-black text-slate-900 tracking-tight">{value}</span>
        {trend && (
          <span
            className={`text-xs font-semibold px-1.5 py-0.5 rounded-md ${
              trend.isPositive ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'
            }`}
          >
            {trend.value}
          </span>
        )}
      </div>

      {subtitle && <p className="mt-1 text-xs text-slate-500 font-medium">{subtitle}</p>}
    </div>
  );
};
