import React, { useState, useEffect } from 'react';
import {
  Check,
  User,
  HeartHandshake,
  BookOpen,
  Sliders,
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
  { id: 'Fact', label: 'Fact', icon: <BookOpen className="w-3.5 h-3.5" /> },
  { id: 'Preference', label: 'Preference', icon: <HeartHandshake className="w-3.5 h-3.5" /> },
  { id: 'Profile', label: 'Profile / Context', icon: <User className="w-3.5 h-3.5" /> },
];

export const MemoryEditorModal: React.FC<MemoryEditorModalProps> = ({
  isOpen,
  onClose,
  onSave,
  memoryToEdit,
}) => {
  const [content, setContent] = useState('');
  const [category, setCategory] = useState<MemoryCategory>('Fact');
  const [importance, setImportance] = useState(1.0);

  useEffect(() => {
    if (memoryToEdit) {
      setContent(memoryToEdit.content);
      const cat = (memoryToEdit.category === 'Preference' || memoryToEdit.category === 'Profile')
        ? memoryToEdit.category
        : 'Fact';
      setCategory(cat);
      setImportance(typeof memoryToEdit.importance === 'number' ? memoryToEdit.importance : 1.0);
    } else {
      setContent('');
      setCategory('Fact');
      setImportance(1.0);
    }
  }, [memoryToEdit, isOpen]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim()) return;

    onSave({
      id: memoryToEdit?.id,
      content: content.trim(),
      category,
      importance,
      lastUpdated: 'Just now',
    });
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={memoryToEdit ? 'Edit Memory Record' : 'Create New Memory Record'}
      size="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-5">
        {/* Category Selector Chips */}
        <div className="space-y-1.5">
          <label className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
            Memory Category
          </label>
          <div className="grid grid-cols-3 gap-2">
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
            placeholder="Describe the factual statement, preference, or profile context..."
            className="w-full px-3.5 py-2.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none focus:border-[var(--color-accent)] transition-all leading-relaxed"
            required
          />
        </div>

        {/* Importance Slider (Backend float 0.0 to 2.0) */}
        <div className="space-y-2 p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
          <div className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-secondary)]">
            <span className="flex items-center gap-1.5">
              <Sliders className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              <span>Memory Importance Weight</span>
            </span>
            <span className="font-mono text-sm text-[var(--color-text-primary)]">
              {importance.toFixed(1)}
            </span>
          </div>
          <input
            type="range"
            min="0.0"
            max="2.0"
            step="0.1"
            value={importance}
            onChange={(e) => setImportance(parseFloat(e.target.value))}
            className="w-full accent-[var(--color-accent)] cursor-pointer"
          />
          <div className="flex justify-between text-[10px] text-[var(--color-text-muted)] font-mono">
            <span>0.0 (Low)</span>
            <span>1.0 (Standard)</span>
            <span>2.0 (High Priority)</span>
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
            {memoryToEdit ? 'Save Changes' : 'Save Memory'}
          </NeumorphicButton>
        </div>
      </form>
    </Modal>
  );
};
