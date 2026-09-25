import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  uploadAttachment,
  fetchAttachmentBlobUrl,
  deleteAttachment,
  AttachmentOut,
  ALLOWED_MIME_TYPES,
  MAX_SIZE_BYTES,
  MAX_ATTACHMENTS_PER_MESSAGE,
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

  describe('canonical constraints', () => {
    it('exports canonical attachment constants aligned with backend', () => {
      expect(ALLOWED_MIME_TYPES).toEqual(['image/png', 'image/jpeg']);
      expect(MAX_SIZE_BYTES).toBe(10 * 1024 * 1024);
      expect(MAX_ATTACHMENTS_PER_MESSAGE).toBe(4);
    });
  });

  describe('uploadAttachment', () => {
    it('sends multipart/form-data via apiFetch and parses exact AttachmentOut schema', async () => {
      let capturedUrl = '';
      let capturedInit: RequestInit | undefined;

      const backendResponse: AttachmentOut = {
        id: 'att-123',
        conversation_id: 'conv-1',
        message_id: null,
        filename_display: 'photo.png',
        mime_type: 'image/png',
        size_bytes: 2048,
        image_width: 800,
        image_height: 600,
        created_at: '2026-09-25T00:00:00Z',
      };

      globalThis.fetch = vi.fn().mockImplementation(async (url, init) => {
        capturedUrl = String(url);
        capturedInit = init;
        return {
          ok: true,
          status: 201,
          json: async () => backendResponse,
        };
      });

      const file = new File(['dummy binary content'], 'photo.png', { type: 'image/png' });
      const result = await uploadAttachment('conv-1', file);

      expect(capturedUrl).toBe('http://127.0.0.1:8000/api/v1/conversations/conv-1/attachments');
      expect(capturedInit?.method).toBe('POST');
      const headers = capturedInit?.headers as Headers;
      expect(headers.get('Authorization')).toBe('Bearer test-pairing-key');
      // Crucial: Content-Type must NOT be set manually on FormData requests
      expect(headers.get('Content-Type')).toBeNull();
      expect(capturedInit?.body).toBeInstanceOf(FormData);

      // Verify exact public schema fields (no file_name, content_type, byte_size, sha256)
      expect(result.id).toBe('att-123');
      expect(result.conversation_id).toBe('conv-1');
      expect(result.message_id).toBeNull();
      expect(result.filename_display).toBe('photo.png');
      expect(result.mime_type).toBe('image/png');
      expect(result.size_bytes).toBe(2048);
      expect(result.image_width).toBe(800);
      expect(result.image_height).toBe(600);
      expect(result.created_at).toBe('2026-09-25T00:00:00Z');
      expect((result as any).sha256).toBeUndefined();
      expect((result as any).file_name).toBeUndefined();
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
    it('fetches binary preview data with exact /preview URL and Authorization header', async () => {
      let capturedUrl = '';
      let capturedHeaders: Headers | undefined;

      const mockBlob = new Blob(['image-bytes'], { type: 'image/png' });
      globalThis.fetch = vi.fn().mockImplementation(async (url, init) => {
        capturedUrl = String(url);
        capturedHeaders = init?.headers as Headers;
        return {
          ok: true,
          status: 200,
          blob: async () => mockBlob,
        };
      });

      const blobUrl = await fetchAttachmentBlobUrl('conv-1', 'att-123');

      // Assert EXACT /preview route
      expect(capturedUrl).toBe('http://127.0.0.1:8000/api/v1/conversations/conv-1/attachments/att-123/preview');
      expect(capturedHeaders?.get('Authorization')).toBe('Bearer test-pairing-key');
      expect(URL.createObjectURL).toHaveBeenCalledWith(mockBlob);
      expect(blobUrl).toBe('blob:http://localhost/test-blob-uuid');
    });

    it('throws ApiError on preview HTTP non-2xx', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
      });

      await expect(fetchAttachmentBlobUrl('conv-1', 'att-missing')).rejects.toThrow('Failed to fetch attachment preview (404)');
    });
  });

  describe('deleteAttachment', () => {
    it('sends DELETE request via apiFetch with Authorization header and resolves on 204', async () => {
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

    it('throws ApiError on HTTP 404 (explicit removal policy does not swallow 404)', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
        json: async () => ({
          detail: 'Attachment not found',
        }),
      });

      await expect(deleteAttachment('conv-1', 'att-already-gone')).rejects.toThrow('Attachment not found');
    });

    it('throws ApiError on HTTP 500 failure', async () => {
      globalThis.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        json: async () => ({
          detail: 'Internal server error',
        }),
      });

      await expect(deleteAttachment('conv-1', 'att-err')).rejects.toThrow('Internal server error');
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
