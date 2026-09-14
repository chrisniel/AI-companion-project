import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useBackend } from '../../context/BackendContext';
import {
  listConversations,
  createConversation,
  getMessages,
  streamSendMessage,
  ConversationOut,
} from '../../services/api';
import {
  AssistantMessage,
  AssistantState,
  ConversationHistoryItem,
  MessageType,
} from '../../types';
import { ConversationHistoryDrawer } from './ConversationHistoryDrawer';
import { AssistantComposer } from './assistant/AssistantComposer';
import { AssistantMessageList } from './assistant/AssistantMessageList';
import { AssistantStatusBar } from './assistant/AssistantStatusBar';
import {
  AssistantErrorDisplay,
  classifyStreamError,
  AssistantErrorCode,
  ClassifiedStreamError,
} from './assistant/AssistantErrorDisplay';

// Re-export classification types and helper for backward compatibility and test contracts
export { classifyStreamError, type AssistantErrorCode, type ClassifiedStreamError };

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
  const [inputPrompt, setInputPrompt] = useState('');
  const [attachments, setAttachments] = useState<string[]>([]);

  const { isOnline, modelStatus, loadModel, isModelLoading, registry } = useBackend();
  const abortControllerRef = useRef<AbortController | null>(null);
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
    : (currentModelName || 'Runtime Offline');

  const isModelSleeping = isOnline && modelStatus?.runtime_state === 'MODEL_SLEEPING';
  const isModelUnloaded = isOnline && (!modelStatus?.model_loaded || modelStatus?.runtime_state === 'MODEL_UNLOADED');
  const isRouterOffline = isOnline && !modelStatus?.router_running;

  const assistantState = propAssistantState !== undefined ? propAssistantState : internalAssistantState;
  const setAssistantState = (st: AssistantState) => {
    if (onSetAssistantState) {
      onSetAssistantState(st);
    } else {
      setInternalAssistantState(st);
    }
  };

  const isBusy = assistantState === 'thinking' || assistantState === 'speaking' || assistantState === 'executing_tool';

  // Initial messages start empty; live messages load from API or user prompts
  const [messages, setMessages] = useState<AssistantMessage[]>([]);

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
        setMessages([]);
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
      setMessages([]);
    } catch (err) {
      console.warn('Failed to create remote conversation:', err);
      setAssistantState('idle');
      // Preserve existing valid conversation state if one exists;
      // otherwise show an appropriate empty/offline state outside message history.
      const hasValidConversation = conversations.some((c) => c.id === activeConversationId);
      if (!hasValidConversation) {
        setActiveConversationId('');
        setConversationTitle('No Conversation (Offline)');
        setMessages([]);
      }
    }
  };

  const handleSelectConversation = (id: string) => {
    setActiveConversationId(id);
    const found = conversations.find((c) => c.id === id);
    if (found) {
      setConversationTitle(found.title);
    }
    loadConversationMessages(id);
  };

  const drawerConversations: ConversationHistoryItem[] = conversations.map((c) => ({
    id: c.id,
    title: c.title,
    date: new Date(c.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' }),
    snippet: 'Local conversation session stored in SQLite.',
    model: effectiveModelName,
    messagesCount: c.id === activeConversationId ? messages.length : 1,
  }));

  return (
    <div className="space-y-6">
      {/* 1. HEADER & STATUS BAR */}
      <AssistantStatusBar
        conversationTitle={conversationTitle}
        drawerConversationsCount={drawerConversations.length}
        onOpenHistory={() => setHistoryOpen(true)}
        activeCharacterName={activeCharacterName}
        currentModelName={currentModelName}
        isOnline={isOnline}
        modelStatus={modelStatus}
        registry={registry}
        onNewConversation={handleNewConversation}
        assistantState={assistantState}
      />

      {/* 2. CONVERSATION MESSAGE LIST */}
      <AssistantMessageList
        messages={messages}
        userName={userName}
        activeCharacterName={activeCharacterName}
        isBusy={isBusy}
        assistantState={assistantState}
      />

      {/* 3. DOCKED COMPOSER & STATUS/ERROR NOTICES */}
      <div className="sticky bottom-4 z-20 max-w-4xl mx-auto space-y-2">
        <AssistantErrorDisplay
          isOnline={isOnline}
          isModelSleeping={isModelSleeping}
          isModelUnloaded={isModelUnloaded}
          isRouterOffline={isRouterOffline}
          isModelLoading={isModelLoading}
          onLoadModel={() => loadModel()}
        />

        <AssistantComposer
          inputPrompt={inputPrompt}
          onInputChange={setInputPrompt}
          onSendMessage={handleSendMessage}
          onStopGeneration={handleStopGeneration}
          isBusy={isBusy}
          assistantState={assistantState}
          onSetAssistantState={setAssistantState}
          activeCharacterName={activeCharacterName}
          appliedContextSize={modelStatus?.applied_context_size}
          attachments={attachments}
          onRemoveAttachment={(idx) => setAttachments((prev) => prev.filter((_, i) => i !== idx))}
        />
      </div>

      {/* 4. CONVERSATION HISTORY DRAWER */}
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
