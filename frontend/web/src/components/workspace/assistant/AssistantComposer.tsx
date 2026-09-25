import React, { useRef } from 'react';
import {
  Paperclip,
  Mic,
  MicOff,
  Send,
  Square,
  X,
  AlertTriangle,
} from 'lucide-react';
import { AssistantState } from '../../../types';
import { AttachmentOut } from '../../../services/api';

export interface StagedAttachmentItem {
  attachment: AttachmentOut;
  previewUrl: string;
}

export interface AssistantComposerProps {
  inputPrompt: string;
  onInputChange: (val: string) => void;
  onSendMessage: () => void;
  onStopGeneration?: () => void;
  isBusy: boolean;
  assistantState: AssistantState;
  onSetAssistantState?: (state: AssistantState) => void;
  activeCharacterName: string;
  appliedContextSize?: number | null;

  // 8B.6 Attachment & Send Lifecycle Props
  stagedAttachments?: StagedAttachmentItem[];
  onRemoveAttachment?: (attachmentId: string) => void;
  onFilesSelected?: (files: FileList | File[]) => void;
  canAttach?: boolean;
  isUploadingAttachments?: boolean;
  removingAttachmentIds?: Set<string>;
  sendDisabled?: boolean;
  canStop?: boolean;
  isComposerFrozen?: boolean;
  hasVision?: boolean;

  // Legacy compatibility props
  attachments?: string[];
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
  stagedAttachments = [],
  onRemoveAttachment,
  onFilesSelected,
  canAttach = false,
  isUploadingAttachments = false,
  removingAttachmentIds = new Set(),
  sendDisabled = false,
  canStop = false,
  isComposerFrozen = false,
  hasVision = false,
  attachments = [],
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const lineCount = inputPrompt ? inputPrompt.split('\n').length : 1;
  const textareaRows = Math.min(5, Math.max(1, lineCount));

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0 && onFilesSelected) {
      onFilesSelected(e.target.files);
    }
    e.target.value = '';
  };

  const hasStaged = stagedAttachments.length > 0;
  const showVisionWarning = hasStaged && !hasVision;

  return (
    <div className="p-3 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-2xl space-y-2.5">
      {/* Hidden File Input */}
      <input
        type="file"
        ref={fileInputRef}
        accept="image/png,image/jpeg"
        multiple
        disabled={!canAttach}
        onChange={handleFileChange}
        className="hidden"
        data-testid="attachment-file-input"
      />

      {/* Model Vision Capability Warning */}
      {showVisionWarning && (
        <div
          data-testid="vision-loss-warning"
          className="mx-2 px-3 py-2 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs flex items-center gap-2"
        >
          <AlertTriangle className="w-4 h-4 flex-shrink-0" />
          <span>Current active model does not support image input. Remove attachments or switch to a vision-enabled model to send.</span>
        </div>
      )}

      {/* Staged Thumbnail Cards */}
      {hasStaged && (
        <div className="flex flex-wrap items-center gap-2 px-2 pt-1" data-testid="staged-attachments-strip">
          {stagedAttachments.map((item) => {
            const isRemoving = removingAttachmentIds.has(item.attachment.id);
            return (
              <div
                key={item.attachment.id}
                data-testid={`staged-card-${item.attachment.id}`}
                className="relative group w-14 h-14 rounded-2xl overflow-hidden border border-[var(--color-border-subtle)] surface-raised flex-shrink-0"
              >
                <img
                  src={item.previewUrl}
                  alt={item.attachment.file_name}
                  className="w-full h-full object-cover"
                />
                {isRemoving && (
                  <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
                    <span className="text-[10px] font-mono text-white animate-pulse">...</span>
                  </div>
                )}
                {onRemoveAttachment && !isComposerFrozen && !isRemoving && (
                  <button
                    type="button"
                    onClick={() => onRemoveAttachment(item.attachment.id)}
                    className="absolute top-1 right-1 w-5 h-5 rounded-full bg-black/60 hover:bg-rose-600 text-white flex items-center justify-center text-xs transition-colors"
                    aria-label={`Remove attachment ${item.attachment.file_name}`}
                    title={`Remove ${item.attachment.file_name}`}
                  >
                    <X className="w-3 h-3" />
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Legacy attachments backward compatibility tag strip */}
      {!hasStaged && attachments.length > 0 && (
        <div className="flex flex-wrap items-center gap-2 px-2 pt-1">
          {attachments.map((file, idx) => (
            <span
              key={idx}
              className="px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] font-mono text-[var(--color-accent)] flex items-center gap-1.5"
            >
              <Paperclip className="w-3 h-3" />
              {file}
            </span>
          ))}
        </div>
      )}

      {/* Main Input Row */}
      <div className="flex items-end gap-2">
        {/* Attachment Button */}
        <button
          type="button"
          onClick={() => {
            if (canAttach) {
              fileInputRef.current?.click();
            }
          }}
          disabled={!canAttach}
          className={`w-10 h-10 rounded-2xl border flex items-center justify-center flex-shrink-0 mb-0.5 transition-all ${
            canAttach
              ? 'surface-raised border-[var(--color-border-subtle)] text-[var(--color-text-primary)] hover:border-[var(--color-accent)] hover:text-[var(--color-accent)] cursor-pointer'
              : 'surface-recessed border-[var(--color-border-subtle)] opacity-40 cursor-not-allowed text-[var(--color-text-muted)]'
          }`}
          title={
            !hasVision
              ? 'Active model does not support image input'
              : isUploadingAttachments
              ? 'Uploading attachment...'
              : stagedAttachments.length >= 4
              ? 'Maximum 4 attachments reached'
              : 'Attach image (PNG or JPEG, max 10 MiB)'
          }
          aria-label="Attach images"
          data-testid="attachment-paperclip-button"
        >
          <Paperclip className={`w-4 h-4 ${isUploadingAttachments ? 'animate-pulse text-[var(--color-accent)]' : ''}`} />
        </button>

        {/* Multiline Composer Textarea */}
        <textarea
          rows={textareaRows}
          value={inputPrompt}
          readOnly={isComposerFrozen}
          onChange={(e) => onInputChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              if (!sendDisabled && !isComposerFrozen) {
                onSendMessage();
              }
            } else if (e.key === 'Escape' && canStop && onStopGeneration) {
              e.preventDefault();
              onStopGeneration();
            }
          }}
          placeholder={`Message ${activeCharacterName} or run slash commands (/schedule, /task, /health)...`}
          className={`flex-1 bg-transparent px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none resize-none max-h-36 leading-relaxed self-center ${
            isComposerFrozen ? 'opacity-60 cursor-not-allowed' : ''
          }`}
          data-testid="composer-textarea"
        />

        {/* Microphone Toggle (Stub) */}
        <button
          type="button"
          onClick={() =>
            onSetAssistantState?.(assistantState === 'listening' ? 'idle' : 'listening')
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

        {/* Stop Generation Button (rendered only when canStop is true) */}
        {canStop && (
          <button
            type="button"
            onClick={onStopGeneration}
            className="w-10 h-10 rounded-2xl bg-orange-500/15 border border-orange-500/40 text-orange-400 hover:bg-orange-500/25 flex items-center justify-center transition-all flex-shrink-0 mb-0.5"
            title="Stop generation"
            aria-label="Stop generation"
            data-testid="stop-generation-button"
          >
            <Square className="w-4 h-4 fill-current" />
          </button>
        )}

        {/* Send Button */}
        <button
          type="button"
          onClick={() => {
            if (!sendDisabled && !isComposerFrozen) {
              onSendMessage();
            }
          }}
          disabled={sendDisabled || isComposerFrozen}
          className="w-10 h-10 rounded-2xl bg-accent-gradient text-white flex items-center justify-center shadow-md glow-accent-sm disabled:opacity-40 disabled:cursor-not-allowed hover:scale-105 active:scale-95 transition-all flex-shrink-0 mb-0.5"
          title="Send prompt to local model"
          aria-label="Send message"
          data-testid="send-message-button"
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
          {appliedContextSize != null
            ? `Context buffer: ${appliedContextSize} tokens`
            : 'Context buffer: Unavailable'}
        </span>
      </div>
    </div>
  );
};
