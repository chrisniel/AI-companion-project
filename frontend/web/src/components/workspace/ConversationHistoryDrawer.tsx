import React, { useState } from 'react';
import {
  History,
  X,
  Search,
  Plus,
  MessageSquare,
  ChevronRight,
  Clock,
  Cpu,
  Trash2,
} from 'lucide-react';
import { SearchInput } from '../ui/SearchInput';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { ConversationHistoryItem } from '../../types';

export interface ConversationHistoryDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  activeConversationId: string;
  onSelectConversation: (id: string) => void;
  onNewConversation: () => void;
}

export const mockConversations: ConversationHistoryItem[] = [
  {
    id: 'conv-1',
    title: 'Daily Briefing & Local System Orchestration',
    date: 'Today, 10:30 AM',
    snippet: 'Inspected local task queue, verified vector memory consolidation cron at 04:00 AM...',
    model: 'Llama-3.1-8B-Instruct',
    messagesCount: 8,
  },
  {
    id: 'conv-2',
    title: 'CUDA Kernel Tuning for Quantized Weights',
    date: 'Today, 08:15 AM',
    snippet: 'Benchmarked FP16 vs Q4_K_M matrix multiplication throughput on RTX 4090...',
    model: 'Qwen-2.5-Coder-7B',
    messagesCount: 14,
  },
  {
    id: 'conv-3',
    title: 'Biometric Telemetry & Sleep Cycle Correlation',
    date: 'Yesterday, 09:40 PM',
    snippet: 'Evaluated resting heart rate and REM sleep trends with ambient room temperature logs...',
    model: 'Llama-3.1-8B-Instruct',
    messagesCount: 6,
  },
  {
    id: 'conv-4',
    title: 'Zero-Telemetry Packet Filter Inspection',
    date: 'Yesterday, 03:20 PM',
    snippet: 'Confirmed loopback binding rules on port 8000; blocked all outgoing DNS requests...',
    model: 'Llama-3.1-8B-Instruct',
    messagesCount: 5,
  },
  {
    id: 'conv-5',
    title: 'Audio VAD Threshold Calibration & Echo Cancellation',
    date: 'Sep 7, 11:15 AM',
    snippet: 'Configured studio microphone array noise gate at -34dB for hands-free voice synthesis...',
    model: 'Gemma-2-9B-IT',
    messagesCount: 11,
  },
];

export const ConversationHistoryDrawer: React.FC<ConversationHistoryDrawerProps> = ({
  isOpen,
  onClose,
  activeConversationId,
  onSelectConversation,
  onNewConversation,
}) => {
  const [searchQuery, setSearchQuery] = useState('');

  if (!isOpen) return null;

  const filteredConversations = mockConversations.filter(
    (c) =>
      c.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.snippet.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.model.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="fixed inset-0 z-50 flex">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
        onClick={onClose}
      />

      {/* Drawer Panel */}
      <div className="relative w-full max-w-sm sm:max-w-md h-full glass-panel-elevated border-r border-[var(--color-surface-glass-border)] shadow-2xl flex flex-col z-10 animate-in slide-in-from-left duration-200">
        {/* Drawer Header */}
        <div className="h-16 px-5 border-b border-[var(--color-border-subtle)] flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm">
              <History className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-sm font-bold text-[var(--color-text-primary)]">
                Conversation History
              </h2>
              <p className="text-[11px] text-[var(--color-text-muted)] font-mono">
                {mockConversations.length} Local Sessions
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-all"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Action & Search */}
        <div className="p-4 space-y-3 border-b border-[var(--color-border-subtle)] flex-shrink-0">
          <NeumorphicButton
            variant="primary"
            size="sm"
            icon={<Plus className="w-4 h-4 text-white" />}
            onClick={() => {
              onNewConversation();
              onClose();
            }}
            className="w-full justify-center"
          >
            New Conversation
          </NeumorphicButton>

          <SearchInput
            value={searchQuery}
            onChangeValue={setSearchQuery}
            placeholder="Search past conversations..."
            sizeVariant="sm"
          />
        </div>

        {/* Conversation List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-2.5">
          {filteredConversations.length === 0 ? (
            <div className="text-center py-10 text-xs text-[var(--color-text-muted)] font-mono">
              No conversations found matching &quot;{searchQuery}&quot;
            </div>
          ) : (
            filteredConversations.map((conv) => {
              const isActive = conv.id === activeConversationId;
              return (
                <div
                  key={conv.id}
                  onClick={() => {
                    onSelectConversation(conv.id);
                    onClose();
                  }}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      onSelectConversation(conv.id);
                      onClose();
                    }
                  }}
                  className={`p-3.5 rounded-2xl border cursor-pointer transition-all text-left space-y-2 ${
                    isActive
                      ? 'surface-raised border-[var(--color-accent)] shadow-sm'
                      : 'surface-recessed border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/30'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <h3 className="text-xs font-bold text-[var(--color-text-primary)] line-clamp-1">
                      {conv.title}
                    </h3>
                    <Badge variant={isActive ? 'accent' : 'glass'} size="sm">
                      {conv.messagesCount} msgs
                    </Badge>
                  </div>

                  <p className="text-[11px] text-[var(--color-text-secondary)] line-clamp-2 leading-relaxed">
                    {conv.snippet}
                  </p>

                  <div className="flex items-center justify-between pt-1 border-t border-[var(--color-border-subtle)] text-[10px] font-mono text-[var(--color-text-muted)]">
                    <span className="flex items-center gap-1">
                      <Clock className="w-3 h-3 text-[var(--color-text-muted)]" />
                      {conv.date}
                    </span>
                    <span className="text-[var(--color-accent)] font-semibold truncate max-w-[120px]">
                      {conv.model.replace('-Instruct', '')}
                    </span>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Drawer Footer */}
        <div className="p-3.5 border-t border-[var(--color-border-subtle)] text-center text-[10px] text-[var(--color-text-muted)] font-mono">
          Local SQLite storage • 100% Private on-device
        </div>
      </div>
    </div>
  );
};
