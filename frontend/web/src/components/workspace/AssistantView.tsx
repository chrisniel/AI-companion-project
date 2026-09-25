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
  AttachmentOut,
  ALLOWED_MIME_TYPES,
  MAX_SIZE_BYTES,
  MAX_ATTACHMENTS_PER_MESSAGE,
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
  const conversationsRef = useRef<ConversationOut[]>([]);
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

  // 8B.6 Action & Navigation Disabled Truth (Item 7: shared authoritative render truth)
  const conversationActionsDisabled =
    sendPhase !== 'idle' ||
    isBusy ||
    isUploadingAttachments ||
    removingAttachmentIds.size > 0 ||
    isConversationTransitioning;

  // 8B.6 Send Disabled Truth (Item 12: disabled when no active conversation exists)
  const sendDisabled =
    !activeConversationId ||
    sendPhase !== 'idle' ||
    isBusy ||
    isUploadingAttachments ||
    removingAttachmentIds.size > 0 ||
    isConversationTransitioning ||
    (stagedAttachments.length > 0 && !hasVision) ||
    (!inputPrompt.trim() && stagedAttachments.length === 0);

  // 8B.6 Attachment Pick Truth (Item 4: canonical MAX_ATTACHMENTS_PER_MESSAGE)
  const canAttach =
    Boolean(activeConversationId) &&
    isOnline &&
    hasVision &&
    stagedAttachments.length < MAX_ATTACHMENTS_PER_MESSAGE &&
    sendPhase === 'idle' &&
    !isUploadingAttachments &&
    removingAttachmentIds.size === 0 &&
    !isConversationTransitioning;

  // 8B.6 Stop Truth (forbidden before acceptance)
  const canStop = sendPhase === 'accepted_streaming' && isBusy;

  // 8B.6 Composer Freeze Truth
  const isComposerFrozen = sendPhase !== 'idle' || isConversationTransitioning;

  // Keep conversationsRef in sync with state
  useEffect(() => {
    conversationsRef.current = conversations;
  }, [conversations]);

  // 8B.6 Fail-Closed Staged Attachment Cleanup
  const cleanupDefinitelyStagedAttachments = useCallback((convId: string): boolean => {
    if (sendPhaseRef.current !== 'idle') return false;
    if (uploadInProgressRef.current) return false;
    if (removingAttachmentIdsRef.current.size > 0) return false;

    const staged = stagedAttachmentsRef.current;
    stagedAttachmentsRef.current = [];
    setStagedAttachments([]);

    staged.forEach((item) => {
      try {
        URL.revokeObjectURL(item.previewUrl);
      } catch {}
      deleteAttachment(convId, item.attachment.id).catch(() => {});
    });

    return true;
  }, []);

  // 8B.6 Centralized Conversation Departure Transition (Item 8: fail-closed return boolean)
  const transitionActiveConversation = useCallback((
    nextId: string,
    options?: { cleanupOldStaged?: boolean },
  ): boolean => {
    const previousId = activeConversationIdRef.current;

    if (previousId && previousId !== nextId && (options?.cleanupOldStaged ?? true)) {
      const safeToLeave = cleanupDefinitelyStagedAttachments(previousId);
      if (!safeToLeave) {
        return false;
      }
    }

    attachmentLifecycleTokenRef.current++;
    activeConversationIdRef.current = nextId;
    setActiveConversationId(nextId);
    return true;
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

  // Mount/Unmount Tracking & Local/Remote Cleanup (Item 11)
  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      attachmentLifecycleTokenRef.current++;

      const stagedSnapshot = [...stagedAttachmentsRef.current];
      stagedAttachmentsRef.current = [];

      // ALWAYS: revoke every staged previewUrl locally to prevent browser memory leaks
      stagedSnapshot.forEach((item) => {
        try {
          URL.revokeObjectURL(item.previewUrl);
        } catch {}
      });

      // ONLY if definitely safe: remote DELETE staged rows
      const currentId = activeConversationIdRef.current;
      const isDefinitelySafe =
        sendPhaseRef.current === 'idle' &&
        !uploadInProgressRef.current &&
        removingAttachmentIdsRef.current.size === 0 &&
        !conversationTransitionRef.current;

      if (currentId && isDefinitelySafe && stagedSnapshot.length > 0) {
        stagedSnapshot.forEach((item) => {
          deleteAttachment(currentId, item.attachment.id).catch(() => {});
        });
      }
    };
  }, []);

  // Conversation Initialization & Reconnect Reconciliation (Item 9 & 10)
  useEffect(() => {
    let isMounted = true;
    async function initConversations() {
      if (!isOnline) return;

      try {
        const res = await listConversations();
        if (!isMounted) return;

        if (res.items && res.items.length > 0) {
          conversationsRef.current = res.items;
          setConversations(res.items);

          const currentId = activeConversationIdRef.current;
          const matching = currentId ? res.items.find((c) => c.id === currentId) : undefined;

          if (matching) {
            setConversationTitle(matching.title);
            if (!hasInitializedRef.current) {
              loadConversationMessages(matching.id);
            }
          } else {
            // Reconnect reconciliation: respect ALL mutation locks (Item 9)
            const isLocked =
              sendPhaseRef.current !== 'idle' ||
              uploadInProgressRef.current ||
              removingAttachmentIdsRef.current.size > 0 ||
              conversationTransitionRef.current;

            if (isLocked) {
              setAttachmentError(
                'Current conversation was not found on the backend while send outcome is pending or operations are active. Preserving local state. Reload application to reconcile.'
              );
            } else {
              const active = res.items[0];
              const success = transitionActiveConversation(active.id, { cleanupOldStaged: true });
              if (success) {
                setConversationTitle(active.title);
                loadConversationMessages(active.id);
              } else {
                setAttachmentError('Active conversation could not be safely switched during reconciliation.');
              }
            }
          }
          hasInitializedRef.current = true;
        } else if (!hasInitializedRef.current) {
          try {
            const created = await createConversation('New Conversation');
            if (!isMounted) return;
            conversationsRef.current = [created];
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
        // Last-known-state preservation: do NOT clear valid conversation if refresh failed (Item 10)
        const currentId = activeConversationIdRef.current;
        const hasValid = conversationsRef.current.some((c) => c.id === currentId);
        if (!currentId || !hasValid) {
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
  }, [isOnline, loadConversationMessages, transitionActiveConversation]);

  const formatStreamErrorMessage = (err: Error): string => {
    const isBusyErr = err.message?.includes('409') || err.message?.includes('BUSY');
    if (isBusyErr) {
      return '[Notice]: Model or conversation is currently busy. Please wait for previous generation to finish.';
    }

    return classifyStreamError(err, isOnline, modelStatus).visibleMessage;
  };

  // 8B.6 Sequential File Selection & Upload Batch (Items 4, 5, 16)
  const handleFilesSelected = async (files: FileList | File[]) => {
    if (uploadInProgressRef.current) return;
    if (sendPhaseRef.current !== 'idle') return;
    if (removingAttachmentIdsRef.current.size > 0) return;
    if (conversationTransitionRef.current) return;
    if (!activeConversationIdRef.current || !hasVision) return;

    const capturedConvId = activeConversationIdRef.current;
    const capturedToken = attachmentLifecycleTokenRef.current;

    const currentCount = stagedAttachmentsRef.current.length;
    const availableSlots = MAX_ATTACHMENTS_PER_MESSAGE - currentCount;
    if (availableSlots <= 0) {
      setAttachmentError(`Maximum of ${MAX_ATTACHMENTS_PER_MESSAGE} attachments allowed per message.`);
      return;
    }

    const candidateFiles = Array.from(files);
    const validFiles: File[] = [];
    const validationErrors: string[] = [];

    for (const file of candidateFiles) {
      if (!ALLOWED_MIME_TYPES.includes(file.type as any)) {
        validationErrors.push(`"${file.name}": Only PNG and JPEG images are supported.`);
        continue;
      }
      if (file.size <= 0) {
        validationErrors.push(`"${file.name}": Zero-byte files cannot be attached.`);
        continue;
      }
      if (file.size > MAX_SIZE_BYTES) {
        validationErrors.push(`"${file.name}": Exceeds the ${MAX_SIZE_BYTES / (1024 * 1024)} MiB limit.`);
        continue;
      }
      validFiles.push(file);
    }

    let filesToUpload = validFiles;
    let quotaWarning = '';
    if (validFiles.length > availableSlots) {
      filesToUpload = validFiles.slice(0, availableSlots);
      quotaWarning = `Only ${availableSlots} more attachment${availableSlots === 1 ? '' : 's'} can be added (max ${MAX_ATTACHMENTS_PER_MESSAGE} per message).`;
    }

    const initialWarning = [
      validationErrors.length > 0 ? validationErrors[0] : null,
      quotaWarning || null,
    ].filter(Boolean).join(' • ');

    if (initialWarning) {
      setAttachmentError(initialWarning);
    } else {
      setAttachmentError(null);
    }

    if (filesToUpload.length === 0) return;

    uploadInProgressRef.current = true;
    setIsUploadingAttachments(true);

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

        let uploaded: AttachmentOut;
        try {
          uploaded = await uploadAttachment(capturedConvId, file);
        } catch (uploadErr: any) {
          if (mountedRef.current) {
            setAttachmentError(uploadErr.message || 'Failed to upload attachment.');
          }
          break;
        }

        if (
          !mountedRef.current ||
          attachmentLifecycleTokenRef.current !== capturedToken ||
          activeConversationIdRef.current !== capturedConvId ||
          sendPhaseRef.current !== 'idle'
        ) {
          deleteAttachment(capturedConvId, uploaded.id).catch((delErr) => {
            console.warn('Failed to delete orphaned attachment after departure:', delErr);
          });
          break;
        }

        // Preview fetching with rollback on failure (Item 5)
        let previewUrl: string;
        try {
          previewUrl = await fetchAttachmentBlobUrl(capturedConvId, uploaded.id);
        } catch (previewErr: any) {
          try {
            await deleteAttachment(capturedConvId, uploaded.id);
          } catch (delErr) {
            console.warn('Failed to rollback uploaded attachment after preview failure:', delErr);
          }
          if (mountedRef.current) {
            setAttachmentError(previewErr.message || 'Failed to generate preview for uploaded attachment.');
          }
          break;
        }

        if (
          !mountedRef.current ||
          attachmentLifecycleTokenRef.current !== capturedToken ||
          activeConversationIdRef.current !== capturedConvId ||
          sendPhaseRef.current !== 'idle'
        ) {
          try {
            URL.revokeObjectURL(previewUrl);
          } catch {}
          deleteAttachment(capturedConvId, uploaded.id).catch((delErr) => {
            console.warn('Failed to delete orphaned attachment after departure:', delErr);
          });
          break;
        }

        const newItem: StagedAttachmentItem = { attachment: uploaded, previewUrl };
        stagedAttachmentsRef.current = [...stagedAttachmentsRef.current, newItem];
        setStagedAttachments((prev) => [...prev, newItem]);
      }
    } finally {
      uploadInProgressRef.current = false;
      if (mountedRef.current) {
        setIsUploadingAttachments(false);
      }
    }
  };

  // 8B.6 Synchronous Removal Serialization (Item 6: do NOT remove in finally if DELETE fails)
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

      // DELETE succeeded: revoke URL and remove staged card
      try {
        URL.revokeObjectURL(target.previewUrl);
      } catch {}

      stagedAttachmentsRef.current = stagedAttachmentsRef.current.filter(
        (s) => s.attachment.id !== attachmentId
      );
      setStagedAttachments((prev) => prev.filter((s) => s.attachment.id !== attachmentId));
    } catch (err: any) {
      console.warn('Failed to delete attachment on backend:', err);
      // DELETE failed: keep staged card, keep preview URL, show attachment error
      if (mountedRef.current) {
        setAttachmentError(err.message || 'Failed to remove attachment.');
      }
    } finally {
      // Release lock ONLY in finally
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

    // Item 12: Guard sending without a real conversation
    const convId = activeConversationIdRef.current;
    if (!convId) {
      setAttachmentError('Select or create a conversation before sending.');
      return;
    }

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

      const success = transitionActiveConversation(created.id, { cleanupOldStaged: true });
      if (!success) {
        setAttachmentError('Cannot switch conversations while attachment operations are in progress.');
        return;
      }
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
      const hasValidConversation = conversationsRef.current.some((c) => c.id === currentId);
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

  // 8B.6 Synchronous Conversation Selection (Item 7: guard all refs)
  const handleSelectConversation = (id: string) => {
    if (sendPhaseRef.current !== 'idle') return;
    if (uploadInProgressRef.current) return;
    if (removingAttachmentIdsRef.current.size > 0) return;
    if (conversationTransitionRef.current) return;

    const success = transitionActiveConversation(id, { cleanupOldStaged: true });
    if (!success) {
      setAttachmentError('Cannot switch conversations while attachment operations are in progress.');
      return;
    }

    const found = conversationsRef.current.find((c) => c.id === id);
    if (found) {
      setConversationTitle(found.title);
    }
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
        isConversationSwitchingDisabled={conversationActionsDisabled}
      />
    </div>
  );
};
