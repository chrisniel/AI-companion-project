import React from 'react';
import {
  User,
  HeartHandshake,
  BookOpen,
  FolderGit2,
  Calendar,
  Clock,
  Edit3,
  Trash2,
} from 'lucide-react';
import { MemoryEntry, MemoryCategory } from '../../../types';

export interface MemoryItemCardProps {
  memory: MemoryEntry;
  onEdit: (memory: MemoryEntry) => void;
  onDelete: (id: string) => void;
}

export const MemoryItemCard: React.FC<MemoryItemCardProps> = ({
  memory,
  onEdit,
  onDelete,
}) => {
  const getCategoryConfig = (cat: MemoryCategory) => {
    switch (cat) {
      case 'Profile':
        return {
          icon: <User className="w-3.5 h-3.5" />,
          colorClass: 'text-purple-400 border-purple-400/30 bg-purple-500/10',
          label: 'Profile / Context',
        };
      case 'Preference':
        return {
          icon: <HeartHandshake className="w-3.5 h-3.5" />,
          colorClass: 'text-cyan-400 border-cyan-400/30 bg-cyan-500/10',
          label: 'Preference',
        };
      case 'Fact':
      default:
        return {
          icon: <BookOpen className="w-3.5 h-3.5" />,
          colorClass: 'text-emerald-400 border-emerald-400/30 bg-emerald-500/10',
          label: 'Fact',
        };
    }
  };

  const catConfig = getCategoryConfig(memory.category);
  const importanceVal = typeof memory.importance === 'number' ? memory.importance : 1.0;

  return (
    <article
      id={`memory-card-${memory.id}`}
      className="rounded-2xl border transition-all duration-150 p-4 sm:p-5 flex flex-col justify-between surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] shadow-xs"
    >
      <div className="space-y-3">
        {/* Top bar: Category Badge + Source + Importance */}
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2 flex-wrap">
            {/* Category badge */}
            <span
              className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold border ${catConfig.colorClass}`}
            >
              {catConfig.icon}
              <span>{catConfig.label}</span>
            </span>

            {/* Source indicator */}
            <span className="text-xs text-[var(--color-text-secondary)] font-medium flex items-center gap-1">
              <span className="text-[var(--color-text-muted)] font-mono text-[11px]">via</span>
              <span className="truncate max-w-[220px]" title={memory.source}>
                {memory.source}
              </span>
            </span>
          </div>

          <div className="flex items-center gap-2">
            {/* Importance metric indicator */}
            <div
              className="flex items-center gap-1 text-xs font-mono px-2 py-0.5 rounded-md surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-accent)]"
              title={`Memory Importance Weight: ${importanceVal.toFixed(1)}`}
            >
              <span>Importance: {importanceVal.toFixed(1)}</span>
            </div>
          </div>
        </div>

        {/* Content: Clean, high-contrast, comfortable line-height */}
        <div className="py-1">
          <p className="text-sm sm:text-base text-[var(--color-text-primary)] leading-relaxed font-normal select-text">
            {memory.content}
          </p>
        </div>
      </div>

      {/* Bottom Bar: Timestamp and Actions (Edit, Delete) */}
      <div className="pt-3 mt-3 border-t border-[var(--color-border-subtle)] flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--color-text-muted)] font-mono">
        <div className="flex items-center gap-1.5">
          <Clock className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
          <span>Created {memory.createdAt || memory.lastUpdated}</span>
        </div>

        {/* Action Controls: Edit, Delete */}
        <div className="flex items-center gap-1.5">
          <button
            onClick={() => onEdit(memory)}
            className="px-2.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] hover:border-[var(--color-accent)] flex items-center gap-1.5 transition-all cursor-pointer"
            title="Edit memory content or category"
          >
            <Edit3 className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>Edit</span>
          </button>

          <button
            onClick={() => onDelete(memory.id)}
            className="px-2.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-rose-400 hover:border-rose-500/40 hover:bg-rose-500/10 flex items-center gap-1.5 transition-all cursor-pointer"
            title="Delete this memory record"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Delete</span>
          </button>
        </div>
      </div>
    </article>
  );
};
