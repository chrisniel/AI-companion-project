import React, { useState } from 'react';
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
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { StatusIndicator } from '../ui/StatusIndicator';
import {
  AssistantMessage,
  AssistantState,
  ConversationHistoryItem,
} from '../../types';
import {
  ConversationHistoryDrawer,
  mockConversations,
} from './ConversationHistoryDrawer';
import { ConversationMessageItem } from './ConversationMessageItem';

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
  currentModelName = 'Llama-3.1-8B-Instruct',
}) => {
  const [internalAssistantState, setInternalAssistantState] = useState<AssistantState>('idle');
  const [historyOpen, setHistoryOpen] = useState(false);
  const [activeConversationId, setActiveConversationId] = useState('conv-1');
  const [conversationTitle, setConversationTitle] = useState(
    'Daily Briefing & Local System Orchestration'
  );
  const [webSearchMode, setWebSearchMode] = useState<'airgapped' | 'web'>('airgapped');
  const [inputPrompt, setInputPrompt] = useState('');
  const [attachments, setAttachments] = useState<string[]>([]);

  const assistantState = propAssistantState !== undefined ? propAssistantState : internalAssistantState;
  const setAssistantState = (st: AssistantState) => {
    if (onSetAssistantState) {
      onSetAssistantState(st);
    } else {
      setInternalAssistantState(st);
    }
  };

  // Mock conversation stream containing all required message types & tool cards
  const [messages, setMessages] = useState<AssistantMessage[]>([
    {
      id: 'msg-1',
      type: 'system',
      timestamp: '10:15 AM',
      content:
        'Local neural core initialized (Port 8000). Model: Llama-3.1-8B-Instruct (Q4_K_M). 33 GPU layers offloaded. Airgap security enforcement verified.',
    },
    {
      id: 'msg-2',
      type: 'user',
      timestamp: '10:16 AM',
      content:
        'Morning Aura! Can you pull my upcoming schedule, check if my sleep and health stats synced, and log a task for verifying our local GGUF quantizations?',
    },
    {
      id: 'msg-3',
      type: 'memory_retrieval',
      timestamp: '10:16 AM',
      content:
        'User prefers morning focus blocks between 02:00 PM and 04:00 PM with non-essential audio muted. Quantization priority: FP16 -> Q4_K_M matrix accuracy.',
      memoryMetadata: {
        query: 'schedule preferences and quantization tasks',
        similarity: '0.94',
        source: 'bge-large-en-v1.5 (local HNSW)',
      },
    },
    {
      id: 'msg-4',
      type: 'tool_execution',
      timestamp: '10:16 AM',
      content: 'Retrieved 3 events from local workstation schedule.',
      toolCard: {
        toolName: 'Schedule',
        action: 'Completed',
        summary: 'Retrieved 3 events for today',
        status: 'completed',
        details: {
          '02:30 PM': 'Deep Work: Core Neural Pipeline Optimization (60m)',
          '04:00 PM': 'Vector Memory Backup & Export',
          '06:00 PM': 'Evening Audio Briefing Checkpoint',
        },
      },
    },
    {
      id: 'msg-5',
      type: 'tool_execution',
      timestamp: '10:16 AM',
      content: 'Retrieved biometric wellness summary from Bluetooth BLE sync.',
      toolCard: {
        toolName: 'Health',
        action: 'Completed',
        summary: 'Retrieved wellness summary',
        status: 'completed',
        details: {
          Sleep: '7h 48m (88% sleep score, Deep 1h 45m)',
          'Resting HR': '64 bpm (Daily range: 58 - 114 bpm)',
          Activity: '8,420 steps (84% of 10k target)',
        },
      },
    },
    {
      id: 'msg-6',
      type: 'tool_execution',
      timestamp: '10:17 AM',
      content: 'Created operational workspace reminder task.',
      toolCard: {
        toolName: 'Task',
        action: 'Created',
        summary: 'Project reminder: Verify GGUF quantizations',
        status: 'completed',
        details: {
          'Queue Position': 'Priority 1 (Workspace Queue)',
          'Assigned Model': 'Llama-3.1-8B-Instruct',
          Deadline: 'Today before 04:00 PM',
        },
      },
    },
    {
      id: 'msg-7',
      type: 'web_search',
      timestamp: '10:17 AM',
      content:
        'Queried local documentation index for "CUDA kernel tuning & GGUF benchmarks". Retrieved 3 reference documents from local repository.',
      searchMetadata: {
        query: 'CUDA kernel tuning benchmarks',
        resultsCount: 3,
        source: 'Local Docs & Wiki',
      },
    },
    {
      id: 'msg-8',
      type: 'assistant',
      timestamp: '10:17 AM',
      content:
        'Good morning, Chris! Everything is set for your day:\n\n1. **Schedule**: Your main scheduled session is *Deep Work: Core Neural Pipeline Optimization* at 02:30 PM (60 minutes). I have queued reminders for vector exports at 04:00 PM.\n2. **Health**: Your telemetry synced cleanly 10 minutes ago — 7h 48m sleep with 88% readiness, resting HR steady at 64 bpm, and 8,420 steps logged.\n3. **Task Queued**: Created your project task *"Verify GGUF quantizations"* in the operational queue for this afternoon.\n\nAll background engines are nominal and running 100% on-device.',
    },
    {
      id: 'msg-9',
      type: 'warning',
      timestamp: '10:18 AM',
      content:
        'Context window buffer utilization is currently at 4,820 / 16,384 tokens (29%). Local KV cache is performing smoothly at 42.8 tokens/second.',
    },
  ]);

  // Handle Send Message
  const handleSendMessage = () => {
    if (!inputPrompt.trim() && attachments.length === 0) return;

    const userMsg: AssistantMessage = {
      id: `msg-${Date.now()}`,
      type: 'user',
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      content: inputPrompt.trim() || 'Shared attachment for processing.',
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputPrompt('');
    setAttachments([]);

    // Simulate Assistant Workflow
    setAssistantState('thinking');

    setTimeout(() => {
      setAssistantState('executing_tool');
    }, 1000);

    setTimeout(() => {
      setAssistantState('speaking');
      const responseMsg: AssistantMessage = {
        id: `msg-${Date.now() + 1}`,
        type: 'assistant',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        content: `I processed your request using local weights. All inference occurred on-device via your GPU with 0ms cloud latency. Ready for your next command.`,
      };
      setMessages((prev) => [...prev, responseMsg]);
    }, 2400);

    setTimeout(() => {
      setAssistantState('idle');
    }, 3800);
  };

  const handleStopGeneration = () => {
    setAssistantState('interrupted');
    setTimeout(() => {
      setAssistantState('idle');
    }, 1500);
  };

  const handleNewConversation = () => {
    setActiveConversationId(`conv-${Date.now()}`);
    setConversationTitle('New Local Workspace Session');
    setAssistantState('idle');
    setMessages([
      {
        id: `sys-${Date.now()}`,
        type: 'system',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        content: `New session initialized. Context buffer cleared. Pinned model: ${currentModelName}.`,
      },
      {
        id: `ast-${Date.now()}`,
        type: 'assistant',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        content: `Ready for a new session, ${userName}. What would you like to examine or execute?`,
      },
    ]);
  };

  const handleSelectConversation = (id: string) => {
    setActiveConversationId(id);
    const found = mockConversations.find((c) => c.id === id);
    if (found) {
      setConversationTitle(found.title);
    }
  };

  // Assistant State Status Label
  const getAssistantStateDisplay = () => {
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
        return { label: 'Speaking / Streaming', color: 'text-[var(--color-accent)] animate-pulse', desc: 'Synthesizing output @ 42.8 t/s' };
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
                5
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
              <span className="font-semibold truncate max-w-[130px]">{currentModelName}</span>
            </div>

            {/* Runtime / Provider */}
            <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-secondary)]">
              <span>llama.cpp (CUDA)</span>
            </div>

            {/* Local / Cloud Indicator */}
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono text-emerald-500 font-semibold">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span className="hidden md:inline">100% Local Airgapped</span>
              <span className="md:hidden">Local</span>
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
                {assistantState === 'speaking' && 'Streaming response tokens @ 42.8 t/s...'}
              </span>
            </div>
          </div>
        )}
      </div>

      {/* ========================================================= */}
      {/* 4. INPUT COMPOSER: Polished Soft Glass Docked Composer    */}
      {/* ========================================================= */}
      <div className="sticky bottom-4 z-20 max-w-4xl mx-auto">
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
            <span>Local token cache: 16k buffer</span>
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
      />
    </div>
  );
};
