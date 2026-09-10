import React from 'react';
import {
  User,
  HeartHandshake,
  BookOpen,
  FolderGit2,
  Calendar,
  Clock,
  Edit3,
  Archive,
  ArchiveRestore,
  Trash2,
  Sparkles,
  ShieldCheck,
  Tag,
  ExternalLink,
} from 'lucide-react';
import { MemoryEntry, MemoryCategory } from '../../../types';
import { Badge } from '../../ui/Badge';
import { NeumorphicButton } from '../../ui/NeumorphicButton';

export interface MemoryItemCardProps {
  memory: MemoryEntry;
  onEdit: (memory: MemoryEntry) => void;
  onToggleArchive: (id: string) => void;
  onDelete: (id: string) => void;
}

export const MemoryItemCard: React.FC<MemoryItemCardProps> = ({
  memory,
  onEdit,
  onToggleArchive,
  onDelete,
}) => {
  const getCategoryConfig = (cat: MemoryCategory) => {
    switch (cat) {
      case 'Profile':
        return {
          icon: <User className="w-3.5 h-3.5" />,
          colorClass: 'text-purple-400 border-purple-400/30 bg-purple-500/10',
          label: 'Profile',
        };
      case 'Preference':
        return {
          icon: <HeartHandshake className="w-3.5 h-3.5" />,
          colorClass: 'text-cyan-400 border-cyan-400/30 bg-cyan-500/10',
          label: 'Preference',
        };
      case 'Fact':
        return {
          icon: <BookOpen className="w-3.5 h-3.5" />,
          colorClass: 'text-emerald-400 border-emerald-400/30 bg-emerald-500/10',
          label: 'Fact',
        };
      case 'Project':
        return {
          icon: <FolderGit2 className="w-3.5 h-3.5" />,
          colorClass: 'text-amber-400 border-amber-400/30 bg-amber-500/10',
          label: 'Project',
        };
      case 'Event':
        return {
          icon: <Calendar className="w-3.5 h-3.5" />,
          colorClass: 'text-blue-400 border-blue-400/30 bg-blue-500/10',
          label: 'Event',
        };
      case 'Temporary':
        return {
          icon: <Clock className="w-3.5 h-3.5" />,
          colorClass: 'text-rose-400 border-rose-400/30 bg-rose-500/10',
          label: 'Temporary',
        };
    }
  };

  const catConfig = getCategoryConfig(memory.category);
  const confidencePercent = Math.round(memory.confidence * 100);

  const getConfidenceBadgeColor = (percent: number) => {
    if (percent >= 95) return 'text-emerald-400 border-emerald-500/30';
    if (percent >= 85) return 'text-[var(--color-accent)] border-[var(--color-accent)]/30';
    return 'text-amber-400 border-amber-500/30';
  };

  return (
    <article
      id={`memory-card-${memory.id}`}
      className={`rounded-2xl border transition-all duration-150 p-4 sm:p-5 flex flex-col justify-between ${
        memory.isArchived
          ? 'surface-base opacity-70 border-[var(--color-border-subtle)] bg-[var(--color-surface)]/60'
          : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] shadow-xs'
      }`}
    >
      <div className="space-y-3">
        {/* Top bar: Category Badge + Source + Confidence + Archive Flag */}
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
            {/* Confidence metric indicator */}
            <div
              className={`flex items-center gap-1 text-xs font-mono px-2 py-0.5 rounded-md surface-recessed border ${getConfidenceBadgeColor(
                confidencePercent
              )}`}
              title={`Vector Retrieval Confidence: ${confidencePercent}%`}
            >
              <Sparkles className="w-3 h-3 text-[var(--color-accent)]" />
              <span>{confidencePercent}% conf</span>
            </div>

            {memory.isArchived && (
              <Badge variant="neutral" size="sm">
                Archived
              </Badge>
            )}
          </div>
        </div>

        {/* Content: Clean, high-contrast, comfortable line-height (Anti-slop & high readability) */}
        <div className="py-1">
          <p className="text-sm sm:text-base text-[var(--color-text-primary)] leading-relaxed font-normal select-text">
            {memory.content}
          </p>
        </div>

        {/* Tags if present */}
        {memory.tags && memory.tags.length > 0 && (
          <div className="flex items-center gap-1.5 flex-wrap pt-0.5">
            {memory.tags.map((tag) => (
              <span
                key={tag}
                className="text-[11px] font-mono px-2 py-0.5 rounded-md surface-recessed text-[var(--color-text-muted)] border border-[var(--color-border-subtle)] flex items-center gap-1"
              >
                <Tag className="w-2.5 h-2.5 opacity-60" />
                <span>{tag}</span>
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Bottom Bar: Timestamp and Actions (Edit, Archive, Delete) */}
      <div className="pt-3 mt-3 border-t border-[var(--color-border-subtle)] flex flex-wrap items-center justify-between gap-3 text-xs text-[var(--color-text-muted)] font-mono">
        <div className="flex items-center gap-1.5">
          <Clock className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
          <span>Updated {memory.lastUpdated}</span>
        </div>

        {/* Mock Controls: Edit, Archive, Delete */}
        <div className="flex items-center gap-1.5">
          <button
            onClick={() => onEdit(memory)}
            className="px-2.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] hover:border-[var(--color-accent)] flex items-center gap-1.5 transition-all cursor-pointer"
            title="Edit memory content or metadata"
          >
            <Edit3 className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>Edit</span>
          </button>

          <button
            onClick={() => onToggleArchive(memory.id)}
            className="px-2.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] hover:border-[var(--color-border-strong)] flex items-center gap-1.5 transition-all cursor-pointer"
            title={memory.isArchived ? 'Restore to active memory' : 'Archive this memory'}
          >
            {memory.isArchived ? (
              <>
                <ArchiveRestore className="w-3.5 h-3.5 text-emerald-400" />
                <span>Restore</span>
              </>
            ) : (
              <>
                <Archive className="w-3.5 h-3.5 text-[var(--color-text-secondary)]" />
                <span>Archive</span>
              </>
            )}
          </button>

          <button
            onClick={() => onDelete(memory.id)}
            className="px-2.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-rose-400 hover:border-rose-500/40 hover:bg-rose-500/10 flex items-center gap-1.5 transition-all cursor-pointer"
            title="Delete this memory"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Delete</span>
          </button>
        </div>
      </div>
    </article>
  );
};
