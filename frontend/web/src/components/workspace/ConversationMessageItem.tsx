import React, { useState, useEffect } from 'react';
import {
  Sparkles,
  User,
  Bot,
  Terminal,
  Calendar,
  CheckSquare,
  Activity,
  Brain,
  Search,
  Globe,
  AlertTriangle,
  AlertCircle,
  Copy,
  Check,
  Volume2,
  ChevronDown,
  ChevronUp,
  ExternalLink,
  Zap,
  Image as ImageIcon,
  FileWarning,
  Loader2,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { Modal } from '../ui/Modal';
import { AssistantMessage } from '../../types';
import { fetchAttachmentBlobUrl, ALLOWED_MIME_TYPES } from '../../services/api';
import type { AttachmentRef } from '../../services/api';
import { AssistantMarkdownRenderer } from './assistant/AssistantMarkdownRenderer';

interface AttachmentPreviewRendererProps {
  conversationId: string;
  attachment: AttachmentRef;
}

const AttachmentPreviewRenderer: React.FC<AttachmentPreviewRendererProps> = ({
  conversationId,
  attachment,
}) => {
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [error, setError] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(true);
  const [isLightboxOpen, setIsLightboxOpen] = useState<boolean>(false);

  const isSupportedImage = ALLOWED_MIME_TYPES.some(
    (mimeType) => mimeType === attachment.mime_type
  );

  useEffect(() => {
    let isMounted = true;
    let localUrl: string | null = null;

    if (!isSupportedImage) {
      setLoading(false);
      return;
    }

    setLoading(true);
    fetchAttachmentBlobUrl(conversationId, attachment.id)
      .then((url) => {
        if (!isMounted) {
          // Resolved AFTER disposal, immediately revoke.
          try {
            URL.revokeObjectURL(url);
          } catch {}
          return;
        }
        localUrl = url;
        setBlobUrl(url);
        setError(false);
      })
      .catch((err) => {
        if (!isMounted) return;
        console.warn('Failed to fetch attachment preview:', err);
        setError(true);
      })
      .finally(() => {
        if (isMounted) setLoading(false);
      });

    return () => {
      isMounted = false;
      if (localUrl) {
        try {
          URL.revokeObjectURL(localUrl);
        } catch {}
      }
    };
  }, [conversationId, attachment.id, isSupportedImage]);

  return (
    <>
      <div className="relative w-24 h-24 rounded-lg overflow-hidden border border-[var(--color-border-subtle)] bg-[var(--color-surface-recessed)] flex items-center justify-center group">
        {loading ? (
          <Loader2 className="w-5 h-5 text-[var(--color-text-muted)] animate-spin" />
        ) : error ? (
          <div className="flex flex-col items-center gap-1 text-[var(--color-text-muted)] p-1 text-center" title="Preview unavailable">
            <FileWarning className="w-5 h-5" />
            <span className="text-[9px] font-mono leading-tight truncate w-full px-1">{attachment.filename_display}</span>
          </div>
        ) : isSupportedImage && blobUrl ? (
          <button
            type="button"
            onClick={() => setIsLightboxOpen(true)}
            aria-label={`View enlarged preview of ${attachment.filename_display}`}
            className="w-full h-full p-0 m-0 border-0 bg-transparent cursor-pointer focus:outline-none focus:ring-2 focus:ring-[var(--color-accent)] rounded-lg overflow-hidden relative block"
          >
            <img src={blobUrl} alt={attachment.filename_display} className="w-full h-full object-cover transition-transform duration-200 group-hover:scale-105" />
            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center opacity-0 group-hover:opacity-100">
              <span className="text-[10px] font-medium text-white px-2 py-0.5 rounded-full bg-black/60 backdrop-blur-sm shadow">
                View
              </span>
            </div>
          </button>
        ) : (
          <div className="flex flex-col items-center gap-1 text-[var(--color-text-muted)] p-1 text-center" title={attachment.filename_display}>
            <ImageIcon className="w-5 h-5" />
            <span className="text-[9px] font-mono leading-tight truncate w-full px-1">{attachment.filename_display}</span>
          </div>
        )}
      </div>

      {isLightboxOpen && blobUrl && (
        <Modal
          isOpen={isLightboxOpen}
          onClose={() => setIsLightboxOpen(false)}
          title={attachment.filename_display}
          description={`${attachment.mime_type} • ${Math.round(attachment.size_bytes / 1024)} KB`}
          maxWidth="xl"
        >
          <div className="flex items-center justify-center overflow-hidden py-2" data-testid="image-lightbox-content">
            <img
              src={blobUrl}
              alt={attachment.filename_display}
              className="max-h-[70vh] max-w-full w-auto h-auto object-contain rounded-xl shadow-lg border border-[var(--color-border-subtle)]"
            />
          </div>
        </Modal>
      )}
    </>
  );
};

export interface ConversationMessageItemProps {
  message: AssistantMessage;
  userName?: string;
  activeCharacterName?: string;
  activeConversationId?: string;
}

export const ConversationMessageItem: React.FC<ConversationMessageItemProps> = ({
  message,
  userName = 'Chris',
  activeCharacterName = 'Aura',
  activeConversationId,
}) => {
  const [copied, setCopied] = useState(false);
  const [detailsExpanded, setDetailsExpanded] = useState(false);
  const [isSpeaking, setIsSpeaking] = useState(false);

  const handleCopy = (text: string) => {
    navigator.clipboard?.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSpeak = () => {
    setIsSpeaking(true);
    setTimeout(() => setIsSpeaking(false), 2500);
  };

  // 1. SYSTEM MESSAGE
  if (message.type === 'system') {
    return (
      <div className="flex justify-center my-3">
        <div className="px-4 py-2 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] max-w-xl text-center space-y-1">
          <div className="flex items-center justify-center gap-1.5 text-[11px] font-mono text-[var(--color-accent)] font-semibold">
            <Terminal className="w-3.5 h-3.5" />
            <span>Local System Context • {message.timestamp}</span>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] font-mono leading-relaxed">
            {message.content}
          </p>
        </div>
      </div>
    );
  }

  // 2. WARNING MESSAGE
  if (message.type === 'warning') {
    return (
      <div className="flex justify-center my-3">
        <div className="w-full max-w-2xl p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-700 dark:text-amber-300 space-y-1.5">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0" />
              <span className="text-xs font-bold uppercase tracking-wider font-mono">
                System Runtime Warning
              </span>
            </div>
            <span className="text-[10px] font-mono opacity-75">{message.timestamp}</span>
          </div>
          <p className="text-xs leading-relaxed text-[var(--color-text-primary)]">
            {message.content}
          </p>
        </div>
      </div>
    );
  }

  // 3. ERROR MESSAGE
  if (message.type === 'error') {
    return (
      <div className="flex justify-center my-3">
        <div className="w-full max-w-2xl p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 text-rose-700 dark:text-rose-300 space-y-1.5">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-500 flex-shrink-0" />
              <span className="text-xs font-bold uppercase tracking-wider font-mono">
                Inference Engine Notice
              </span>
            </div>
            <span className="text-[10px] font-mono opacity-75">{message.timestamp}</span>
          </div>
          <p className="text-xs leading-relaxed text-[var(--color-text-primary)]">
            {message.content}
          </p>
        </div>
      </div>
    );
  }

  // 4. TOOL EXECUTION CARD
  if (message.type === 'tool_execution' && message.toolCard) {
    const { toolName, action, summary, status, details } = message.toolCard;

    const getToolIcon = () => {
      switch (toolName.toLowerCase()) {
        case 'schedule':
          return <Calendar className="w-4 h-4 text-[var(--color-accent)]" />;
        case 'task':
          return <CheckSquare className="w-4 h-4 text-emerald-500" />;
        case 'health':
          return <Activity className="w-4 h-4 text-rose-500" />;
        default:
          return <Zap className="w-4 h-4 text-[var(--color-accent)]" />;
      }
    };

    return (
      <div className="flex items-start gap-3 my-2 max-w-2xl ml-11">
        <div className="w-full p-3.5 rounded-2xl glass-panel border border-[var(--color-surface-glass-border)] space-y-2.5 shadow-sm">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <div className="w-7 h-7 rounded-xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center">
                {getToolIcon()}
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    {toolName}
                  </span>
                  <Badge variant={status === 'completed' ? 'success' : 'accent'} size="sm">
                    {action}
                  </Badge>
                </div>
                <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                  {summary}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 text-[10px] font-mono text-[var(--color-text-muted)]">
              <span>{message.timestamp}</span>
              {details && (
                <button
                  type="button"
                  onClick={() => setDetailsExpanded(!detailsExpanded)}
                  className="p-1 rounded-lg hover:bg-[var(--color-surface-secondary)] text-[var(--color-text-secondary)]"
                  title="Toggle tool output details"
                >
                  {detailsExpanded ? (
                    <ChevronUp className="w-3.5 h-3.5" />
                  ) : (
                    <ChevronDown className="w-3.5 h-3.5" />
                  )}
                </button>
              )}
            </div>
          </div>

          {detailsExpanded && details && (
            <div className="pt-2 border-t border-[var(--color-border-subtle)] grid grid-cols-2 gap-2 text-xs font-mono">
              {Object.entries(details).map(([key, val]) => (
                <div key={key} className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
                  <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                    {key}
                  </span>
                  <span className="font-semibold text-[var(--color-text-primary)]">{String(val)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  // 5. MEMORY RETRIEVAL CARD
  if (message.type === 'memory_retrieval') {
    return (
      <div className="flex items-start gap-3 my-2 max-w-2xl ml-11">
        <div className="w-full p-3.5 rounded-2xl glass-panel border border-[var(--color-surface-glass-border)] space-y-2 shadow-sm">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
                <Brain className="w-4 h-4" />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    Local Memory Retrieval
                  </span>
                  <Badge variant="accent" size="sm">
                    sim: {message.memoryMetadata?.similarity || '0.94'}
                  </Badge>
                </div>
                <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                  Index: {message.memoryMetadata?.source || 'bge-large-en-v1.5'}
                </span>
              </div>
            </div>
            <span className="text-[10px] font-mono text-[var(--color-text-muted)]">
              {message.timestamp}
            </span>
          </div>

          <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-secondary)] font-mono leading-relaxed">
            &ldquo;{message.content}&rdquo;
          </div>
        </div>
      </div>
    );
  }

  // 6. WEB / SEARCH RESULT CARD
  if (message.type === 'web_search') {
    return (
      <div className="flex items-start gap-3 my-2 max-w-2xl ml-11">
        <div className="w-full p-3.5 rounded-2xl glass-panel border border-[var(--color-surface-glass-border)] space-y-2.5 shadow-sm">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-xl bg-sky-500/10 border border-sky-500/30 flex items-center justify-center text-sky-400">
                <Globe className="w-4 h-4" />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    Local Knowledge Search
                  </span>
                  <Badge variant="glass" size="sm">
                    {message.searchMetadata?.resultsCount || 3} citations
                  </Badge>
                </div>
                <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                  Query: {message.searchMetadata?.query || 'local documentation'}
                </span>
              </div>
            </div>
            <span className="text-[10px] font-mono text-[var(--color-text-muted)]">
              {message.timestamp}
            </span>
          </div>

          <p className="text-xs text-[var(--color-text-primary)] leading-relaxed">
            {message.content}
          </p>

          <div className="pt-2 border-t border-[var(--color-border-subtle)] space-y-1">
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between text-[11px]">
              <span className="font-mono text-[var(--color-accent)] truncate">
                docs/04_Architecture/local-runtime.md
              </span>
              <span className="text-[10px] text-[var(--color-text-muted)] font-mono">Local Doc</span>
            </div>
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between text-[11px]">
              <span className="font-mono text-[var(--color-accent)] truncate">
                benchmarks/vram-measurements.json
              </span>
              <span className="text-[10px] text-[var(--color-text-muted)] font-mono">Telemetry Log</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // 7. USER MESSAGE
  if (message.type === 'user') {
    return (
      <div className="flex items-start gap-3 my-3 max-w-3xl ml-auto flex-row-reverse">
        {/* User Avatar */}
        <div className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-xs font-bold text-white shadow-sm flex-shrink-0 glow-accent-sm">
          {userName[0].toUpperCase()}
        </div>

        {/* User Message Bubble */}
        <div role="article" className="p-4 rounded-3xl surface-raised border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] space-y-1 max-w-xl">
          <div className="flex items-center justify-between gap-4 text-[11px] text-[var(--color-text-muted)] font-mono">
            <span className="font-semibold text-[var(--color-text-primary)]">{userName}</span>
            <span>{message.timestamp}</span>
          </div>
          <p className="leading-relaxed whitespace-pre-line">{message.content}</p>
          {message.attachments && message.attachments.length > 0 && activeConversationId && (
            <div className="flex flex-wrap gap-2 pt-2 mt-2 border-t border-[var(--color-border-subtle)]">
              {message.attachments.map((att) => (
                <AttachmentPreviewRenderer
                  key={att.id}
                  conversationId={activeConversationId}
                  attachment={att}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  // 8. ASSISTANT MESSAGE
  return (
    <div className="flex items-start gap-3 my-3 max-w-3xl">
      {/* Assistant Avatar */}
      <div className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-white text-xs font-bold shadow-sm glow-accent-sm flex-shrink-0">
        <Bot className="w-4 h-4" />
      </div>

      {/* Assistant Message Bubble */}
      <div role="article" className="p-4 sm:p-5 rounded-3xl glass-panel border border-[var(--color-surface-glass-border)] text-sm text-[var(--color-text-primary)] space-y-2.5 max-w-2xl shadow-sm">
        <div className="flex items-center justify-between gap-4 pb-1.5 border-b border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)] font-mono">
          <div className="flex items-center gap-2">
            <span className="font-bold text-[var(--color-accent)]">{activeCharacterName}</span>
          </div>
          <span>{message.timestamp}</span>
        </div>

        <AssistantMarkdownRenderer content={message.content} className="text-sm" />

        {/* Action Controls */}
        <div className="flex items-center justify-end gap-2 pt-2 border-t border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)]">
          <button
            type="button"
            onClick={handleSpeak}
            className={`px-2 py-1 rounded-lg surface-recessed hover:text-[var(--color-accent)] flex items-center gap-1 transition-colors ${
              isSpeaking ? 'text-[var(--color-accent)] border border-[var(--color-accent)]/40' : ''
            }`}
            title="Synthesize voice output"
          >
            <Volume2 className="w-3.5 h-3.5" />
            <span className="text-[10px]">{isSpeaking ? 'Playing...' : 'Voice'}</span>
          </button>

          <button
            type="button"
            onClick={() => handleCopy(message.content)}
            className="px-2 py-1 rounded-lg surface-recessed hover:text-[var(--color-accent)] flex items-center gap-1 transition-colors"
            title="Copy text to clipboard"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
            <span className="text-[10px]">{copied ? 'Copied' : 'Copy'}</span>
          </button>
        </div>
      </div>
    </div>
  );
};
