import React, { useState, useEffect } from 'react';
import {
  Brain,
  X,
  Check,
  Tag,
  Sparkles,
  User,
  HeartHandshake,
  BookOpen,
  FolderGit2,
  Calendar,
  Clock,
} from 'lucide-react';
import { MemoryEntry, MemoryCategory } from '../../../types';
import { Modal } from '../../ui/Modal';
import { NeumorphicButton } from '../../ui/NeumorphicButton';

export interface MemoryEditorModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (memory: Partial<MemoryEntry>) => void;
  memoryToEdit?: MemoryEntry | null;
}

const CATEGORIES: { id: MemoryCategory; label: string; icon: React.ReactNode }[] = [
  { id: 'Profile', label: 'Profile', icon: <User className="w-3.5 h-3.5" /> },
  { id: 'Preference', label: 'Preference', icon: <HeartHandshake className="w-3.5 h-3.5" /> },
  { id: 'Fact', label: 'Fact', icon: <BookOpen className="w-3.5 h-3.5" /> },
  { id: 'Project', label: 'Project', icon: <FolderGit2 className="w-3.5 h-3.5" /> },
  { id: 'Event', label: 'Event', icon: <Calendar className="w-3.5 h-3.5" /> },
  { id: 'Temporary', label: 'Temporary', icon: <Clock className="w-3.5 h-3.5" /> },
];

export const MemoryEditorModal: React.FC<MemoryEditorModalProps> = ({
  isOpen,
  onClose,
  onSave,
  memoryToEdit,
}) => {
  const [content, setContent] = useState('');
  const [category, setCategory] = useState<MemoryCategory>('Preference');
  const [source, setSource] = useState('');
  const [confidence, setConfidence] = useState(0.95);
  const [tagsString, setTagsString] = useState('');

  useEffect(() => {
    if (memoryToEdit) {
      setContent(memoryToEdit.content);
      setCategory(memoryToEdit.category);
      setSource(memoryToEdit.source);
      setConfidence(memoryToEdit.confidence);
      setTagsString(memoryToEdit.tags?.join(', ') || '');
    } else {
      setContent('');
      setCategory('Preference');
      setSource('Direct User Input');
      setConfidence(0.95);
      setTagsString('');
    }
  }, [memoryToEdit, isOpen]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim()) return;

    const tags = tagsString
      .split(',')
      .map((t) => t.trim().toLowerCase())
      .filter((t) => t.length > 0);

    onSave({
      id: memoryToEdit?.id,
      content: content.trim(),
      category,
      source: source.trim() || 'Manual Input',
      confidence,
      tags,
      lastUpdated: 'Just now',
    });
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={memoryToEdit ? 'Edit Semantic Memory' : 'Create New Memory Entry'}
      size="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-5">
        {/* Category Selector Chips */}
        <div className="space-y-1.5">
          <label className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
            Memory Category
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
            {CATEGORIES.map((cat) => {
              const isSelected = category === cat.id;
              return (
                <button
                  type="button"
                  key={cat.id}
                  onClick={() => setCategory(cat.id)}
                  className={`p-2.5 rounded-xl border text-xs font-semibold flex items-center justify-center gap-2 transition-all cursor-pointer ${
                    isSelected
                      ? 'surface-raised border-[var(--color-accent)] text-[var(--color-accent)] shadow-xs'
                      : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  {cat.icon}
                  <span>{cat.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Content Field */}
        <div className="space-y-1.5">
          <div className="flex items-center justify-between">
            <label className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
              Memory Content
            </label>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)]">
              {content.length} characters
            </span>
          </div>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={4}
            placeholder="Describe the profile detail, preference, factual statement, or project context..."
            className="w-full px-3.5 py-2.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none focus:border-[var(--color-accent)] transition-all leading-relaxed"
            required
          />
        </div>

        {/* Source & Tags */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
              Origin / Source
            </label>
            <input
              type="text"
              value={source}
              onChange={(e) => setSource(e.target.value)}
              placeholder="e.g. Conversation with User, Health Connect"
              className="w-full px-3.5 py-2.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none focus:border-[var(--color-accent)] transition-all"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
              Tags (comma separated)
            </label>
            <input
              type="text"
              value={tagsString}
              onChange={(e) => setTagsString(e.target.value)}
              placeholder="e.g. architecture, style, concise"
              className="w-full px-3.5 py-2.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none focus:border-[var(--color-accent)] transition-all"
            />
          </div>
        </div>

        {/* Confidence Slider */}
        <div className="space-y-2 p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
          <div className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-secondary)]">
            <span className="flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              <span>Vector Ingestion Confidence</span>
            </span>
            <span className="font-mono text-sm text-[var(--color-text-primary)]">
              {Math.round(confidence * 100)}%
            </span>
          </div>
          <input
            type="range"
            min="0.5"
            max="1.0"
            step="0.01"
            value={confidence}
            onChange={(e) => setConfidence(parseFloat(e.target.value))}
            className="w-full accent-[var(--color-accent)] cursor-pointer"
          />
          <div className="flex justify-between text-[10px] text-[var(--color-text-muted)] font-mono">
            <span>50% (Tentative)</span>
            <span>85% (Strong)</span>
            <span>100% (Absolute Axiom)</span>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center justify-end gap-3 pt-2">
          <NeumorphicButton
            type="button"
            variant="ghost"
            onClick={onClose}
          >
            Cancel
          </NeumorphicButton>

          <NeumorphicButton
            type="submit"
            variant="primary"
            disabled={!content.trim()}
            icon={<Check className="w-4 h-4" />}
          >
            {memoryToEdit ? 'Save Changes' : 'Index Memory'}
          </NeumorphicButton>
        </div>
      </form>
    </Modal>
  );
};
