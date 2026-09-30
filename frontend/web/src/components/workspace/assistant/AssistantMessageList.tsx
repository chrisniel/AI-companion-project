import React, { useEffect, useRef, useState } from 'react';
import { Bot, ChevronDown } from 'lucide-react';
import { AssistantMessage, AssistantState } from '../../../types';
import { ConversationMessageItem } from '../ConversationMessageItem';

export interface AssistantMessageListProps {
  messages: AssistantMessage[];
  userName: string;
  activeCharacterName: string;
  isBusy: boolean;
  assistantState: AssistantState;
  activeConversationId?: string;
}

export const AssistantMessageList: React.FC<AssistantMessageListProps> = ({
  messages,
  userName,
  activeCharacterName,
  isBusy,
  assistantState,
  activeConversationId,
}) => {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const isNearBottomRef = useRef<boolean>(true);
  const [showScrollBottom, setShowScrollBottom] = useState<boolean>(false);

  const handleScroll = () => {
    if (!containerRef.current) return;
    const { scrollTop, scrollHeight, clientHeight } = containerRef.current;
    const isNear = scrollHeight - scrollTop - clientHeight < 120;
    isNearBottomRef.current = isNear;
    setShowScrollBottom(!isNear && messages.length > 3);
  };

  const scrollToBottom = (behavior: ScrollBehavior = 'smooth') => {
    if (!containerRef.current) return;
    if (typeof containerRef.current.scrollTo === 'function') {
      containerRef.current.scrollTo({
        top: containerRef.current.scrollHeight,
        behavior,
      });
    } else {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  };

  // Only auto-scroll when near bottom
  useEffect(() => {
    if (isNearBottomRef.current) {
      scrollToBottom('smooth');
    }
  }, [messages]);

  return (
    <div
      ref={containerRef}
      onScroll={handleScroll}
      className="h-full overflow-y-auto px-2 sm:px-4 py-4 space-y-4 max-w-4xl mx-auto relative scroll-smooth"
      data-testid="assistant-messages-container"
    >
      {/* Empty State */}
      {messages.length === 0 && (
        <div className="h-full min-h-[320px] flex flex-col items-center justify-center text-center p-6 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-accent-gradient flex items-center justify-center text-white shadow-md glow-accent-sm">
            <Bot className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-sm">
            <h2 className="text-base font-bold text-[var(--color-text-primary)]">
              Conversation with {activeCharacterName}
            </h2>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Send a prompt to begin your local companion conversation.
            </p>
          </div>
        </div>
      )}

      {/* Populated Messages */}
      {messages.map((msg) => (
        <ConversationMessageItem
          key={msg.id}
          message={msg}
          userName={userName}
          activeCharacterName={activeCharacterName}
          activeConversationId={activeConversationId}
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

      {/* Floating Scroll to Bottom Button */}
      {showScrollBottom && (
        <div className="sticky bottom-2 flex justify-center z-10 pointer-events-none">
          <button
            type="button"
            onClick={() => scrollToBottom('smooth')}
            className="pointer-events-auto flex items-center gap-1.5 px-3 py-1.5 rounded-full surface-raised border border-[var(--color-border-subtle)] shadow-lg hover:border-[var(--color-accent)]/50 text-xs font-medium text-[var(--color-text-primary)] transition-all backdrop-blur-sm"
          >
            <ChevronDown className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>Scroll to bottom</span>
          </button>
        </div>
      )}
    </div>
  );
};
