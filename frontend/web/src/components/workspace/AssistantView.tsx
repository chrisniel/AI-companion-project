import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useBackend } from '../../context/BackendContext';
import {
  listConversations,
  createConversation,
  getMessages,
  streamSendMessage,
  uploadAttachment,
  fetchAttachmentBlobUrl,
  deleteAttachment,
  registryEntryMatchesIdentifier,
  ConversationOut,
  ApiError,
} from '../../services/api';
import {
  AssistantMessage,
  AssistantState,
  ConversationHistoryItem,
  MessageType,
} from '../../types';
import { ConversationHistoryDrawer } from './ConversationHistoryDrawer';
import {
  AssistantComposer,
  StagedAttachmentItem,
} from './assistant/AssistantComposer';
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

export type SendPhase =
  | 'idle'
  | 'awaiting_acceptance'
  | 'accepted_streaming'
  | 'outcome_unknown';

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
  const [activeConversationId, setActiveConversationId] = useState('');
  const [conversationTitle, setConversationTitle] = useState('No Conversation');
  const [inputPrompt, setInputPrompt] = useState('');

  // 8B.6 Staged Attachments
  const [stagedAttachments, setStagedAttachments] = useState<StagedAttachmentItem[]>([]);
  const stagedAttachmentsRef = useRef<StagedAttachmentItem[]>([]);

  // 8B.6 Send Phase
  const [sendPhase, setSendPhase] = useState<SendPhase>('idle');
  const sendPhaseRef = useRef<SendPhase>('idle');
  const transitionSendPhase = (next: SendPhase) => {
    sendPhaseRef.current = next;
    setSendPhase(next);
  };

  // 8B.6 Upload Lock
  const [isUploadingAttachments, setIsUploadingAttachments] = useState(false);
  const uploadInProgressRef = useRef(false);

  // 8B.6 Per-ID Removal Lock
  const [removingAttachmentIds, setRemovingAttachmentIds] = useState<Set<string>>(new Set());
  const removingAttachmentIdsRef = useRef<Set<string>>(new Set());

  // 8B.6 Conversation Transition Lock
  const [isConversationTransitioning, setIsConversationTransitioning] = useState(false);
  const conversationTransitionRef = useRef(false);

  // 8B.6 Error Display & Tokens
  const [attachmentError, setAttachmentError] = useState<string | null>(null);
  const attachmentLifecycleTokenRef = useRef(0);
  const mountedRef = useRef(true);

  const { isOnline, modelStatus, loadModel, isModelLoading, registry } = useBackend();
  const abortControllerRef = useRef<AbortController | null>(null);
  const hasInitializedRef = useRef(false);
  const activeConversationIdRef = useRef(activeConversationId);
  const messageLoadTokenRef = useRef(0);

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

  // 8B.6 Active Model & Vision Capability Truth
  const activeModelId = modelStatus?.active_model || null;
  const activeModelEntry = activeModelId
    ? registry.find((m) => registryEntryMatchesIdentifier(m, activeModelId))
    : null;

  const hasVision = Boolean(
    isOnline &&
    modelStatus?.model_loaded &&
    activeModelEntry?.library_state?.available_capabilities?.includes('vision')
  );

  // 8B.6 Action & Navigation Disabled Truth
  const conversationActionsDisabled =
    sendPhase !== 'idle' ||
    isBusy ||
    isUploadingAttachments ||
    removingAttachmentIds.size > 0 ||
    isConversationTransitioning;

  const isConversationSwitchingDisabled =
    sendPhase !== 'idle' ||
    isBusy ||
    removingAttachmentIds.size > 0;

  // 8B.6 Send Disabled Truth
  const sendDisabled =
    sendPhase !== 'idle' ||
    isBusy ||
    isUploadingAttachments ||
    removingAttachmentIds.size > 0 ||
    isConversationTransitioning ||
    (stagedAttachments.length > 0 && !hasVision) ||
    (!inputPrompt.trim() && stagedAttachments.length === 0);

  // 8B.6 Attachment Pick Truth
  const canAttach =
    Boolean(activeConversationId) &&
    isOnline &&
    hasVision &&
    stagedAttachments.length < 4 &&
    sendPhase === 'idle' &&
    !isUploadingAttachments &&
    removingAttachmentIds.size === 0 &&
    !isConversationTransitioning;

  // 8B.6 Stop Truth (forbidden before acceptance)
  const canStop = sendPhase === 'accepted_streaming' && isBusy;

  // 8B.6 Composer Freeze Truth
  const isComposerFrozen = sendPhase !== 'idle' || isConversationTransitioning;

  // 8B.6 Fail-Closed Staged Attachment Cleanup
  const cleanupDefinitelyStagedAttachments = useCallback((convId: string): boolean => {
    if (sendPhaseRef.current !== 'idle') return false;
    if (uploadInProgressRef.current) return false;
    if (removingAttachmentIdsRef.current.size > 0) return false;

    const staged = stagedAttachmentsRef.current;
    stagedAttachmentsRef.current = [];
    setStagedAttachments([]);

    staged.forEach((item) => {
      URL.revokeObjectURL(item.previewUrl);
      deleteAttachment(convId, item.attachment.id).catch(() => {});
    });

    return true;
  }, []);

  // 8B.6 Centralized Conversation Departure Transition
  const transitionActiveConversation = useCallback((
    nextId: string,
    options?: { cleanupOldStaged?: boolean },
  ) => {
    const previousId = activeConversationIdRef.current;

    if (previousId && previousId !== nextId) {
      if (options?.cleanupOldStaged ?? true) {
        cleanupDefinitelyStagedAttachments(previousId);
      }
      attachmentLifecycleTokenRef.current++;
    }

    activeConversationIdRef.current = nextId;
    setActiveConversationId(nextId);
  }, [cleanupDefinitelyStagedAttachments]);

  // Load conversation messages
  const loadConversationMessages = useCallback(async (convId: string) => {
    const currentToken = ++messageLoadTokenRef.current;
    setMessages([]);

    try {
      const res = await getMessages(convId);
      if (messageLoadTokenRef.current !== currentToken) {
        return;
      }

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
      if (messageLoadTokenRef.current === currentToken) {
        setMessages([]);
      }
    }
  }, [activeCharacterName, userName]);

  // Mount/Unmount Tracking & Cleanup
  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      const currentId = activeConversationIdRef.current;
      if (currentId) {
        cleanupDefinitelyStagedAttachments(currentId);
      }
    };
  }, [cleanupDefinitelyStagedAttachments]);

  // Conversation Initialization & Reconnect Reconciliation
  useEffect(() => {
    let isMounted = true;
    async function initConversations() {
      if (!isOnline) return;

      try {
        const res = await listConversations();
        if (!isMounted) return;

        if (res.items && res.items.length > 0) {
          setConversations(res.items);

          const currentId = activeConversationIdRef.current;
          const matching = currentId ? res.items.find((c) => c.id === currentId) : undefined;

          if (matching) {
            setConversationTitle(matching.title);
            if (!hasInitializedRef.current) {
              loadConversationMessages(matching.id);
            }
          } else {
            if (sendPhaseRef.current !== 'idle') {
              setAttachmentError(
                'Current conversation was not found on the backend while send outcome is pending or uncertain. Reload the application to reconcile.'
              );
            } else {
              const active = res.items[0];
              transitionActiveConversation(active.id, { cleanupOldStaged: true });
              setConversationTitle(active.title);
              loadConversationMessages(active.id);
            }
          }
          hasInitializedRef.current = true;
        } else if (!hasInitializedRef.current) {
          try {
            const created = await createConversation('New Conversation');
            if (!isMounted) return;
            setConversations([created]);
            activeConversationIdRef.current = created.id;
            setActiveConversationId(created.id);
            setConversationTitle(created.title);
            loadConversationMessages(created.id);
            hasInitializedRef.current = true;
          } catch (createErr) {
            console.warn('Unable to create initial conversation on backend:', createErr);
            if (!isMounted) return;
            activeConversationIdRef.current = '';
            setActiveConversationId('');
            setConversationTitle('No Conversation');
            setMessages([]);
            hasInitializedRef.current = true;
          }
        }
      } catch (err) {
        console.warn('Unable to initialize conversations from backend:', err);
        if (!isMounted) return;
        const currentId = activeConversationIdRef.current;
        const hasValid = conversations.some((c) => c.id === currentId);
        if (!hasValid) {
          activeConversationIdRef.current = '';
          setActiveConversationId('');
          setConversationTitle('No Conversation');
          setMessages([]);
        }
      }
    }

    initConversations();
    return () => {
      isMounted = false;
    };
  }, [isOnline, loadConversationMessages, transitionActiveConversation, conversations]);

  const formatStreamErrorMessage = (err: Error): string => {
    const isBusyErr = err.message?.includes('409') || err.message?.includes('BUSY');
    if (isBusyErr) {
      return '[Notice]: Model or conversation is currently busy. Please wait for previous generation to finish.';
    }

    return classifyStreamError(err, isOnline, modelStatus).visibleMessage;
  };

  // 8B.6 Sequential File Selection & Upload Batch
  const handleFilesSelected = async (files: FileList | File[]) => {
    if (uploadInProgressRef.current) return;
    if (sendPhaseRef.current !== 'idle') return;
    if (removingAttachmentIdsRef.current.size > 0) return;
    if (conversationTransitionRef.current) return;
    if (!activeConversationIdRef.current || !hasVision) return;

    const capturedConvId = activeConversationIdRef.current;
    const capturedToken = attachmentLifecycleTokenRef.current;

    const currentCount = stagedAttachmentsRef.current.length;
    const availableSlots = 4 - currentCount;
    if (availableSlots <= 0) {
      setAttachmentError('Maximum of 4 attachments allowed per message.');
      return;
    }

    const candidateFiles = Array.from(files);
    const validFiles: File[] = [];

    for (const file of candidateFiles) {
      if (file.type !== 'image/png' && file.type !== 'image/jpeg') {
        setAttachmentError('Only PNG and JPEG images are supported.');
        continue;
      }
      if (file.size <= 0) {
        setAttachmentError('Zero-byte files cannot be attached.');
        continue;
      }
      if (file.size > 10 * 1024 * 1024) {
        setAttachmentError(`File "${file.name}" exceeds the 10 MiB limit.`);
        continue;
      }
      validFiles.push(file);
    }

    const filesToUpload = validFiles.slice(0, availableSlots);
    if (filesToUpload.length === 0) return;

    uploadInProgressRef.current = true;
    setIsUploadingAttachments(true);
    setAttachmentError(null);

    try {
      for (const file of filesToUpload) {
        if (
          !mountedRef.current ||
          attachmentLifecycleTokenRef.current !== capturedToken ||
          activeConversationIdRef.current !== capturedConvId ||
          sendPhaseRef.current !== 'idle'
        ) {
          break;
        }

        const uploaded = await uploadAttachment(capturedConvId, file);

        if (
          !mountedRef.current ||
          attachmentLifecycleTokenRef.current !== capturedToken ||
          activeConversationIdRef.current !== capturedConvId ||
          sendPhaseRef.current !== 'idle'
        ) {
          deleteAttachment(capturedConvId, uploaded.id).catch(() => {});
          break;
        }

        const previewUrl = await fetchAttachmentBlobUrl(capturedConvId, uploaded.id);

        if (
          !mountedRef.current ||
          attachmentLifecycleTokenRef.current !== capturedToken ||
          activeConversationIdRef.current !== capturedConvId ||
          sendPhaseRef.current !== 'idle'
        ) {
          URL.revokeObjectURL(previewUrl);
          deleteAttachment(capturedConvId, uploaded.id).catch(() => {});
          break;
        }

        const newItem: StagedAttachmentItem = { attachment: uploaded, previewUrl };
        stagedAttachmentsRef.current = [...stagedAttachmentsRef.current, newItem];
        setStagedAttachments((prev) => [...prev, newItem]);
      }
    } catch (err: any) {
      if (mountedRef.current) {
        setAttachmentError(err.message || 'Failed to upload attachment.');
      }
    } finally {
      uploadInProgressRef.current = false;
      if (mountedRef.current) {
        setIsUploadingAttachments(false);
      }
    }
  };

  // 8B.6 Synchronous Removal Serialization
  const handleRemoveAttachment = async (attachmentId: string) => {
    if (removingAttachmentIdsRef.current.has(attachmentId)) return;
    if (sendPhaseRef.current !== 'idle') return;
    if (uploadInProgressRef.current) return;
    if (conversationTransitionRef.current) return;

    const convId = activeConversationIdRef.current;
    if (!convId) return;

    const target = stagedAttachmentsRef.current.find((s) => s.attachment.id === attachmentId);
    if (!target) return;

    removingAttachmentIdsRef.current.add(attachmentId);
    setRemovingAttachmentIds(new Set(removingAttachmentIdsRef.current));

    try {
      await deleteAttachment(convId, attachmentId);
    } catch (err) {
      console.warn('Failed to delete attachment on backend:', err);
    } finally {
      URL.revokeObjectURL(target.previewUrl);

      stagedAttachmentsRef.current = stagedAttachmentsRef.current.filter(
        (s) => s.attachment.id !== attachmentId
      );
      setStagedAttachments((prev) => prev.filter((s) => s.attachment.id !== attachmentId));

      removingAttachmentIdsRef.current.delete(attachmentId);
      if (mountedRef.current) {
        setRemovingAttachmentIds(new Set(removingAttachmentIdsRef.current));
      }
    }
  };

  // 8B.6 Handle Send Message with Staged Attachments & Lifecycle Phase Machine
  const handleSendMessage = async () => {
    if (sendPhaseRef.current !== 'idle') return;
    if (uploadInProgressRef.current) return;
    if (removingAttachmentIdsRef.current.size > 0) return;
    if (conversationTransitionRef.current) return;
    if (isBusy) return;

    const stagedSnapshot = [...stagedAttachmentsRef.current];
    if (stagedSnapshot.length > 0 && !hasVision) {
      setAttachmentError('Active model does not support image input.');
      return;
    }

    const promptText = inputPrompt.trim();
    if (!promptText && stagedSnapshot.length === 0) return;

    const convId = activeConversationIdRef.current || 'default';

    const userText = promptText || 'Shared attachment for processing.';
    const attachmentIds = stagedSnapshot.map((s) => s.attachment.id);

    // Synchronously lock send phase BEFORE awaiting fetch
    transitionSendPhase('awaiting_acceptance');
    setAttachmentError(null);

    const clientMessageId =
      typeof crypto !== 'undefined' && crypto.randomUUID
        ? crypto.randomUUID()
        : `cl-${Date.now()}`;
    const assistantMsgId = `ast-${Date.now() + 1}`;

    let hasBeenAccepted = false;
    abortControllerRef.current = new AbortController();

    await streamSendMessage({
      conversationId: convId,
      userText,
      clientMessageId,
      attachmentIds,
      signal: abortControllerRef.current.signal,

      onAccepted: () => {
        if (!mountedRef.current) return;
        hasBeenAccepted = true;

        // 1. Transition phase and assistant state
        transitionSendPhase('accepted_streaming');
        setAssistantState('thinking');

        // 2. Commit bubbles to UI
        const userMsg: AssistantMessage = {
          id: clientMessageId,
          type: 'user',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: userText,
        };
        const initialAssistantMsg: AssistantMessage = {
          id: assistantMsgId,
          type: 'assistant',
          sender: activeCharacterName,
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          content: '',
        };
        setMessages((prev) => [...prev, userMsg, initialAssistantMsg]);

        // 3. Clear draft and staged cards (attachments now claimed by message)
        setInputPrompt('');
        stagedSnapshot.forEach((s) => URL.revokeObjectURL(s.previewUrl));
        stagedAttachmentsRef.current = [];
        setStagedAttachments([]);
      },

      onToken: (token: string) => {
        if (!mountedRef.current) return;
        setAssistantState('speaking');
        setMessages((prev) => {
          const last = prev[prev.length - 1];
          if (last && last.id === assistantMsgId) {
            return [...prev.slice(0, -1), { ...last, content: last.content + token }];
          }
          return prev;
        });
      },

      onDone: (fullText?: string) => {
        if (!mountedRef.current) return;
        transitionSendPhase('idle');
        setAssistantState('idle');
        abortControllerRef.current = null;
        if (fullText) {
          setMessages((prev) => {
            const last = prev[prev.length - 1];
            if (last && last.id === assistantMsgId && !last.content) {
              return [...prev.slice(0, -1), { ...last, content: fullText }];
            }
            return prev;
          });
        }
      },

      onError: (err: Error, partialText?: string) => {
        if (!mountedRef.current) return;
        abortControllerRef.current = null;

        if (!hasBeenAccepted) {
          // PRE-ACCEPTANCE FAILURE
          if (err instanceof ApiError) {
            // Explicit HTTP rejection: preparation did not commit
            transitionSendPhase('idle');
            setAssistantState('idle');
            setAttachmentError(err.message || 'Failed to send message.');
            // Draft and stagedAttachmentsRef remain intact
          } else {
            // Transport error before HTTP response: outcome is uncertain
            transitionSendPhase('outcome_unknown');
            setAssistantState('idle');
            const streamErr = formatStreamErrorMessage(err);
            const msg =
              stagedSnapshot.length > 0
                ? 'Connection lost before server confirmed message acceptance. Attachment binding status is unknown. Please reload the application or session before making changes.'
                : streamErr;
            setAttachmentError(msg);
            // Draft and cards preserved; destructive actions remain permanently blocked
          }
          return;
        }

        // POST-ACCEPTANCE SSE FAILURE
        transitionSendPhase('idle');
        setAssistantState('idle');
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
  };

  const handleStopGeneration = () => {
    if (sendPhaseRef.current !== 'accepted_streaming') return;

    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
      abortControllerRef.current = null;
    }
    transitionSendPhase('idle');
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

  // 8B.6 Async New Conversation with Synchronous Transition Lock
  const handleNewConversation = async () => {
    if (conversationTransitionRef.current) return;
    if (sendPhaseRef.current !== 'idle') return;
    if (uploadInProgressRef.current) return;
    if (removingAttachmentIdsRef.current.size > 0) return;

    conversationTransitionRef.current = true;
    setIsConversationTransitioning(true);

    const requestToken = ++messageLoadTokenRef.current;
    try {
      const created = await createConversation('New Conversation');

      if (
        !mountedRef.current ||
        !conversationTransitionRef.current ||
        sendPhaseRef.current !== 'idle' ||
        uploadInProgressRef.current ||
        removingAttachmentIdsRef.current.size > 0
      ) {
        return;
      }

      setConversations((prev) => [created, ...prev]);

      if (messageLoadTokenRef.current !== requestToken) {
        return;
      }

      transitionActiveConversation(created.id, { cleanupOldStaged: true });
      setConversationTitle(created.title);
      setAssistantState('idle');
      setMessages([]);
    } catch (err) {
      console.warn('Failed to create remote conversation:', err);
      setAssistantState('idle');
      setAttachmentError('Failed to create new conversation.');

      if (messageLoadTokenRef.current !== requestToken) {
        return;
      }

      const currentId = activeConversationIdRef.current;
      const hasValidConversation = conversations.some((c) => c.id === currentId);
      if (!hasValidConversation) {
        activeConversationIdRef.current = '';
        setActiveConversationId('');
        setConversationTitle('No Conversation');
        setMessages([]);
      }
    } finally {
      conversationTransitionRef.current = false;
      if (mountedRef.current) {
        setIsConversationTransitioning(false);
      }
    }
  };

  // 8B.6 Synchronous Conversation Selection
  const handleSelectConversation = (id: string) => {
    if (sendPhaseRef.current !== 'idle') return;
    if (removingAttachmentIdsRef.current.size > 0) return;

    const found = conversations.find((c) => c.id === id);
    if (found) {
      setConversationTitle(found.title);
    }

    transitionActiveConversation(id, { cleanupOldStaged: true });
    loadConversationMessages(id);
  };

  const drawerConversations: ConversationHistoryItem[] = conversations.map((c) => ({
    id: c.id,
    title: c.title,
    date: new Date(c.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' }),
    messagesCount: c.id === activeConversationId ? messages.length : undefined,
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
        isNewConversationDisabled={conversationActionsDisabled}
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
          error={attachmentError}
          onDismissError={() => setAttachmentError(null)}
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
          stagedAttachments={stagedAttachments}
          onRemoveAttachment={handleRemoveAttachment}
          onFilesSelected={handleFilesSelected}
          canAttach={canAttach}
          isUploadingAttachments={isUploadingAttachments}
          removingAttachmentIds={removingAttachmentIds}
          sendDisabled={sendDisabled}
          canStop={canStop}
          isComposerFrozen={isComposerFrozen}
          hasVision={hasVision}
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
        conversationActionsDisabled={conversationActionsDisabled}
        isConversationSwitchingDisabled={isConversationSwitchingDisabled}
      />
    </div>
  );
};
