import React, { useEffect, useRef } from 'react';
import { Bot } from 'lucide-react';
import { AssistantMessage, AssistantState } from '../../../types';
import { ConversationMessageItem } from '../ConversationMessageItem';

export interface AssistantMessageListProps {
  messages: AssistantMessage[];
  userName: string;
  activeCharacterName: string;
  isBusy: boolean;
  assistantState: AssistantState;
}

export const AssistantMessageList: React.FC<AssistantMessageListProps> = ({
  messages,
  userName,
  activeCharacterName,
  isBusy,
  assistantState,
}) => {
  const messagesEndRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView?.({ behavior: 'smooth' });
  }, [messages]);

  return (
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
  );
};
