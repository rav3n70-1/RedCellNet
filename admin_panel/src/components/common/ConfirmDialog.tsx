// admin_panel/src/components/common/ConfirmDialog.tsx
import React from 'react';
import { AlertTriangle } from 'lucide-react';
import { Modal } from './Modal';

interface ConfirmDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  isDestructive?: boolean;
  isLoading?: boolean;
}

export const ConfirmDialog: React.FC<ConfirmDialogProps> = ({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  isDestructive = true,
  isLoading = false,
}) => {
  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title} maxWidth="md">
      <div className="flex items-start gap-4">
        <div
          className={`p-3 rounded-full shrink-0 ${
            isDestructive ? 'bg-rose-100 text-rose-600' : 'bg-amber-100 text-amber-600'
          }`}
        >
          <AlertTriangle className="w-6 h-6" />
        </div>
        <div className="flex-1">
          <p className="text-sm text-slate-600 leading-relaxed">{message}</p>
        </div>
      </div>

      <div className="mt-6 flex justify-end gap-3 pt-4 border-t border-slate-100">
        <button
          type="button"
          disabled={isLoading}
          onClick={onClose}
          className="px-4 py-2 text-sm font-semibold text-slate-700 bg-white border border-slate-300 rounded-xl hover:bg-slate-50 transition-colors"
        >
          {cancelText}
        </button>
        <button
          type="button"
          disabled={isLoading}
          onClick={onConfirm}
          className={`px-4 py-2 text-sm font-semibold text-white rounded-xl shadow-xs transition-colors ${
            isDestructive
              ? 'bg-rose-600 hover:bg-rose-700 disabled:bg-rose-400'
              : 'bg-red-600 hover:bg-red-700 disabled:bg-red-400'
          }`}
        >
          {isLoading ? 'Processing...' : confirmText}
        </button>
      </div>
    </Modal>
  );
};
