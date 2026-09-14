import React from 'react';
import {
  Paperclip,
  Mic,
  MicOff,
  Send,
  Square,
} from 'lucide-react';
import { AssistantState } from '../../../types';

export interface AssistantComposerProps {
  inputPrompt: string;
  onInputChange: (val: string) => void;
  onSendMessage: () => void;
  onStopGeneration: () => void;
  isBusy: boolean;
  assistantState: AssistantState;
  onSetAssistantState: (state: AssistantState) => void;
  activeCharacterName: string;
  appliedContextSize?: number | null;
  attachments?: string[];
  onRemoveAttachment?: (index: number) => void;
}

export const AssistantComposer: React.FC<AssistantComposerProps> = ({
  inputPrompt,
  onInputChange,
  onSendMessage,
  onStopGeneration,
  isBusy,
  assistantState,
  onSetAssistantState,
  activeCharacterName,
  appliedContextSize,
  attachments = [],
  onRemoveAttachment,
}) => {
  const lineCount = inputPrompt ? inputPrompt.split('\n').length : 1;
  const textareaRows = Math.min(5, Math.max(1, lineCount));

  return (
    <div className="p-3 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-2xl space-y-2.5">
      {/* Attachment Tags (if any active in state) */}
      {attachments.length > 0 && (
        <div className="flex flex-wrap items-center gap-2 px-2 pt-1">
          {attachments.map((file, idx) => (
            <span
              key={idx}
              className="px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] font-mono text-[var(--color-accent)] flex items-center gap-1.5"
            >
              <Paperclip className="w-3 h-3" />
              {file}
              {onRemoveAttachment && (
                <button
                  type="button"
                  onClick={() => onRemoveAttachment(idx)}
                  className="hover:text-rose-500 ml-1"
                  aria-label={`Remove attachment ${file}`}
                >
                  ×
                </button>
              )}
            </span>
          ))}
        </div>
      )}

      {/* Main Input Row */}
      <div className="flex items-end gap-2">
        {/* Attachment Button — Disabled in 8A.2, enabled in Phase 8B */}
        <button
          type="button"
          disabled
          className="w-10 h-10 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] opacity-50 cursor-not-allowed flex items-center justify-center text-[var(--color-text-muted)] flex-shrink-0 mb-0.5"
          title="Image attachments — Phase 8B"
          aria-label="Image attachments — Phase 8B"
        >
          <Paperclip className="w-4 h-4" />
        </button>

        {/* Multiline Composer Textarea */}
        <textarea
          rows={textareaRows}
          value={inputPrompt}
          onChange={(e) => onInputChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              onSendMessage();
            } else if (e.key === 'Escape' && isBusy) {
              e.preventDefault();
              onStopGeneration();
            }
          }}
          placeholder={`Message ${activeCharacterName} or run slash commands (/schedule, /task, /health)...`}
          className="flex-1 bg-transparent px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none resize-none max-h-36 leading-relaxed self-center"
        />

        {/* Microphone Toggle (Stub: simulate listening preview without false VAD claims) */}
        <button
          type="button"
          onClick={() =>
            onSetAssistantState(assistantState === 'listening' ? 'idle' : 'listening')
          }
          className={`w-10 h-10 rounded-2xl border flex items-center justify-center transition-all flex-shrink-0 mb-0.5 ${
            assistantState === 'listening'
              ? 'bg-rose-500/15 border-rose-500 text-rose-500 font-bold animate-pulse'
              : 'surface-raised border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-accent)]'
          }`}
          title={
            assistantState === 'listening'
              ? 'Stop listening (Preview stub)'
              : 'Voice input (Stub — audio capture not connected)'
          }
          aria-label={
            assistantState === 'listening'
              ? 'Stop listening (Preview stub)'
              : 'Voice input (Stub — audio capture not connected)'
          }
        >
          {assistantState === 'listening' ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
        </button>

        {/* Stop Generation Button (when busy) */}
        {isBusy && (
          <button
            type="button"
            onClick={onStopGeneration}
            className="w-10 h-10 rounded-2xl bg-orange-500/15 border border-orange-500/40 text-orange-400 hover:bg-orange-500/25 flex items-center justify-center transition-all flex-shrink-0 mb-0.5"
            title="Stop generation"
          >
            <Square className="w-4 h-4 fill-current" />
          </button>
        )}

        {/* Send Button */}
        <button
          type="button"
          onClick={onSendMessage}
          disabled={!inputPrompt.trim() && attachments.length === 0}
          className="w-10 h-10 rounded-2xl bg-accent-gradient text-white flex items-center justify-center shadow-md glow-accent-sm disabled:opacity-40 disabled:cursor-not-allowed hover:scale-105 active:scale-95 transition-all flex-shrink-0 mb-0.5"
          title="Send prompt to local model"
        >
          <Send className="w-4 h-4" />
        </button>
      </div>

      {/* Composer Footer Hints */}
      <div className="flex items-center justify-between px-2 pt-1 text-[10px] text-[var(--color-text-muted)] font-mono border-t border-[var(--color-border-subtle)]">
        <span className="flex items-center gap-1">
          <span>Press <strong>Enter</strong> to send • <strong>Shift + Enter</strong> for newline</span>
        </span>
        <span>
          {appliedContextSize
            ? `Context buffer: ${appliedContextSize} tokens`
            : 'Local context buffer: active'}
        </span>
      </div>
    </div>
  );
};
