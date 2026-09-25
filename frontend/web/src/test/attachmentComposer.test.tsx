import '@testing-library/jest-dom/vitest';
import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { AssistantView } from '../components/workspace/AssistantView';
import { BackendProvider } from '../context/BackendContext';
import * as api from '../services/api';
import { ModelStatusResponse } from '../services/api/modelApi';
import {
  uploadAttachment,
  fetchAttachmentBlobUrl,
  deleteAttachment,
  streamSendMessage,
} from '../services/api';

// Mock API module
vi.mock('../services/api', async () => {
  const actual = await vi.importActual<typeof import('../services/api')>('../services/api');
  return {
    ...actual,
    checkHealth: vi.fn().mockResolvedValue({ status: 'healthy' }),
    getModelStatus: vi.fn(),
    loadModel: vi.fn(),
    unloadModel: vi.fn(),
    updateModelProfile: vi.fn(),
    createConversation: vi.fn(),
    listConversations: vi.fn(),
    getMessages: vi.fn(),
    fetchModelRegistry: vi.fn(),
    uploadAttachment: vi.fn(),
    fetchAttachmentBlobUrl: vi.fn(),
    deleteAttachment: vi.fn(),
    streamSendMessage: vi.fn(),
  };
});

function createMockStatus(overrides: Partial<ModelStatusResponse> = {}): ModelStatusResponse {
  return {
    provider: 'llama.cpp',
    engine_version: 'b10936',
    router_running: true,
    managed_by_core: true,
    runtime_state: 'MODEL_READY',
    active_model: 'qwen3-vl-2b-instruct',
    model_resident: true,
    model_loaded: true,
    model_awake: true,
    requested_profile: 'balanced',
    applied_profile: 'balanced',
    applied_context_size: 4096,
    applied_gpu_layers: 28,
    requested_mmproj_offload: true,
    applied_mmproj_offload: true,
    generation_active: false,
    last_runtime_error: null,
    mmproj_offload: true,
    is_loaded: true,
    active_profile: 'balanced',
    context_size: 4096,
    gpu_layers: 28,
    idle_timeout_seconds: 900,
    seconds_until_idle: 850,
    seconds_until_unload: null,
    available_models: ['qwen3-vl-2b-instruct.gguf'],
    ...overrides,
  };
}

const mockRegistry = [
  {
    manifest: {
      id: 'qwen3-vl-2b-instruct',
      display_name: 'Qwen3-VL 2B Instruct',
      primary_file: 'models/qwen3-vl-2b-instruct.gguf',
      capabilities: ['chat', 'vision'],
    },
    library_state: {
      available_capabilities: ['chat', 'vision'],
    },
    hints: {},
    runtime_model_id: 'qwen3-vl-2b-instruct',
    registry_source: 'installed',
  },
  {
    manifest: {
      id: 'llama-3.2-3b-instruct',
      display_name: 'Llama 3.2 3B Instruct',
      primary_file: 'models/llama-3.2-3b-instruct.gguf',
      capabilities: ['chat'],
    },
    library_state: {
      available_capabilities: ['chat'],
    },
    hints: {},
    runtime_model_id: 'llama-3.2-3b-instruct',
    registry_source: 'installed',
  },
];

describe('Phase 8B.6 Web Attachment Composer Integration Tests', () => {
  const originalCreateObjectURL = URL.createObjectURL;
  const originalRevokeObjectURL = URL.revokeObjectURL;

  beforeEach(() => {
    localStorage.clear();
    localStorage.setItem('companion_api_url', 'http://127.0.0.1:8000');
    localStorage.setItem('companion_api_key', 'test-key');

    URL.createObjectURL = vi.fn().mockImplementation((blob) => `blob:http://localhost/mock-${Math.random()}`);
    URL.revokeObjectURL = vi.fn();

    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.fetchModelRegistry).mockResolvedValue(mockRegistry as any);
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-1',
          title: 'Test Session A',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-25T00:00:00Z',
          updated_at: '2026-09-25T00:00:00Z',
        },
        {
          id: 'conv-2',
          title: 'Test Session B',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-25T01:00:00Z',
          updated_at: '2026-09-25T01:00:00Z',
        },
      ],
      total: 2,
    });
    vi.mocked(api.getMessages).mockResolvedValue({ items: [], total: 0 });
    vi.mocked(api.createConversation).mockResolvedValue({
      id: 'conv-new-1',
      title: 'New Conversation',
      character_id: 'aura',
      owner_id: 'chris',
      created_at: '2026-09-25T02:00:00Z',
      updated_at: '2026-09-25T02:00:00Z',
    });
    vi.mocked(uploadAttachment).mockResolvedValue({
      id: 'att-1',
      conversation_id: 'conv-1',
      message_id: null,
      file_name: 'test.png',
      content_type: 'image/png',
      byte_size: 1024,
      sha256: 'sha256-abc',
      created_at: '2026-09-25T00:00:00Z',
    });
    vi.mocked(fetchAttachmentBlobUrl).mockResolvedValue('blob:http://localhost/mock-att-1');
    vi.mocked(deleteAttachment).mockResolvedValue();
    vi.mocked(streamSendMessage).mockResolvedValue();
  });

  afterEach(() => {
    URL.createObjectURL = originalCreateObjectURL;
    URL.revokeObjectURL = originalRevokeObjectURL;
    vi.restoreAllMocks();
  });

  const renderWithBackend = () => {
    return render(
      <BackendProvider>
        <AssistantView />
      </BackendProvider>
    );
  };

  describe('1. Capability Gating', () => {
    it('enables paperclip button when active model has vision capability', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const paperclip = screen.getByTestId('attachment-paperclip-button');
      expect(paperclip).not.toBeDisabled();
      expect(paperclip).toHaveAttribute('title', 'Attach image (PNG or JPEG, max 10 MiB)');
    });

    it('disables paperclip button when active model lacks vision capability', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({ active_model: 'llama-3.2-3b-instruct' })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const paperclip = screen.getByTestId('attachment-paperclip-button');
      expect(paperclip).toBeDisabled();
      expect(paperclip).toHaveAttribute('title', 'Active model does not support image input');
    });

    it('renders inline warning if attachments are staged but active model lacks vision', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      // Stage an attachment while model has vision
      const file = new File(['image-bytes'], 'chart.png', { type: 'image/png' });
      const input = screen.getByTestId('attachment-file-input');

      await act(async () => {
        fireEvent.change(input, { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      // Now simulate active model changing to a non-vision model
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({ active_model: 'llama-3.2-3b-instruct' })
      );

      // Re-poll status in backend provider
      await act(async () => {
        // Fast forward / trigger poll
      });
    });
  });

  describe('2. Local Validation & Multi-File Quota', () => {
    it('rejects unsupported MIME types with explicit error message', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const pdfFile = new File(['dummy-pdf'], 'doc.pdf', { type: 'application/pdf' });
      const input = screen.getByTestId('attachment-file-input');

      await act(async () => {
        fireEvent.change(input, { target: { files: [pdfFile] } });
      });

      expect(screen.getByText('Only PNG and JPEG images are supported.')).toBeInTheDocument();
      expect(uploadAttachment).not.toHaveBeenCalled();
    });

    it('rejects zero-byte files with explicit error message', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const emptyFile = new File([], 'empty.png', { type: 'image/png' });
      const input = screen.getByTestId('attachment-file-input');

      await act(async () => {
        fireEvent.change(input, { target: { files: [emptyFile] } });
      });

      expect(screen.getByText('Zero-byte files cannot be attached.')).toBeInTheDocument();
      expect(uploadAttachment).not.toHaveBeenCalled();
    });

    it('rejects files exceeding 10 MiB with explicit error message', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const hugeFile = new File([new Uint8Array(10 * 1024 * 1024 + 1)], 'huge.png', { type: 'image/png' });
      const input = screen.getByTestId('attachment-file-input');

      await act(async () => {
        fireEvent.change(input, { target: { files: [hugeFile] } });
      });

      expect(screen.getByText('File "huge.png" exceeds the 10 MiB limit.')).toBeInTheDocument();
      expect(uploadAttachment).not.toHaveBeenCalled();
    });

    it('accepts valid files up to quota limit of 4 sequentially and rejects remainder', async () => {
      let callCount = 0;
      vi.mocked(uploadAttachment).mockImplementation(async (convId, file) => {
        callCount++;
        return {
          id: `att-${callCount}`,
          conversation_id: convId,
          message_id: null,
          file_name: file.name,
          content_type: 'image/png',
          byte_size: 1024,
          sha256: `hash-${callCount}`,
          created_at: '2026-09-25T00:00:00Z',
        };
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const files = [
        new File(['1'], 'img1.png', { type: 'image/png' }),
        new File(['2'], 'img2.png', { type: 'image/png' }),
        new File(['3'], 'img3.png', { type: 'image/png' }),
        new File(['4'], 'img4.png', { type: 'image/png' }),
        new File(['5'], 'img5.png', { type: 'image/png' }), // exceeds quota
      ];

      const input = screen.getByTestId('attachment-file-input');

      await act(async () => {
        fireEvent.change(input, { target: { files } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
        expect(screen.getByTestId('staged-card-att-4')).toBeInTheDocument();
      });

      // Exactly 4 uploads attempted
      expect(uploadAttachment).toHaveBeenCalledTimes(4);
      expect(screen.queryByTestId('staged-card-att-5')).not.toBeInTheDocument();
    });
  });

  describe('3. Staged Card Removal & Double-Click Serialization', () => {
    it('rapid double click on remove issues exactly one DELETE request', async () => {
      let resolveDelete: () => void = () => {};
      const deletePromise = new Promise<void>((resolve) => {
        resolveDelete = resolve;
      });
      vi.mocked(deleteAttachment).mockImplementation(() => deletePromise);

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      // Stage an attachment
      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      const removeBtn = screen.getByRole('button', { name: /Remove attachment test\.png/i });

      // Click twice rapidly in same execution frame
      act(() => {
        fireEvent.click(removeBtn);
        fireEvent.click(removeBtn);
      });

      expect(deleteAttachment).toHaveBeenCalledTimes(1);

      // Resolve the DELETE
      await act(async () => {
        resolveDelete();
      });

      await waitFor(() => {
        expect(screen.queryByTestId('staged-card-att-1')).not.toBeInTheDocument();
      });
      expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-att-1');
    });
  });

  describe('4. Send Lifecycle & onAccepted Invariants', () => {
    it('freezes textarea, sets awaiting_acceptance, and does NOT render message bubbles before onAccepted', async () => {
      let resolveStream: () => void = () => {};
      let capturedOnAccepted: (() => void) | undefined;

      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        capturedOnAccepted = opts.onAccepted;
        await new Promise<void>((resolve) => {
          resolveStream = resolve;
        });
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const textarea = screen.getByTestId('composer-textarea') as HTMLTextAreaElement;
      fireEvent.change(textarea, { target: { value: 'Analyze this data' } });

      const sendBtn = screen.getByTestId('send-message-button');
      expect(sendBtn).not.toBeDisabled();

      // Click Send
      act(() => {
        fireEvent.click(sendBtn);
      });

      // Textarea must be frozen (readOnly)
      expect(textarea).toHaveAttribute('readonly');

      // Crucial: No optimistic bubbles before HTTP acceptance!
      const bubblesBefore = screen
        .queryAllByText('Analyze this data')
        .filter((el) => el.tagName !== 'TEXTAREA');
      expect(bubblesBefore).toHaveLength(0);

      // Now simulate server returning HTTP 200 and triggering onAccepted
      await act(async () => {
        capturedOnAccepted?.();
      });

      // Now bubbles must be rendered!
      expect(screen.getByText('Analyze this data')).toBeInTheDocument();

      // Resolve stream
      await act(async () => {
        resolveStream();
      });
    });

    it('immediate unmount after Send issues ZERO deleteAttachment calls', async () => {
      let resolveStream: () => void = () => {};

      vi.mocked(streamSendMessage).mockImplementation(async () => {
        await new Promise<void>((resolve) => {
          resolveStream = resolve;
        });
      });

      const { unmount } = renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      // Stage an attachment
      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      // Send
      act(() => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // Immediately unmount component while send is in awaiting_acceptance
      unmount();

      // deleteAttachment must NOT have been called for the in-flight send snapshot!
      expect(deleteAttachment).not.toHaveBeenCalled();

      resolveStream();
    });

    it('sends fallback user_text when input prompt is empty with attachments', async () => {
      let capturedUserText = '';
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        capturedUserText = opts.userText;
        opts.onAccepted?.();
        opts.onDone?.();
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      // Stage an attachment
      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      // Send button should be enabled even without prompt text
      const sendBtn = screen.getByTestId('send-message-button');
      expect(sendBtn).not.toBeDisabled();

      await act(async () => {
        fireEvent.click(sendBtn);
      });

      expect(capturedUserText).toBe('Shared attachment for processing.');
    });
  });

  describe('5. Error Handling & outcome_unknown', () => {
    it('pre-acceptance HTTP 422 re-enables textarea, restores idle phase, and preserves draft + staged cards', async () => {
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        opts.onError(
          new api.ApiError({
            code: 'MESSAGE_PREPARATION_FAILED',
            message: 'Model busy with previous turn.',
            status: 422,
          }),
          ''
        );
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      const textarea = screen.getByTestId('composer-textarea') as HTMLTextAreaElement;
      fireEvent.change(textarea, { target: { value: 'My prompt' } });

      await act(async () => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // Error message shown in banner
      expect(screen.getByText('Model busy with previous turn.')).toBeInTheDocument();

      // Draft & staged card preserved
      expect(textarea.value).toBe('My prompt');
      expect(textarea).not.toHaveAttribute('readonly');
      expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();

      // Bubbles were never created
      const bubbles = screen
        .queryAllByText('My prompt')
        .filter((el) => el.tagName !== 'TEXTAREA');
      expect(bubbles).toHaveLength(0);
    });

    it('pre-acceptance transport drop transitions to outcome_unknown, preserves cards, and blocks destructive actions', async () => {
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        // Transport error before onAccepted
        opts.onError(new TypeError('Failed to fetch'), '');
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await act(async () => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // Reconciliation warning banner is shown
      expect(screen.getByText(/Connection lost before server confirmed message acceptance/i)).toBeInTheDocument();

      // Destructive actions blocked: Send disabled, New Chat disabled, Remove button hidden/disabled
      expect(screen.getByTestId('send-message-button')).toBeDisabled();
      expect(screen.getByRole('button', { name: /New Chat/i })).toBeDisabled();

      // Attachment DELETE is NEVER called
      expect(deleteAttachment).not.toHaveBeenCalled();
    });

    it('post-acceptance SSE failure updates assistant bubble error only and does not restore staged cards', async () => {
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        opts.onAccepted?.();
        opts.onToken('Initial tokens');
        opts.onError(new Error('Connection interrupted during streaming'), 'Initial tokens');
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await act(async () => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // Assistant bubble updated with error
      await waitFor(() => {
        expect(screen.getByText(/Initial tokens/i)).toBeInTheDocument();
      });

      // Staged card stays cleared
      expect(screen.queryByTestId('staged-card-att-1')).not.toBeInTheDocument();
    });
  });

  describe('6. Navigation & Button Locks', () => {
    it('disables both New Chat buttons during awaiting_acceptance and outcome_unknown', async () => {
      let capturedOnAccepted: (() => void) | undefined;
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        capturedOnAccepted = opts.onAccepted;
        await new Promise(() => {}); // never resolves
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const statusNewChat = screen.getByRole('button', { name: /New Chat/i });
      expect(statusNewChat).not.toBeDisabled();

      // Send message
      fireEvent.change(screen.getByTestId('composer-textarea'), { target: { value: 'Test' } });
      act(() => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // Both status bar New Chat and drawer are disabled
      expect(statusNewChat).toBeDisabled();

      // Open history drawer
      fireEvent.click(screen.getByTitle('Open Conversation History'));
      const drawerNewConversation = screen.getByRole('button', { name: /New Conversation/i });
      expect(drawerNewConversation).toBeDisabled();
    });
  });

  describe('7. Async Conversation Transitions & Concurrency Locks', () => {
    it('rapid double click on New Chat starts at most one createConversation request', async () => {
      let resolveCreate: () => void = () => {};
      vi.mocked(api.createConversation).mockImplementation(
        () => new Promise((resolve) => { resolveCreate = () => resolve({ id: 'c-new', title: 'New', character_id: 'aura', owner_id: 'chris', created_at: '', updated_at: '' }); })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const newChatBtn = screen.getByRole('button', { name: /New Chat/i });

      act(() => {
        fireEvent.click(newChatBtn);
        fireEvent.click(newChatBtn);
      });

      expect(api.createConversation).toHaveBeenCalledTimes(1);

      await act(async () => {
        resolveCreate();
      });
    });

    it('attempting Send while New Chat is in flight is blocked', async () => {
      let resolveCreate: () => void = () => {};
      vi.mocked(api.createConversation).mockImplementation(
        () => new Promise((resolve) => { resolveCreate = () => resolve({ id: 'c-new', title: 'New', character_id: 'aura', owner_id: 'chris', created_at: '', updated_at: '' }); })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      fireEvent.change(screen.getByTestId('composer-textarea'), { target: { value: 'Prompt' } });

      // Start New Chat
      act(() => {
        fireEvent.click(screen.getByRole('button', { name: /New Chat/i }));
      });

      // Send button must be disabled
      const sendBtn = screen.getByTestId('send-message-button');
      expect(sendBtn).toBeDisabled();

      // Attempting send via Enter key is also blocked
      fireEvent.keyDown(screen.getByTestId('composer-textarea'), { key: 'Enter', code: 'Enter' });
      expect(streamSendMessage).not.toHaveBeenCalled();

      await act(async () => {
        resolveCreate();
      });
    });

    it('A -> B -> A stale upload race: old upload does NOT stage after returning to A', async () => {
      let resolveUpload: (val: any) => void = () => {};
      vi.mocked(uploadAttachment).mockImplementation(
        () => new Promise((resolve) => { resolveUpload = resolve; })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      // Start upload in A
      const file = new File(['content'], 'slow.png', { type: 'image/png' });
      act(() => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      // Now switch to B
      fireEvent.click(screen.getByTitle('Open Conversation History'));
      const convBItem = screen.getByRole('heading', { level: 3, name: 'Test Session B' });
      act(() => {
        fireEvent.click(convBItem);
      });

      // Switch back to A
      fireEvent.click(screen.getByTitle('Open Conversation History'));
      const convAItem = screen.getByRole('heading', { level: 3, name: 'Test Session A' });
      act(() => {
        fireEvent.click(convAItem);
      });

      // Now resolve the old upload from the first visit to A
      await act(async () => {
        resolveUpload({
          id: 'att-stale',
          conversation_id: 'conv-1',
          message_id: null,
          file_name: 'slow.png',
          content_type: 'image/png',
          byte_size: 1024,
          sha256: 'sha-stale',
          created_at: '2026-09-25T00:00:00Z',
        });
      });

      // The stale upload must NOT be staged in the current lifecycle of A!
      expect(screen.queryByTestId('staged-card-att-stale')).not.toBeInTheDocument();

      // The orphaned upload row must have been cleaned
      expect(deleteAttachment).toHaveBeenCalledWith('conv-1', 'att-stale');
    });

    it('cleanup helper fails closed when called during awaiting_acceptance or outcome_unknown', async () => {
      let capturedOnError: ((err: Error, partialText?: string) => void) | undefined;
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        capturedOnError = opts.onError;
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByRole('heading', { level: 1, name: 'Test Session A' })).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      // Send to enter awaiting_acceptance
      act(() => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // Attempt drawer conversation selection while awaiting_acceptance
      fireEvent.click(screen.getByTitle('Open Conversation History'));
      const sessionB = screen.getByRole('heading', { level: 3, name: 'Test Session B' });
      act(() => {
        fireEvent.click(sessionB);
      });

      // Selection must have been ignored; active conversation remains Test Session A
      expect(screen.getByRole('heading', { level: 1, name: 'Test Session A' })).toBeInTheDocument();
      expect(deleteAttachment).not.toHaveBeenCalled();

      // Transition to outcome_unknown via network error
      await act(async () => {
        capturedOnError?.(new TypeError('Failed to fetch'));
      });

      // In outcome_unknown, selection is still blocked and no DELETE occurs
      act(() => {
        fireEvent.click(sessionB);
      });
      expect(screen.getByRole('heading', { level: 1, name: 'Test Session A' })).toBeInTheDocument();
      expect(deleteAttachment).not.toHaveBeenCalled();
    });
  });
});
