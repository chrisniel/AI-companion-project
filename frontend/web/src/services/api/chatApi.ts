/**
 * Chat completions and Server-Sent Events (SSE) streaming API service.
 */

import { getApiBaseUrl, getApiKey, ApiError } from './client';

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface StreamChatOptions {
  messages: ChatMessage[];
  temperature?: number;
  maxTokens?: number;
  profile?: 'eco' | 'balanced' | 'maximum';
  signal?: AbortSignal;
  onToken: (token: string) => void;
  onDone: () => void;
  onError: (error: Error) => void;
}

export async function streamChatCompletion({
  messages,
  temperature = 0.7,
  maxTokens = 1024,
  profile,
  signal,
  onToken,
  onDone,
  onError,
}: StreamChatOptions): Promise<void> {
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();
  const url = `${baseUrl}/api/v1/chat/completions`;

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
        messages,
        stream: true,
        temperature,
        max_tokens: maxTokens,
        profile: profile || null,
      }),
      signal,
    });

    if (!response.ok) {
      let errorMessage = `Inference failed with status ${response.status}`;
      try {
        const errorJson = await response.json();
        if (errorJson.error?.message) {
          errorMessage = errorJson.error.message;
        } else if (errorJson.detail) {
          errorMessage = typeof errorJson.detail === 'string' ? errorJson.detail : JSON.stringify(errorJson.detail);
        }
      } catch {
        // Non-json error
      }
      throw new ApiError({
        code: 'INFERENCE_ERROR',
        message: errorMessage,
        status: response.status,
      });
    }

    if (!response.body) {
      throw new Error('ReadableStream not supported by browser response body.');
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
            if (parsed.error) {
              throw new Error(parsed.error.message || 'Stream error occurred.');
            }

            const delta = parsed.choices?.[0]?.delta?.content;
            if (delta) {
              onToken(delta);
            }
          } catch (err: unknown) {
            // Ignore parse errors on partial heartbeats
            if (payload !== '[DONE]' && err instanceof Error && err.message.includes('Stream error')) {
              onError(err);
              return;
            }
          }
        }
      }
    }

    onDone();
  } catch (err: unknown) {
    if (signal?.aborted) {
      // User requested cancellation, stop cleanly
      onDone();
      return;
    }
    const errorObj = err instanceof Error ? err : new Error(String(err));
    onError(errorObj);
  }
}
