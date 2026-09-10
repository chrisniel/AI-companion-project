import React from 'react';
import { AlertTriangle, Trash2 } from 'lucide-react';
import { Modal } from '../../ui/Modal';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { MemoryEntry } from '../../../types';

export interface MemoryDeleteConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  memory: MemoryEntry | null;
}

export const MemoryDeleteConfirmModal: React.FC<MemoryDeleteConfirmModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  memory,
}) => {
  if (!memory) return null;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Delete Memory Record"
      size="sm"
    >
      <div className="space-y-4">
        <div className="flex items-start gap-3 p-3.5 rounded-2xl surface-recessed border border-rose-500/20 text-xs text-[var(--color-text-secondary)]">
          <AlertTriangle className="w-5 h-5 text-rose-500 flex-shrink-0 mt-0.5" />
          <div>
            <p className="font-semibold text-[var(--color-text-primary)]">
              This action will remove the vector embedding.
            </p>
            <p className="mt-1 leading-relaxed">
              The assistant will no longer retrieve this record during semantic queries.
            </p>
          </div>
        </div>

        <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] line-clamp-3 italic">
          "{memory.content}"
        </div>

        <div className="flex items-center justify-end gap-3 pt-2">
          <NeumorphicButton variant="ghost" size="sm" onClick={onClose}>
            Cancel
          </NeumorphicButton>
          <NeumorphicButton
            variant="danger"
            size="sm"
            onClick={() => {
              onConfirm();
              onClose();
            }}
            icon={<Trash2 className="w-3.5 h-3.5" />}
          >
            Delete Permanently
          </NeumorphicButton>
        </div>
      </div>
    </Modal>
  );
};
