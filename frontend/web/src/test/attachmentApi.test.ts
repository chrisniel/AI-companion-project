import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  uploadAttachment,
  fetchAttachmentBlobUrl,
  deleteAttachment,
  AttachmentOut,
} from '../services/api/attachmentApi';
import {
  registryEntryMatchesIdentifier,
  RegistryEntry,
} from '../services/api/registryApi';
import { streamSendMessage } from '../services/api/conversationApi';
import { ApiError } from '../services/api/client';

describe('Phase 8B.6 Attachment API & Registry Tests', () => {
  const originalFetch = globalThis.fetch;
  const originalCreateObjectURL = URL.createObjectURL;
  const originalRevokeObjectURL = URL.revokeObjectURL;

  beforeEach(() => {
    localStorage.clear();
    localStorage.setItem('companion_api_url', 'http://127.0.0.1:8000');
    localStorage.setItem('companion_api_key', 'test-pairing-key');
    URL.createObjectURL = vi.fn().mockReturnValue('blob:http://localhost/test-blob-uuid');
    URL.revokeObjectURL = vi.fn();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    URL.createObjectURL = originalCreateObjectURL;
    URL.revokeObjectURL = originalRevokeObjectURL;
    vi.restoreAllMocks();
  });

  describe('uploadAttachment', () => {
    it('sends multipart/form-data with Authorization header and does not set manual Content-Type', async () => {
      let capturedUrl = '';
      let capturedInit: RequestInit | undefined;

      globalThis.fetch = vi.fn().mockImplementation(async (url, init) => {
        capturedUrl = String(url);
        capturedInit = init;
        return {
          ok: true,
          status: 201,
          json: async () => ({
            id: 'att-123',
            conversation_id: 'conv-1',
            message_id: null,
            file_name: 'test.png',
            content_type: 'image/png',
            byte_size: 1024,
            sha256: 'abc123hash',
            created_at: '2026-09-25T00:00:00Z',
          }),
        };
      });

      const file = new File(['dummy binary content'], 'test.png', { type: 'image/png' });
      const result = await uploadAttachment('conv-1', file);

      expect(capturedUrl).toBe('http://127.0.0.1:8000/api/v1/conversations/conv-1/attachments');
      expect(capturedInit?.method).toBe('POST');
      const headers = capturedInit?.headers as Record<string, string>;
      expect(headers['Authorization']).toBe('Bearer test-pairing-key');
      // Crucial: Content-Type must NOT be manually set so browser can generate boundary
      expect(headers['Content-Type']).toBeUndefined();
      expect(capturedInit?.body).toBeInstanceOf(FormData);
      expect(result.id).toBe('att-123');
      expect(result.file_name).toBe('test.png');
    });

    it('throws ApiError with status and server error message on failure', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({
          detail: 'File exceeds 10 MiB limit.',
        }),
      });

      const file = new File(['large content'], 'huge.png', { type: 'image/png' });
      await expect(uploadAttachment('conv-1', file)).rejects.toThrow('File exceeds 10 MiB limit.');
    });
  });

  describe('fetchAttachmentBlobUrl', () => {
    it('fetches binary data with Authorization header and returns createObjectURL', async () => {
      let capturedUrl = '';
      let capturedHeaders: Record<string, string> = {};

      const mockBlob = new Blob(['image-bytes'], { type: 'image/png' });
      globalThis.fetch = vi.fn().mockImplementation(async (url, init) => {
        capturedUrl = String(url);
        capturedHeaders = (init?.headers as Record<string, string>) || {};
        return {
          ok: true,
          status: 200,
          blob: async () => mockBlob,
        };
      });

      const blobUrl = await fetchAttachmentBlobUrl('conv-1', 'att-123');

      expect(capturedUrl).toBe('http://127.0.0.1:8000/api/v1/conversations/conv-1/attachments/att-123');
      expect(capturedHeaders['Authorization']).toBe('Bearer test-pairing-key');
      expect(URL.createObjectURL).toHaveBeenCalledWith(mockBlob);
      expect(blobUrl).toBe('blob:http://localhost/test-blob-uuid');
    });

    it('throws ApiError on HTTP non-2xx', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
      });

      await expect(fetchAttachmentBlobUrl('conv-1', 'att-missing')).rejects.toThrow('Failed to fetch attachment binary (404)');
    });
  });

  describe('deleteAttachment', () => {
    it('sends DELETE request with Authorization header and resolves on 200/204', async () => {
      let capturedMethod = '';
      let capturedUrl = '';

      globalThis.fetch = vi.fn().mockImplementation(async (url, init) => {
        capturedUrl = String(url);
        capturedMethod = init?.method || '';
        return {
          ok: true,
          status: 204,
        };
      });

      await deleteAttachment('conv-1', 'att-123');

      expect(capturedUrl).toBe('http://127.0.0.1:8000/api/v1/conversations/conv-1/attachments/att-123');
      expect(capturedMethod).toBe('DELETE');
    });

    it('treats 404 as idempotent success without throwing', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
      });

      await expect(deleteAttachment('conv-1', 'att-already-gone')).resolves.toBeUndefined();
    });

    it('throws ApiError on non-404 failure', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
      });

      await expect(deleteAttachment('conv-1', 'att-err')).rejects.toThrow('Failed to delete attachment (500)');
    });
  });

  describe('registryEntryMatchesIdentifier with stem parity', () => {
    const entry: RegistryEntry = {
      manifest: {
        id: 'qwen2-vl-7b',
        display_name: 'Qwen2-VL 7B Instruct',
        primary_file: 'models/Qwen2-VL-7B-Instruct-Q4_K_M.gguf',
      },
      library_state: {
        available_capabilities: ['chat', 'vision'],
      },
      hints: {},
      runtime_model_id: 'qwen2-vl-runtime-id',
      registry_source: 'installed',
    };

    it('matches exact manifest id', () => {
      expect(registryEntryMatchesIdentifier(entry, 'qwen2-vl-7b')).toBe(true);
    });

    it('matches runtime_model_id', () => {
      expect(registryEntryMatchesIdentifier(entry, 'qwen2-vl-runtime-id')).toBe(true);
    });

    it('matches primary_file full path', () => {
      expect(registryEntryMatchesIdentifier(entry, 'models/Qwen2-VL-7B-Instruct-Q4_K_M.gguf')).toBe(true);
    });

    it('matches primary_file basename', () => {
      expect(registryEntryMatchesIdentifier(entry, 'Qwen2-VL-7B-Instruct-Q4_K_M.gguf')).toBe(true);
    });

    it('matches primary_file basename stem without .gguf extension', () => {
      expect(registryEntryMatchesIdentifier(entry, 'Qwen2-VL-7B-Instruct-Q4_K_M')).toBe(true);
    });

    it('does not match unrelated identifier', () => {
      expect(registryEntryMatchesIdentifier(entry, 'llama-3.2-3b')).toBe(false);
    });
  });

  describe('streamSendMessage callback error ownership and onAccepted ordering', () => {
    it('fires onAccepted before stream body read on HTTP 200', async () => {
      const order: string[] = [];

      const mockBody = {
        getReader() {
          order.push('get-reader');
          let readCount = 0;
          return {
            read: async () => {
              order.push('reader-read');
              if (readCount === 0) {
                readCount++;
                return {
                  done: false,
                  value: new TextEncoder().encode('data: {"type":"token","content":"Hello"}\n\ndata: [DONE]\n\n'),
                };
              }
              return { done: true, value: undefined };
            },
          };
        },
      } as unknown as ReadableStream<Uint8Array>;

      globalThis.fetch = vi.fn().mockImplementation(async () => {
        order.push('fetch-response');
        return {
          ok: true,
          status: 200,
          body: mockBody,
        };
      });

      const onAccepted = vi.fn().mockImplementation(() => {
        order.push('onAccepted');
      });
      const onToken = vi.fn();
      const onDone = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hello',
        attachmentIds: ['att-1'],
        onAccepted,
        onToken,
        onDone,
        onError,
      });

      expect(order).toEqual(['fetch-response', 'onAccepted', 'get-reader', 'reader-read']);
      expect(onAccepted).toHaveBeenCalledTimes(1);
      expect(onError).not.toHaveBeenCalled();
      expect(onDone).toHaveBeenCalled();
      expect(onToken).toHaveBeenCalledWith('Hello');
    });

    it('calls onError with ApiError on explicit HTTP non-2xx and NEVER calls onAccepted', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({
          detail: 'Attachment does not belong to conversation.',
        }),
      });

      const onAccepted = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hello',
        attachmentIds: ['att-invalid'],
        onAccepted,
        onToken: vi.fn(),
        onDone: vi.fn(),
        onError,
      });

      expect(onAccepted).not.toHaveBeenCalled();
      expect(onError).toHaveBeenCalledTimes(1);
      const [err] = onError.mock.calls[0];
      expect(err).toBeInstanceOf(ApiError);
      expect(err.status).toBe(422);
      expect(err.message).toContain('Attachment does not belong to conversation.');
    });

    it('calls onError with transport Error on network drop before response and NEVER calls onAccepted', async () => {
      globalThis.fetch = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));

      const onAccepted = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hello',
        onAccepted,
        onToken: vi.fn(),
        onDone: vi.fn(),
        onError,
      });

      expect(onAccepted).not.toHaveBeenCalled();
      expect(onError).toHaveBeenCalledTimes(1);
      const [err] = onError.mock.calls[0];
      expect(err).toBeInstanceOf(TypeError);
      expect(err).not.toBeInstanceOf(ApiError);
    });

    it('fires onAccepted before throwing if response.ok is true but response.body is missing', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        body: null,
      });

      const onAccepted = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hello',
        onAccepted,
        onToken: vi.fn(),
        onDone: vi.fn(),
        onError,
      });

      // onAccepted fired because HTTP 200 was received
      expect(onAccepted).toHaveBeenCalledTimes(1);
      // then missing body throws and reaches onError
      expect(onError).toHaveBeenCalledTimes(1);
      const [err] = onError.mock.calls[0];
      expect(err.message).toContain('ReadableStream not supported');
    });
  });
});
