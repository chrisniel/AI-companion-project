import React, { useEffect } from 'react';
import { Sparkles, ChevronUp } from 'lucide-react';

export interface GlobalComposerProps {
  activeCharacterName?: string;
  onOpenAssistant?: () => void;
}

export const GlobalComposer: React.FC<GlobalComposerProps> = ({
  activeCharacterName = 'Assistant',
  onOpenAssistant,
}) => {
  // Global shortcut: press "/" to open Assistant directly when not typing in another input
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (
        e.key === '/' &&
        !['INPUT', 'TEXTAREA'].includes((document.activeElement as HTMLElement)?.tagName)
      ) {
        e.preventDefault();
        onOpenAssistant?.();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onOpenAssistant]);

  return (
    <div className="w-full max-w-4xl mx-auto px-4 sm:px-6 pb-3 pt-1 sticky bottom-0 z-20 pointer-events-none select-none">
      <div className="flex justify-center">
        <button
          type="button"
          onClick={() => onOpenAssistant?.()}
          aria-label={`Ask ${activeCharacterName} (Opens Assistant Workspace)`}
          className="pointer-events-auto group flex items-center gap-2.5 px-5 py-2.5 rounded-full glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-md hover:border-[var(--color-accent)]/50 hover:shadow-lg active:scale-95 transition-all text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] cursor-pointer"
          title={`Ask ${activeCharacterName} (Press /)`}
        >
          <Sparkles className="w-3.5 h-3.5 text-[var(--color-accent)] group-hover:rotate-12 transition-transform" />
          <span className="font-semibold text-[var(--color-text-primary)]">
            Ask {activeCharacterName}
          </span>
          <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-md surface-recessed text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
            /
          </span>
          <ChevronUp className="w-3 h-3 text-[var(--color-text-muted)] group-hover:-translate-y-0.5 transition-transform" />
        </button>
      </div>
    </div>
  );
};
