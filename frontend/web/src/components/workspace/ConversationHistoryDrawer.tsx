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
  conversations?: ConversationHistoryItem[];
}

export const ConversationHistoryDrawer: React.FC<ConversationHistoryDrawerProps> = ({
  isOpen,
  onClose,
  activeConversationId,
  onSelectConversation,
  onNewConversation,
  conversations = [],
}) => {
  const [searchQuery, setSearchQuery] = useState('');

  if (!isOpen) return null;

  const conversationList = conversations;

  const filteredConversations = conversationList.filter(
    (c) =>
      c.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (c.snippet ? c.snippet.toLowerCase().includes(searchQuery.toLowerCase()) : false) ||
      (c.model ? c.model.toLowerCase().includes(searchQuery.toLowerCase()) : false)
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
                {conversationList.length} Local Sessions
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
              {searchQuery.trim()
                ? `No conversations found matching "${searchQuery}"`
                : 'No conversations yet'}
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
                    {conv.messagesCount != null && (
                      <Badge variant={isActive ? 'accent' : 'glass'} size="sm">
                        {conv.messagesCount} msgs
                      </Badge>
                    )}
                  </div>

                  {conv.snippet && (
                    <p className="text-[11px] text-[var(--color-text-secondary)] line-clamp-2 leading-relaxed">
                      {conv.snippet}
                    </p>
                  )}

                  <div className="flex items-center justify-between pt-1 border-t border-[var(--color-border-subtle)] text-[10px] font-mono text-[var(--color-text-muted)]">
                    <span className="flex items-center gap-1">
                      <Clock className="w-3 h-3 text-[var(--color-text-muted)]" />
                      {conv.date}
                    </span>
                    {conv.model && (
                      <span className="text-[var(--color-accent)] font-semibold truncate max-w-[120px]">
                        {conv.model.replace('-Instruct', '')}
                      </span>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Drawer Footer */}
        <div className="p-3.5 border-t border-[var(--color-border-subtle)] text-center text-[10px] text-[var(--color-text-muted)] font-mono">
          Local conversation storage
        </div>
      </div>
    </div>
  );
};
