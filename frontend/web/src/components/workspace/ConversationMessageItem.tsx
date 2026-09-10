import React, { useState } from 'react';
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
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { AssistantMessage } from '../../types';

export interface ConversationMessageItemProps {
  message: AssistantMessage;
  userName?: string;
  activeCharacterName?: string;
}

export const ConversationMessageItem: React.FC<ConversationMessageItemProps> = ({
  message,
  userName = 'Chris',
  activeCharacterName = 'Aura',
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
                  Query: {message.searchMetadata?.query || 'CUDA benchmarks'}
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
                llama.cpp/docs/backend-cuda.md
              </span>
              <span className="text-[10px] text-[var(--color-text-muted)] font-mono">Local Doc</span>
            </div>
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between text-[11px]">
              <span className="font-mono text-[var(--color-accent)] truncate">
                benchmarks/vram-alloc-q4km.json
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
        <div className="p-4 rounded-3xl surface-raised border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] space-y-1 max-w-xl">
          <div className="flex items-center justify-between gap-4 text-[11px] text-[var(--color-text-muted)] font-mono">
            <span className="font-semibold text-[var(--color-text-primary)]">{userName}</span>
            <span>{message.timestamp}</span>
          </div>
          <p className="leading-relaxed whitespace-pre-line">{message.content}</p>
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
      <div className="p-4 sm:p-5 rounded-3xl glass-panel border border-[var(--color-surface-glass-border)] text-sm text-[var(--color-text-primary)] space-y-2.5 max-w-2xl shadow-sm">
        <div className="flex items-center justify-between gap-4 pb-1.5 border-b border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)] font-mono">
          <div className="flex items-center gap-2">
            <span className="font-bold text-[var(--color-accent)]">{activeCharacterName}</span>
            <span className="text-[10px] text-emerald-500 font-medium">42.8 t/s • 22ms</span>
          </div>
          <span>{message.timestamp}</span>
        </div>

        <p className="leading-relaxed whitespace-pre-line text-sm">{message.content}</p>

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
