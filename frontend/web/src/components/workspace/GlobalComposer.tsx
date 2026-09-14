import React, { useState, useEffect } from 'react';
import {
  Paperclip,
  Mic,
  Sparkles,
  ChevronUp,
} from 'lucide-react';

export interface GlobalComposerProps {
  activeCharacterName?: string;
  onOpenAssistant?: () => void;
}

export const GlobalComposer: React.FC<GlobalComposerProps> = ({
  activeCharacterName = 'Assistant',
  onOpenAssistant,
}) => {
  const [isFocused, setIsFocused] = useState(false);
  const [isHovered, setIsHovered] = useState(false);

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

  const isExpanded = isFocused || isHovered;

  const handleLaunch = () => {
    setIsFocused(false);
    onOpenAssistant?.();
  };

  return (
    <div
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      className="w-full max-w-4xl mx-auto px-4 sm:px-6 pb-3 pt-1 sticky bottom-0 z-20 select-none"
    >
      {!isExpanded ? (
        /* Sleek Collapsed Peek Bar */
        <div className="flex justify-center transition-all duration-200">
          <button
            type="button"
            onClick={handleLaunch}
            className="pointer-events-auto group flex items-center gap-2 px-4 py-2 rounded-full glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-md hover:border-[var(--color-accent)]/50 hover:shadow-lg transition-all text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] cursor-pointer"
          >
            <Sparkles className="w-3.5 h-3.5 text-[var(--color-accent)] group-hover:rotate-12 transition-transform" />
            <span className="font-medium">Ask {activeCharacterName}</span>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-md surface-recessed text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
              Open Assistant (/)
            </span>
            <ChevronUp className="w-3 h-3 text-[var(--color-text-muted)] group-hover:-translate-y-0.5 transition-transform" />
          </button>
        </div>
      ) : (
        /* Floating Soft Glass Launcher Card */
        <div className="p-2 sm:p-2.5 rounded-2xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-2xl pointer-events-auto transition-all duration-200">
          <div className="flex items-center gap-2">
            {/* 1. Attachment Button (Disabled - Planned Phase 8B) */}
            <button
              type="button"
              disabled
              title="Image attachments — Phase 8B (Planned)"
              className="w-9 h-9 rounded-xl surface-recessed border border-[var(--color-border-subtle)] opacity-50 flex items-center justify-center text-[var(--color-text-muted)] cursor-not-allowed flex-shrink-0"
            >
              <Paperclip className="w-4 h-4" />
            </button>

            {/* 2. Launcher Action Area (Non-editable trigger button) */}
            <button
              type="button"
              onClick={handleLaunch}
              className="flex-1 text-left px-3 py-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40 transition-all cursor-pointer truncate"
              title="Click to open Assistant workspace"
            >
              Ask {activeCharacterName} (Opens Assistant Workspace)...
            </button>

            {/* 3. Microphone Button (Disabled - Voice input not connected) */}
            <button
              type="button"
              disabled
              title="Voice input not connected — Planned"
              className="w-9 h-9 rounded-xl surface-recessed border border-[var(--color-border-subtle)] opacity-50 flex items-center justify-center text-[var(--color-text-muted)] cursor-not-allowed flex-shrink-0"
            >
              <Mic className="w-4 h-4" />
            </button>

            {/* 4. Open Assistant Button */}
            <button
              type="button"
              onClick={handleLaunch}
              title="Open Assistant Workspace"
              className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-accent-gradient text-white text-xs font-semibold shadow-md hover:shadow-lg active:scale-95 transition-all flex-shrink-0 glow-accent-sm cursor-pointer"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Open Assistant</span>
            </button>
          </div>

          {/* Bottom Helper Bar */}
          <div className="flex items-center justify-between px-2 pt-1.5 text-[10px] text-[var(--color-text-muted)] border-t border-[var(--color-border-subtle)]/50 mt-1">
            <span className="font-mono">
              Local AI Companion • Assistant Launcher
            </span>

            <span className="hidden sm:inline font-mono">
              Press / to open conversation workspace
            </span>
          </div>
        </div>
      )}
    </div>
  );
};
