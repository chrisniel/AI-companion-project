import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  Bot,
  User,
  Sparkles,
  History,
  Plus,
  Search,
  Paperclip,
  Mic,
  MicOff,
  Send,
  Square,
  Globe,
  Cpu,
  ShieldCheck,
  Zap,
  RotateCcw,
  Activity,
  Terminal,
  Layers,
  ChevronDown,
  Info,
  RefreshCw,
  AlertCircle,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { StatusIndicator } from '../ui/StatusIndicator';
import { useBackend } from '../../context/BackendContext';
import {
  listConversations,
  createConversation,
  getConversation,
  getMessages,
  streamSendMessage,
  ConversationOut,
  MessageOut,
  ModelStatusResponse,
} from '../../services/api';
import {
  AssistantMessage,
  AssistantState,
  ConversationHistoryItem,
  MessageType,
} from '../../types';
import {
  ConversationHistoryDrawer,
  mockConversations,
} from './ConversationHistoryDrawer';
import { ConversationMessageItem } from './ConversationMessageItem';

export type AssistantErrorCode =
  | 'CORE_OFFLINE'
  | 'MODEL_NOT_LOADED'
  | 'MODEL_SLEEPING'
  | 'WAKE_FAILED'
  | 'STREAM_CONNECTION_FAILED'
  | 'STREAM_TERMINATED'
  | 'MODEL_GENERATION_FAILED'
  | 'USER_CANCELLED';

export interface ClassifiedStreamError {
  code: AssistantErrorCode;
  visibleMessage: string;
}

export function classifyStreamError(
  err: Error | unknown,
  isOnline: boolean,
  modelStatus: ModelStatusResponse | null | undefined
): ClassifiedStreamError {
  const errObj = err instanceof Error ? err : new Error(String(err));
  const errMessage = errObj.message || 'Stream terminated unexpectedly';
  const apiCode = (errObj as { code?: string }).code;

  // 1. User cancellation
  if (
    errObj.name === 'AbortError' ||
    errMessage.toLowerCase().includes('abort') ||
    errMessage.toLowerCase().includes('cancel')
  ) {
    return {
      code: 'USER_CANCELLED',
      visibleMessage: `Generation stopped by user. [USER_CANCELLED]`,
    };
  }

  // 2. Core Offline
  if (!isOnline) {
    return {
      code: 'CORE_OFFLINE',
      visibleMessage: `Local AI Core is offline. Ensure Local AI Core is running on :8000. [CORE_OFFLINE: ${errMessage}]`,
    };
  }

  // 3. Stream Terminated unexpectedly (premature EOF)
  if (apiCode === 'STREAM_TERMINATED' || errMessage.includes('STREAM_TERMINATED')) {
    return {
      code: 'STREAM_TERMINATED',
      visibleMessage: `Stream ended abruptly before explicit completion. [STREAM_TERMINATED: ${errMessage}]`,
    };
  }

  // 4. Model sleeping or wake failure
  const isWakeFailed =
    errMessage.toLowerCase().includes('wake') || (apiCode && apiCode.includes('WAKE'));
  if (isWakeFailed) {
    return {
      code: 'WAKE_FAILED',
      visibleMessage: `Model wake failed. Wake the model manually in Models view. [WAKE_FAILED: ${errMessage}]`,
    };
  }
  if (modelStatus?.runtime_state === 'MODEL_SLEEPING') {
    return {
      code: 'MODEL_SLEEPING',
      visibleMessage: `Model is currently sleeping. Wake the model in Models view or retry to wake. [MODEL_SLEEPING: ${errMessage}]`,
    };
  }

  // 5. Model Not Loaded
  const isUnloaded =
    !modelStatus?.model_loaded ||
    modelStatus?.runtime_state === 'MODEL_UNLOADED' ||
    apiCode === 'LLM_UNAVAILABLE' ||
    errMessage.includes('LLM_UNAVAILABLE');
  if (isUnloaded) {
    return {
      code: 'MODEL_NOT_LOADED',
      visibleMessage: `No active model loaded. Ensure an LLM model is loaded in Models view. [MODEL_NOT_LOADED: ${errMessage}]`,
    };
  }

  // 6. Explicit model generation failure (SSE error event, GPU OOM, context overflow)
  if (
    apiCode === 'MODEL_GENERATION_FAILED' ||
    errMessage.toLowerCase().includes('gpu out of memory') ||
    errMessage.toLowerCase().includes('out of memory') ||
    errMessage.toLowerCase().includes('context') ||
    errMessage.toLowerCase().includes('generation failed')
  ) {
    return {
      code: 'MODEL_GENERATION_FAILED',
      visibleMessage: `Model generation failed: ${errMessage}. [MODEL_GENERATION_FAILED]`,
    };
  }

  // 7. Transport / Stream Connection failure while Core and Model are ready
  const isTransportError =
    errMessage.toLowerCase().includes('failed to fetch') ||
    errMessage.toLowerCase().includes('networkerror') ||
    errMessage.toLowerCase().includes('load failed') ||
    errMessage.toLowerCase().includes('stream failed with status 500') ||
    errMessage.toLowerCase().includes('internal server error');

  if (modelStatus?.model_loaded && isTransportError) {
    return {
      code: 'STREAM_CONNECTION_FAILED',
      visibleMessage: `Connection to the Assistant stream failed. Core and model status remain available. [STREAM_CONNECTION_FAILED: ${errMessage}]`,
    };
  }

  // 8. General / Fallback Model Generation Failure
  return {
    code: 'MODEL_GENERATION_FAILED',
    visibleMessage: `Model generation failed: ${errMessage}. [MODEL_GENERATION_FAILED]`,
  };
}

export interface AssistantViewProps {
  activeCharacterName?: string;
  userName?: string;
  assistantState?: AssistantState;
  onSetAssistantState?: (state: AssistantState) => void;
  currentModelName?: string;
}

export const AssistantView: React.FC<AssistantViewProps> = ({
  activeCharacterName = 'Aura',
  userName = 'Chris',
  assistantState: propAssistantState,
  onSetAssistantState,
  currentModelName,
}) => {
  const [internalAssistantState, setInternalAssistantState] = useState<AssistantState>('idle');
  const [historyOpen, setHistoryOpen] = useState(false);
  const [conversations, setConversations] = useState<ConversationOut[]>([]);
  const [activeConversationId, setActiveConversationId] = useState('conv-1');
  const [conversationTitle, setConversationTitle] = useState(
    'Daily Briefing & Local System Orchestration'
  );
  const [webSearchMode, setWebSearchMode] = useState<'airgapped' | 'web'>('airgapped');
  const [inputPrompt, setInputPrompt] = useState('');
  const [attachments, setAttachments] = useState<string[]>([]);

  const { isOnline, modelStatus, loadModel, isModelLoading, registry } = useBackend();
  const abortControllerRef = useRef<AbortController | null>(null);
  const messagesEndRef = useRef<HTMLDivElement | null>(null);
  const hasInitializedRef = useRef(false);
  const activeConversationIdRef = useRef(activeConversationId);
  activeConversationIdRef.current = activeConversationId;

  // Authoritative runtime model identity
  const activeModelId = modelStatus?.active_model || null;
  const activeModelEntry = registry.find(
    (m) => m.id === activeModelId || m.display_name === activeModelId
  );
  const effectiveModelName = isOnline
    ? (activeModelEntry ? activeModelEntry.display_name : (activeModelId || 'No Model Loaded'))
    : (currentModelName || 'Offline Demo');

  const isModelSleeping = isOnline && modelStatus?.runtime_state === 'MODEL_SLEEPING';
  const isModelAwake = isOnline && modelStatus?.runtime_state === 'MODEL_READY';
  const isModelUnloaded = isOnline && (!modelStatus?.model_loaded || modelStatus?.runtime_state === 'MODEL_UNLOADED');
  const isRouterOffline = isOnline && !modelStatus?.router_running;
  const isTransitioning = isOnline && (modelStatus?.runtime_state === 'SERVER_STARTING' || modelStatus?.runtime_state === 'MODEL_LOADING');

  // Truthful runtime badge label (no fake CUDA)
  const providerLabel = isOnline
    ? (modelStatus?.applied_profile
        ? `llama.cpp (${modelStatus.applied_profile.toUpperCase()})`
        : (modelStatus?.provider || 'llama.cpp'))
    : 'Offline Mode';

  const assistantState = propAssistantState !== undefined ? propAssistantState : internalAssistantState;
  const setAssistantState = (st: AssistantState) => {
    if (onSetAssistantState) {
      onSetAssistantState(st);
    } else {
      setInternalAssistantState(st);
    }
  };

  // Initial messages for offline / demo mode without fake CUDA or 42.8 t/s claims
  const [messages, setMessages] = useState<AssistantMessage[]>([
    {
      id: 'msg-1',
      type: 'system',
      timestamp: '10:00 AM',
      content:
        'Local AI Core session initialized. Airgap security enforcement verified.',
    },
    {
      id: 'msg-2',
      type: 'assistant',
      timestamp: '10:00 AM',
      content:
        `Good morning, ${userName}! Ready for your local workspace session. Connect to Local AI Core on port 8000 for live model streaming and tools.`,
    },
  ]);

  const loadConversationMessages = useCallback(async (convId: string) => {
    try {
      const res = await getMessages(convId);
      if (res.items && res.items.length > 0) {
        const mapped: AssistantMessage[] = res.items.map((m) => ({
          id: m.id,
          type: (m.sender === 'user' ? 'user' : (m.sender === 'system' ? 'system' : 'assistant')) as MessageType,
          sender: m.sender === 'user' ? userName : (m.sender === 'system' ? 'System' : activeCharacterName),
          timestamp: new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: m.content,
        }));
        setMessages(mapped);
      } else {
        setMessages([
          {
            id: `ast-${Date.now()}`,
            type: 'assistant',
            timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            content: `Ready for this session, ${userName}. What would you like to examine or execute?`,
          },
        ]);
      }
    } catch (err) {
      console.warn('Unable to load conversation messages:', err);
    }
  }, [activeCharacterName, userName]);

  useEffect(() => {
    let isMounted = true;
    async function initConversations() {
      if (!isOnline) return;

      try {
        const res = await listConversations();
        if (!isMounted) return;

        if (res.items && res.items.length > 0) {
          setConversations(res.items);

          // Preserve active conversation selection across reconnects
          const currentId = activeConversationIdRef.current;
          const matching = res.items.find((c) => c.id === currentId);

          if (matching) {
            setConversationTitle(matching.title);
            if (!hasInitializedRef.current) {
              loadConversationMessages(matching.id);
            }
          } else {
            const active = res.items[0];
            setActiveConversationId(active.id);
            setConversationTitle(active.title);
            loadConversationMessages(active.id);
          }
          hasInitializedRef.current = true;
        } else if (!hasInitializedRef.current) {
          const created = await createConversation('Daily Briefing & Local System Orchestration');
          if (!isMounted) return;
          setConversations([created]);
          setActiveConversationId(created.id);
          setConversationTitle(created.title);
          loadConversationMessages(created.id);
          hasInitializedRef.current = true;
        }
      } catch (err) {
        console.warn('Unable to initialize conversations from backend:', err);
      }
    }

    initConversations();
    return () => {
      isMounted = false;
    };
  }, [isOnline, loadConversationMessages]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView?.({ behavior: 'smooth' });
  }, [messages]);

  const formatStreamErrorMessage = (err: Error): string => {
    const isBusyErr = err.message?.includes('409') || err.message?.includes('BUSY');
    if (isBusyErr) {
      return '[Notice]: Model or conversation is currently busy. Please wait for previous generation to finish.';
    }

    return classifyStreamError(err, isOnline, modelStatus).visibleMessage;
  };

  // Handle Send Message with persistent SSE streaming
  const handleSendMessage = async () => {
    if (!inputPrompt.trim() && attachments.length === 0) return;
    if (isBusy) return;

    const userText = inputPrompt.trim() || 'Shared attachment for processing.';
    const clientMessageId = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `cl-${Date.now()}`;

    const userMsg: AssistantMessage = {
      id: clientMessageId,
      type: 'user',
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      content: userText,
    };

    const assistantMsgId = `ast-${Date.now() + 1}`;
    const assistantMsg: AssistantMessage = {
      id: assistantMsgId,
      type: 'assistant',
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      content: '',
    };

    setMessages((prev) => [...prev, userMsg, assistantMsg]);
    setInputPrompt('');
    setAttachments([]);

    setAssistantState('thinking');

    const controller = new AbortController();
    abortControllerRef.current = controller;

    let hasReceivedToken = false;

    try {
      await streamSendMessage({
        conversationId: activeConversationId,
        userText,
        clientMessageId,
        signal: controller.signal,
        onToken: (token) => {
          if (!hasReceivedToken) {
            hasReceivedToken = true;
            setAssistantState('speaking');
          }
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === assistantMsgId ? { ...msg, content: msg.content + token } : msg
            )
          );
        },
        onDone: () => {
          setAssistantState('idle');
          abortControllerRef.current = null;
        },
        onError: (err, partialText) => {
          setAssistantState('idle');
          abortControllerRef.current = null;

          setMessages((prev) =>
            prev.map((msg) => {
              if (msg.id !== assistantMsgId) return msg;
              const text = msg.content || partialText || '';
              if (!text) {
                return {
                  ...msg,
                  content: formatStreamErrorMessage(err),
                };
              } else {
                const classified = classifyStreamError(err, isOnline, modelStatus);
                return {
                  ...msg,
                  content: `${text}\n\n[Incomplete - ${classified.code}: ${err.message || 'Stream terminated'}]`,
                };
              }
            })
          );
        },
      });
    } catch (err: unknown) {
      setAssistantState('idle');
      abortControllerRef.current = null;
      const errorObj = err instanceof Error ? err : new Error(String(err));
      setMessages((prev) =>
        prev.map((msg) => {
          if (msg.id !== assistantMsgId) return msg;
          if (!msg.content) {
            return { ...msg, content: formatStreamErrorMessage(errorObj) };
          } else {
            const classified = classifyStreamError(errorObj, isOnline, modelStatus);
            return { ...msg, content: `${msg.content}\n\n[Incomplete - ${classified.code}: ${errorObj.message}]` };
          }
        })
      );
    }
  };

  const handleStopGeneration = () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
      abortControllerRef.current = null;
    }
    setAssistantState('idle');

    // Ensure the in-flight assistant bubble is never left blank
    setMessages((prev) => {
      const lastMsg = prev[prev.length - 1];
      if (lastMsg && lastMsg.type === 'assistant') {
        const stopNotice = '*[Generation stopped by user]* [USER_CANCELLED]';
        if (!lastMsg.content) {
          return [
            ...prev.slice(0, -1),
            { ...lastMsg, content: stopNotice },
          ];
        } else if (!lastMsg.content.includes('*[Generation stopped by user]*')) {
          return [
            ...prev.slice(0, -1),
            { ...lastMsg, content: `${lastMsg.content}\n\n${stopNotice}` },
          ];
        }
      }
      return prev;
    });
  };

  const handleNewConversation = async () => {
    try {
      const created = await createConversation('New Conversation');
      setConversations((prev) => [created, ...prev]);
      setActiveConversationId(created.id);
      setConversationTitle(created.title);
      setAssistantState('idle');
      setMessages([
        {
          id: `sys-${Date.now()}`,
          type: 'system',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: `New session initialized. Context buffer cleared. Pinned model: ${effectiveModelName}.`,
        },
        {
          id: `ast-${Date.now()}`,
          type: 'assistant',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: `Ready for a new session, ${userName}. What would you like to examine or execute?`,
        },
      ]);
    } catch (err) {
      console.warn('Failed to create remote conversation:', err);
      const fallbackId = `conv-${Date.now()}`;
      setActiveConversationId(fallbackId);
      setConversationTitle('Local Session (Offline)');
      setAssistantState('idle');
      setMessages([
        {
          id: `sys-${Date.now()}`,
          type: 'system',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: `Local session created offline. Pinned model: ${effectiveModelName}.`,
        },
        {
          id: `ast-${Date.now()}`,
          type: 'assistant',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: `Ready for a new session, ${userName}. Note: Server is offline, so messages will not persist to SQLite until reconnected.`,
        },
      ]);
    }
  };

  const handleSelectConversation = (id: string) => {
    setActiveConversationId(id);
    const found = conversations.find((c) => c.id === id);
    if (found) {
      setConversationTitle(found.title);
    } else {
      const mockFound = mockConversations.find((c) => c.id === id);
      if (mockFound) setConversationTitle(mockFound.title);
    }
    loadConversationMessages(id);
  };

  // Assistant State Status Label (authoritative runtime truth)
  const getAssistantStateDisplay = () => {
    if (!isOnline) {
      return { label: 'Offline', color: 'text-[var(--color-text-muted)]', desc: 'Core server offline — demo mode' };
    }
    if (isRouterOffline) {
      return { label: 'Router Stopped', color: 'text-amber-500', desc: 'Core online, llama.cpp router not running' };
    }
    if (isTransitioning) {
      return { label: 'Restarting / Loading', color: 'text-amber-500 animate-pulse', desc: 'Applying runtime changes' };
    }
    if (isModelSleeping) {
      return { label: 'Sleeping', color: 'text-purple-400', desc: 'Model sleeping in RAM (VRAM released)' };
    }
    if (isModelUnloaded) {
      return { label: 'No Model Loaded', color: 'text-amber-500', desc: 'Model weights unloaded from memory' };
    }

    switch (assistantState) {
      case 'idle':
        return { label: 'Idle / Standby', color: 'text-emerald-500', desc: 'Standing by for user query' };
      case 'listening':
        return { label: 'Listening (VAD Active)', color: 'text-sky-400 animate-pulse', desc: 'Streaming audio from microphone' };
      case 'thinking':
        return { label: 'Thinking / Reasoning', color: 'text-amber-500 animate-pulse', desc: 'Evaluating prompt tokens' };
      case 'executing_tool':
        return { label: 'Executing Tool', color: 'text-purple-400 animate-pulse', desc: 'Calling local workspace runtime' };
      case 'speaking':
        return { label: 'Speaking / Streaming', color: 'text-[var(--color-accent)] animate-pulse', desc: 'Synthesizing output tokens' };
      case 'interrupted':
        return { label: 'Interrupted', color: 'text-orange-400', desc: 'Generation halted by user' };
      case 'offline':
        return { label: 'Offline', color: 'text-[var(--color-text-muted)]', desc: 'Local engine disconnected' };
      case 'error':
        return { label: 'Error / OOM Notice', color: 'text-rose-500', desc: 'Context or VRAM overflow notice' };
      default:
        return { label: 'Idle', color: 'text-emerald-500', desc: 'Ready' };
    }
  };

  const stateDisplay = getAssistantStateDisplay();
  const isBusy = assistantState === 'thinking' || assistantState === 'speaking' || assistantState === 'executing_tool';

  const drawerConversations: ConversationHistoryItem[] =
    conversations.length > 0
      ? conversations.map((c) => ({
          id: c.id,
          title: c.title,
          date: new Date(c.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' }),
          snippet: 'Local conversation session stored in SQLite.',
          model: effectiveModelName,
          messagesCount: c.id === activeConversationId ? messages.length : 1,
        }))
      : mockConversations;

  return (
    <div className="space-y-6">
      {/* ========================================================= */}
      {/* 1. HEADER: Personal AI Workspace Bar                      */}
      {/* ========================================================= */}
      <div className="p-5 sm:p-6 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] space-y-4">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          {/* Conversation Title & Drawer Trigger */}
          <div className="flex items-center gap-3 min-w-0">
            <button
              type="button"
              onClick={() => setHistoryOpen(true)}
              className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-primary)] transition-all flex-shrink-0 relative group"
              title="Open Conversation History"
            >
              <History className="w-5 h-5 text-[var(--color-accent)] group-hover:scale-105 transition-transform" />
              <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-[var(--color-accent)] text-white text-[9px] font-bold flex items-center justify-center shadow-sm">
                {drawerConversations.length}
              </span>
            </button>

            <div className="truncate">
              <div className="flex items-center gap-2">
                <h1 className="text-base sm:text-lg font-bold text-[var(--color-text-primary)] truncate">
                  {conversationTitle}
                </h1>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] font-mono truncate">
                Active Persona: <strong className="text-[var(--color-text-primary)]">{activeCharacterName}</strong> • Low-Latency Loopback
              </p>
            </div>
          </div>

          {/* Model / Runtime / Mode Indicators & New Conversation */}
          <div className="flex flex-wrap items-center gap-2 flex-shrink-0">
            {/* Model Badge */}
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-primary)]">
              <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              <span className="font-semibold truncate max-w-[150px]" title={effectiveModelName}>
                {effectiveModelName}
              </span>
              {isOnline && isModelSleeping && (
                <span className="px-1.5 py-0.5 rounded bg-purple-500/20 text-purple-400 text-[10px] font-bold">
                  Sleeping
                </span>
              )}
              {isOnline && isModelAwake && (
                <span className="px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 text-[10px] font-bold">
                  Awake
                </span>
              )}
              {isOnline && isModelUnloaded && (
                <span className="px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-400 text-[10px] font-bold">
                  Unloaded
                </span>
              )}
            </div>

            {/* Runtime / Provider */}
            <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-secondary)]">
              <span>{providerLabel}</span>
            </div>

            {/* Local / Cloud Indicator */}
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono font-semibold">
              {isOnline ? (
                <>
                  <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
                  <span className="text-emerald-500 hidden md:inline">100% Local Airgapped</span>
                  <span className="text-emerald-500 md:hidden">Local</span>
                </>
              ) : (
                <>
                  <AlertCircle className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
                  <span className="text-[var(--color-text-muted)]">Core Offline (Demo)</span>
                </>
              )}
            </div>

            {/* Search / Web Mode Indicator */}
            <button
              type="button"
              onClick={() => setWebSearchMode(webSearchMode === 'airgapped' ? 'web' : 'airgapped')}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border text-xs font-mono transition-all ${
                webSearchMode === 'airgapped'
                  ? 'surface-raised border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  : 'bg-accent-gradient text-white border-[var(--color-accent)] shadow-sm'
              }`}
              title="Click to toggle between airgapped local docs and simulated web search"
            >
              <Globe className="w-3.5 h-3.5" />
              <span className="hidden lg:inline">
                {webSearchMode === 'airgapped' ? 'Search: Airgapped Docs' : 'Search: Web Simulated'}
              </span>
              <span className="lg:hidden">
                {webSearchMode === 'airgapped' ? 'Airgap Docs' : 'Web Mode'}
              </span>
            </button>

            {/* New Conversation Action */}
            <NeumorphicButton
              size="sm"
              variant="primary"
              icon={<Plus className="w-3.5 h-3.5 text-white" />}
              onClick={handleNewConversation}
            >
              New Chat
            </NeumorphicButton>
          </div>
        </div>

        {/* ========================================================= */}
        {/* 2. ASSISTANT VISUAL STATES BAR                            */}
        {/* ========================================================= */}
        <div className="pt-3 border-t border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
              Status:
            </span>
            <div className="flex items-center gap-2 px-2.5 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)]">
              <span className={`text-xs font-bold font-mono ${stateDisplay.color}`}>
                ● {stateDisplay.label}
              </span>
              <span className="text-[11px] text-[var(--color-text-muted)] hidden sm:inline">
                — {stateDisplay.desc}
              </span>
            </div>
          </div>

          {/* Interactive Visual State Switcher Chips */}
          <div className="flex items-center gap-1 overflow-x-auto pb-1 md:pb-0">
            <span className="text-[10px] font-mono text-[var(--color-text-muted)] mr-1 flex-shrink-0">
              Mock State:
            </span>
            {(
              [
                { id: 'idle', label: 'Idle' },
                { id: 'listening', label: 'Listening' },
                { id: 'thinking', label: 'Thinking' },
                { id: 'executing_tool', label: 'Tool' },
                { id: 'speaking', label: 'Speaking' },
                { id: 'interrupted', label: 'Interrupted' },
                { id: 'offline', label: 'Offline' },
                { id: 'error', label: 'Error' },
              ] as const
            ).map((st) => (
              <button
                key={st.id}
                type="button"
                onClick={() => setAssistantState(st.id)}
                className={`px-2 py-0.5 rounded-lg text-[10px] font-mono font-medium transition-all flex-shrink-0 ${
                  assistantState === st.id
                    ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                    : 'surface-recessed text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                {st.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 3. CONVERSATION STREAM                                    */}
      {/* ========================================================= */}
      <div className="space-y-4 max-w-4xl mx-auto min-h-[380px] p-2">
        {messages.map((msg) => (
          <ConversationMessageItem
            key={msg.id}
            message={msg}
            userName={userName}
            activeCharacterName={activeCharacterName}
          />
        ))}

        {/* Live Visual Indicators for Ongoing Assistant States */}
        {isBusy && (
          <div className="flex items-center gap-3 my-3 max-w-xl">
            <div className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-white text-xs font-bold shadow-sm glow-accent-sm animate-pulse">
              <Bot className="w-4 h-4" />
            </div>
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center gap-3 text-xs font-mono text-[var(--color-text-secondary)]">
              <span className="w-2 h-2 rounded-full bg-[var(--color-accent)] animate-ping" />
              <span>
                {assistantState === 'thinking' && 'Reasoning & processing context...'}
                {assistantState === 'executing_tool' && 'Executing tool function on local runtime...'}
                {assistantState === 'speaking' && 'Streaming response tokens in real time...'}
              </span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* ========================================================= */}
      {/* 4. INPUT COMPOSER: Polished Soft Glass Docked Composer    */}
      {/* ========================================================= */}
      <div className="sticky bottom-4 z-20 max-w-4xl mx-auto">
        {/* Sleeping Model Notice */}
        {isModelSleeping && (
          <div className="p-3 mb-2 rounded-2xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-between text-xs text-purple-300">
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-purple-400 flex-shrink-0" />
              <span>Model is sleeping in RAM (VRAM released). Sending a message will wake the model.</span>
            </div>
            <span className="text-[11px] font-mono px-2 py-0.5 rounded bg-purple-500/20 text-purple-300">
              Native Sleep
            </span>
          </div>
        )}

        {/* Unloaded Model Alert Notice */}
        {isModelUnloaded && !isRouterOffline && (
          <div className="p-3 mb-2 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between text-xs text-amber-400">
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 flex-shrink-0" />
              <span>No model is currently loaded. Click Load Model or choose a model from the Models tab.</span>
            </div>
            <button
              type="button"
              disabled={isModelLoading}
              onClick={() => loadModel()}
              className="px-3 py-1 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 font-semibold flex items-center gap-1.5 transition-all disabled:opacity-50"
            >
              {isModelLoading ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Zap className="w-3.5 h-3.5" />}
              <span>Load Model</span>
            </button>
          </div>
        )}

        <div className="p-3 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-2xl space-y-2.5">
          {/* Attachment Tags (if added) */}
          {attachments.length > 0 && (
            <div className="flex flex-wrap items-center gap-2 px-2 pt-1">
              {attachments.map((file, idx) => (
                <span
                  key={idx}
                  className="px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] font-mono text-[var(--color-accent)] flex items-center gap-1.5"
                >
                  <Paperclip className="w-3 h-3" />
                  {file}
                  <button
                    type="button"
                    onClick={() => setAttachments(attachments.filter((_, i) => i !== idx))}
                    className="hover:text-rose-500 ml-1"
                  >
                    ×
                  </button>
                </span>
              ))}
            </div>
          )}

          {/* Main Input Row */}
          <div className="flex items-center gap-2">
            {/* Attachment Button */}
            <button
              type="button"
              onClick={() =>
                setAttachments((prev) => [...prev, `doc_spec_v${prev.length + 1}.md`])
              }
              className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-all flex-shrink-0"
              title="Add attachment / reference document"
            >
              <Paperclip className="w-4 h-4" />
            </button>

            {/* Input Field */}
            <input
              type="text"
              value={inputPrompt}
              onChange={(e) => setInputPrompt(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  handleSendMessage();
                }
              }}
              placeholder={`Message ${activeCharacterName} or run slash commands (/schedule, /task, /health)...`}
              className="flex-1 bg-transparent px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none"
            />

            {/* Microphone Toggle (Simulate listening state) */}
            <button
              type="button"
              onClick={() =>
                setAssistantState(assistantState === 'listening' ? 'idle' : 'listening')
              }
              className={`w-10 h-10 rounded-2xl border flex items-center justify-center transition-all flex-shrink-0 ${
                assistantState === 'listening'
                  ? 'bg-rose-500/15 border-rose-500 text-rose-500 font-bold animate-pulse'
                  : 'surface-raised border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-accent)]'
              }`}
              title={assistantState === 'listening' ? 'Stop listening' : 'Voice input (VAD)'}
            >
              {assistantState === 'listening' ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
            </button>

            {/* Stop Generation Button (when busy) */}
            {isBusy && (
              <button
                type="button"
                onClick={handleStopGeneration}
                className="w-10 h-10 rounded-2xl bg-orange-500/15 border border-orange-500/40 text-orange-400 hover:bg-orange-500/25 flex items-center justify-center transition-all flex-shrink-0"
                title="Stop generation"
              >
                <Square className="w-4 h-4 fill-current" />
              </button>
            )}

            {/* Send Button */}
            <button
              type="button"
              onClick={handleSendMessage}
              disabled={!inputPrompt.trim() && attachments.length === 0}
              className="w-10 h-10 rounded-2xl bg-accent-gradient text-white flex items-center justify-center shadow-md glow-accent-sm disabled:opacity-40 disabled:cursor-not-allowed hover:scale-105 active:scale-95 transition-all flex-shrink-0"
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
              {modelStatus?.applied_context_size
                ? `Context buffer: ${modelStatus.applied_context_size} tokens`
                : 'Local context buffer: active'}
            </span>
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 5. CONVERSATION HISTORY DRAWER                            */}
      {/* ========================================================= */}
      <ConversationHistoryDrawer
        isOpen={historyOpen}
        onClose={() => setHistoryOpen(false)}
        activeConversationId={activeConversationId}
        onSelectConversation={handleSelectConversation}
        onNewConversation={handleNewConversation}
        conversations={drawerConversations}
      />
    </div>
  );
};
