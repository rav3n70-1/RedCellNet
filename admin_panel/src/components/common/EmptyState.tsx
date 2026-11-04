// admin_panel/src/components/common/EmptyState.tsx
import React from 'react';
import type { LucideIcon } from 'lucide-react';

interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  description: string;
  actionText?: string;
  onAction?: () => void;
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  icon: Icon,
  title,
  description,
  actionText,
  onAction,
}) => {
  return (
    <div className="flex flex-col items-center justify-center p-12 text-center bg-white rounded-2xl border border-dashed border-slate-300 my-4">
      <div className="p-4 bg-slate-100 rounded-full text-slate-500 mb-4">
        <Icon className="w-8 h-8" />
      </div>
      <h3 className="text-base font-bold text-slate-900 mb-1">{title}</h3>
      <p className="text-sm text-slate-500 max-w-sm mb-6 leading-relaxed">{description}</p>
      {actionText && onAction && (
        <button
          onClick={onAction}
          className="inline-flex items-center px-4 py-2 text-sm font-semibold text-white bg-red-600 rounded-xl hover:bg-red-700 shadow-xs transition-colors"
        >
          {actionText}
        </button>
      )}
    </div>
  );
};
