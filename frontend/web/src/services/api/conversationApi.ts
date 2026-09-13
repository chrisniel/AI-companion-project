/**
 * Conversation & Message API client for persistent chats.
 */

import { apiFetch, getApiBaseUrl, getApiKey, ApiError } from './client';

export interface ConversationOut {
  id: string;
  title: string;
  character_id: string;
  owner_id: string;
  created_at: string;
  updated_at: string;
}

export interface ConversationListOut {
  items: ConversationOut[];
  total: number;
}

export interface MessageOut {
  id: string;
  conversation_id: string;
  sender: 'user' | 'assistant' | 'system';
  content: string;
  status: string;
  sequence_no: number;
  client_message_id?: string | null;
  model_name?: string | null;
  prompt_tokens?: number | null;
  completion_tokens?: number | null;
  created_at: string;
}

export interface MessageListOut {
  items: MessageOut[];
  total: number;
}

export interface StreamMessageOptions {
  conversationId: string;
  userText: string;
  clientMessageId?: string;
  signal?: AbortSignal;
  onToken: (token: string) => void;
  onDone: () => void;
  onError: (error: Error) => void;
}

export async function createConversation(title?: string, characterId?: string): Promise<ConversationOut> {
  return apiFetch<ConversationOut>('/api/v1/conversations', {
    method: 'POST',
    body: JSON.stringify({ title: title || 'New Conversation', character_id: characterId || 'default' }),
  });
}

export async function listConversations(skip: number = 0, limit: number = 50): Promise<ConversationListOut> {
  return apiFetch<ConversationListOut>(`/api/v1/conversations?skip=${skip}&limit=${limit}`, {
    method: 'GET',
  });
}

export async function getConversation(conversationId: string): Promise<ConversationOut> {
  return apiFetch<ConversationOut>(`/api/v1/conversations/${conversationId}`, {
    method: 'GET',
  });
}

export async function renameConversation(conversationId: string, title: string): Promise<ConversationOut> {
  return apiFetch<ConversationOut>(`/api/v1/conversations/${conversationId}`, {
    method: 'PATCH',
    body: JSON.stringify({ title }),
  });
}

export async function deleteConversation(conversationId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/conversations/${conversationId}`, {
    method: 'DELETE',
  });
}

export async function getMessages(conversationId: string, skip: number = 0, limit: number = 100): Promise<MessageListOut> {
  return apiFetch<MessageListOut>(`/api/v1/conversations/${conversationId}/messages?skip=${skip}&limit=${limit}`, {
    method: 'GET',
  });
}

export async function streamSendMessage({
  conversationId,
  userText,
  clientMessageId,
  signal,
  onToken,
  onDone,
  onError,
}: StreamMessageOptions): Promise<void> {
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();
  const url = `${baseUrl}/api/v1/conversations/${conversationId}/messages`;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        user_text: userText,
        client_message_id: clientMessageId || null,
      }),
      signal,
    });

    if (!response.ok) {
      let errorMessage = `Message stream failed with status ${response.status}`;
      try {
        const errorJson = await response.json();
        if (errorJson.error?.message) {
          errorMessage = errorJson.error.message;
        } else if (errorJson.detail) {
          errorMessage = typeof errorJson.detail === 'string' ? errorJson.detail : JSON.stringify(errorJson.detail);
        }
      } catch {
        // Fallback to HTTP error
      }
      throw new ApiError({
        code: 'MESSAGE_STREAM_ERROR',
        message: errorMessage,
        status: response.status,
      });
    }

    if (!response.body) {
      throw new Error('ReadableStream not supported by browser response.');
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith(':')) continue;

        if (trimmed.startsWith('data:')) {
          const payload = trimmed.slice(5).trim();
          if (payload === '[DONE]') {
            onDone();
            return;
          }

          try {
            const parsed = JSON.parse(payload);
            const delta = parsed.choices?.[0]?.delta?.content;
            if (delta) {
              onToken(delta);
            }
          } catch {
            // Partial JSON chunk or heartbeat
          }
        }
      }
    }

    onDone();
  } catch (err: unknown) {
    if (signal?.aborted) {
      onDone();
      return;
    }
    const errorObj = err instanceof Error ? err : new Error(String(err));
    onError(errorObj);
  }
}
