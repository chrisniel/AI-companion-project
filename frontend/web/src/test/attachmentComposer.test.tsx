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
  AttachmentOut,
  MAX_ATTACHMENTS_PER_MESSAGE,
  MAX_SIZE_BYTES,
  ALLOWED_MIME_TYPES,
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

    URL.createObjectURL = vi.fn().mockImplementation(() => `blob:http://localhost/mock-${Math.random()}`);
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
      filename_display: 'test.png',
      mime_type: 'image/png',
      size_bytes: 1024,
      image_width: 800,
      image_height: 600,
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

  describe('1. Capability Gating & Metadata (Items 1, 4, 13)', () => {
    it('enables paperclip button when active model has vision capability', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const paperclip = screen.getByTestId('attachment-paperclip-button');
      expect(paperclip).not.toBeDisabled();
      expect(paperclip).toHaveAttribute('title', 'Attach image (PNG or JPEG, max 10 MiB)');
    });

    it('disables paperclip and shows vision-loss warning when active model lacks vision', async () => {
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

    it('renders metadata on staged card using filename_display and size_bytes', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['12345'], 'screenshot.png', { type: 'image/png' });
      vi.mocked(uploadAttachment).mockResolvedValueOnce({
        id: 'att-meta',
        conversation_id: 'conv-1',
        message_id: null,
        filename_display: 'screenshot.png',
        mime_type: 'image/png',
        size_bytes: 5120, // 5 KB
        image_width: 1024,
        image_height: 768,
        created_at: '2026-09-25T00:00:00Z',
      });

      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-meta')).toBeInTheDocument();
      });

      // Alt text uses filename_display
      const img = screen.getByAltText('screenshot.png');
      expect(img).toBeInTheDocument();

      // Size rendered in KB
      expect(screen.getByText('5 KB')).toBeInTheDocument();

      // Remove button title and aria-label use filename_display
      const removeBtn = screen.getByRole('button', { name: /Remove attachment screenshot\.png/i });
      expect(removeBtn).toHaveAttribute('title', 'Remove screenshot.png');
    });
  });

  describe('2. Local Validation & Mixed-Batch Quota (Items 4, 16)', () => {
    it('rejects unsupported mime types', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const badFile = new File(['dummy'], 'document.pdf', { type: 'application/pdf' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [badFile] } });
      });

      expect(screen.getByText(/"document\.pdf": Only PNG and JPEG images are supported\./i)).toBeInTheDocument();
      expect(uploadAttachment).not.toHaveBeenCalled();
    });

    it('rejects zero-byte files with explicit error message', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const emptyFile = new File([], 'empty.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [emptyFile] } });
      });

      expect(screen.getByText(/"empty\.png": Zero-byte files cannot be attached\./i)).toBeInTheDocument();
      expect(uploadAttachment).not.toHaveBeenCalled();
    });

    it('rejects files exceeding 10 MiB', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const hugeFile = new File([new Uint8Array(MAX_SIZE_BYTES + 1)], 'huge.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [hugeFile] } });
      });

      expect(screen.getByText(/"huge\.png": Exceeds the 10 MiB limit\./i)).toBeInTheDocument();
      expect(uploadAttachment).not.toHaveBeenCalled();
    });

    it('mixed batch: invalid file does not consume quota, valid files stage, warning retained', async () => {
      let counter = 0;
      vi.mocked(uploadAttachment).mockImplementation(async (convId, file) => {
        counter++;
        return {
          id: `att-mixed-${counter}`,
          conversation_id: convId,
          message_id: null,
          filename_display: file.name,
          mime_type: 'image/png',
          size_bytes: 1024,
          image_width: 800,
          image_height: 600,
          created_at: '2026-09-25T00:00:00Z',
        };
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const badFile = new File(['text'], 'note.txt', { type: 'text/plain' });
      const goodFile1 = new File(['1'], 'good1.png', { type: 'image/png' });
      const goodFile2 = new File(['2'], 'good2.jpg', { type: 'image/jpeg' });

      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), {
          target: { files: [badFile, goodFile1, goodFile2] },
        });
      });

      // Staged cards rendered for valid files
      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-mixed-1')).toBeInTheDocument();
        expect(screen.getByTestId('staged-card-att-mixed-2')).toBeInTheDocument();
      });

      // Retain warning for rejected file
      expect(screen.getByText(/"note\.txt": Only PNG and JPEG images are supported\./i)).toBeInTheDocument();
      expect(uploadAttachment).toHaveBeenCalledTimes(2);
    });

    it('selecting more valid files than remaining capacity surfaces quota notice', async () => {
      let counter = 0;
      vi.mocked(uploadAttachment).mockImplementation(async (convId, file) => {
        counter++;
        return {
          id: `att-quota-${counter}`,
          conversation_id: convId,
          message_id: null,
          filename_display: file.name,
          mime_type: 'image/png',
          size_bytes: 1024,
          image_width: 800,
          image_height: 600,
          created_at: '2026-09-25T00:00:00Z',
        };
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const files = [
        new File(['1'], '1.png', { type: 'image/png' }),
        new File(['2'], '2.png', { type: 'image/png' }),
        new File(['3'], '3.png', { type: 'image/png' }),
        new File(['4'], '4.png', { type: 'image/png' }),
        new File(['5'], '5.png', { type: 'image/png' }), // 5th exceeds quota of 4
      ];

      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-quota-4')).toBeInTheDocument();
      });

      expect(uploadAttachment).toHaveBeenCalledTimes(4);
      expect(screen.getByText(/Only 4 more attachments can be added \(max 4 per message\)\./i)).toBeInTheDocument();
    });
  });

  describe('3. Preview Rollback & Explicit Removal Failure (Items 5, 6)', () => {
    it('rolls back uploaded row via deleteAttachment if preview creation fails', async () => {
      vi.mocked(uploadAttachment).mockResolvedValueOnce({
        id: 'att-orphan-1',
        conversation_id: 'conv-1',
        message_id: null,
        filename_display: 'orphan.png',
        mime_type: 'image/png',
        size_bytes: 1024,
        image_width: 800,
        image_height: 600,
        created_at: '2026-09-25T00:00:00Z',
      });
      // Preview fetch fails
      vi.mocked(fetchAttachmentBlobUrl).mockRejectedValueOnce(
        new Error('Failed to fetch preview image')
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'orphan.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      // Must call deleteAttachment to clean up the uploaded row
      expect(deleteAttachment).toHaveBeenCalledWith('conv-1', 'att-orphan-1');
      // No card staged
      expect(screen.queryByTestId('staged-card-att-orphan-1')).not.toBeInTheDocument();
      // Error is displayed to user
      expect(screen.getByText(/Failed to fetch preview image/i)).toBeInTheDocument();
    });

    it('successful removal revokes preview URL and removes card', async () => {
      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      const removeBtn = screen.getByRole('button', { name: /Remove attachment test\.png/i });
      await act(async () => {
        fireEvent.click(removeBtn);
      });

      expect(deleteAttachment).toHaveBeenCalledWith('conv-1', 'att-1');
      expect(screen.queryByTestId('staged-card-att-1')).not.toBeInTheDocument();
      expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-att-1');
    });

    it('DELETE failure (500) preserves staged card and preview URL, shows error', async () => {
      vi.mocked(deleteAttachment).mockRejectedValueOnce(
        new api.ApiError({ code: 'SERVER_ERROR', message: 'Internal Server Error', status: 500 })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      const removeBtn = screen.getByRole('button', { name: /Remove attachment test\.png/i });
      await act(async () => {
        fireEvent.click(removeBtn);
      });

      // Card is PRESERVED on failure
      expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      // URL is NOT revoked on failure
      expect(URL.revokeObjectURL).not.toHaveBeenCalled();
      // Error shown
      expect(screen.getByText('Internal Server Error')).toBeInTheDocument();
    });

    it('DELETE failure (404) preserves staged card and preview URL, shows error', async () => {
      vi.mocked(deleteAttachment).mockRejectedValueOnce(
        new api.ApiError({ code: 'NOT_FOUND', message: 'Attachment not found', status: 404 })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      const removeBtn = screen.getByRole('button', { name: /Remove attachment test\.png/i });
      await act(async () => {
        fireEvent.click(removeBtn);
      });

      // Explicit removal treats 404 as error: card preserved, error shown
      expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      expect(URL.revokeObjectURL).not.toHaveBeenCalled();
      expect(screen.getByText('Attachment not found')).toBeInTheDocument();
    });

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

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      const removeBtn = screen.getByRole('button', { name: /Remove attachment test\.png/i });

      act(() => {
        fireEvent.click(removeBtn);
        fireEvent.click(removeBtn);
      });

      expect(deleteAttachment).toHaveBeenCalledTimes(1);

      await act(async () => {
        resolveDelete();
      });

      await waitFor(() => {
        expect(screen.queryByTestId('staged-card-att-1')).not.toBeInTheDocument();
      });
    });
  });

  describe('4. Navigation & Conversation Switching Locks (Item 7, 15)', () => {
    it('upload in progress disables conversation switching, New Conversation, and status-bar New Chat', async () => {
      let resolveUpload: () => void = () => {};
      vi.mocked(uploadAttachment).mockImplementation(
        () => new Promise((resolve) => { resolveUpload = () => resolve({ id: 'att-up', conversation_id: 'conv-1', message_id: null, filename_display: 'slow.png', mime_type: 'image/png', size_bytes: 1024, image_width: null, image_height: null, created_at: '' }); })
      );

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      // Start upload
      const file = new File(['content'], 'slow.png', { type: 'image/png' });
      act(() => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      // 1. Status-bar New Chat must be disabled
      const statusNewChat = screen.getByRole('button', { name: /New Chat/i });
      expect(statusNewChat).toBeDisabled();

      // Open drawer
      fireEvent.click(screen.getByTitle('Open Conversation History'));

      // 2. Drawer New Conversation must be disabled
      const drawerNewConv = screen.getByRole('button', { name: /New Conversation/i });
      expect(drawerNewConv).toBeDisabled();

      // 3. Conversation items in drawer must be disabled
      const sessionB = screen.getByRole('button', { name: /Test Session B/i });
      expect(sessionB).toHaveAttribute('aria-disabled', 'true');

      // Clicking conversation item cannot switch while upload is in progress
      act(() => {
        fireEvent.click(sessionB);
      });

      // Active title remains Test Session A
      expect(screen.getByRole('heading', { level: 1, name: 'Test Session A' })).toBeInTheDocument();

      await act(async () => {
        resolveUpload();
      });
    });
  });

  describe('5. Guard Sending Without Real Conversation (Item 12)', () => {
    it('disables send and sends no POST when active conversation is missing', async () => {
      vi.mocked(api.listConversations).mockResolvedValue({ items: [], total: 0 });
      vi.mocked(api.createConversation).mockRejectedValue(new Error('Creation failed'));

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('No Conversation')).toBeInTheDocument();
      });

      const textarea = screen.getByTestId('composer-textarea');
      fireEvent.change(textarea, { target: { value: 'Hello' } });

      const sendBtn = screen.getByTestId('send-message-button');
      // Send button is rendered disabled
      expect(sendBtn).toBeDisabled();

      // Attempting Enter key send sends NO POST to /messages
      fireEvent.keyDown(textarea, { key: 'Enter', code: 'Enter' });
      expect(streamSendMessage).not.toHaveBeenCalled();
    });
  });

  describe('6. Send Lifecycle, Invariants, and Unmount Cleanup (Items 8, 11)', () => {
    it('onAccepted commits bubbles, clears staged cards, and does NOT call deleteAttachment', async () => {
      let capturedOnAccepted: (() => void) | undefined;
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        capturedOnAccepted = opts.onAccepted;
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      const textarea = screen.getByTestId('composer-textarea');
      fireEvent.change(textarea, { target: { value: 'Prompt' } });

      act(() => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      // No bubbles before onAccepted
      expect(screen.queryAllByText('Prompt').filter((el) => el.tagName !== 'TEXTAREA')).toHaveLength(0);

      // Trigger onAccepted
      await act(async () => {
        capturedOnAccepted?.();
      });

      // Bubbles committed
      expect(screen.getByText('Prompt')).toBeInTheDocument();
      // Staged cards cleared without DELETE
      expect(screen.queryByTestId('staged-card-att-1')).not.toBeInTheDocument();
      expect(deleteAttachment).not.toHaveBeenCalled();
      expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-att-1');
    });

    it('unmount while idle revokes Blob URLs and best-effort deletes remote staged rows', async () => {
      const { unmount } = renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      await waitFor(() => {
        expect(screen.getByTestId('staged-card-att-1')).toBeInTheDocument();
      });

      unmount();

      // Revokes URL locally
      expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-att-1');
      // Performs remote delete when idle
      expect(deleteAttachment).toHaveBeenCalledWith('conv-1', 'att-1');
    });

    it('unmount during outcome_unknown revokes Blob URLs but performs ZERO deleteAttachment calls', async () => {
      vi.mocked(streamSendMessage).mockImplementation(async (opts) => {
        opts.onError(new TypeError('Failed to fetch'), '');
      });

      const { unmount } = renderWithBackend();

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

      expect(screen.getByText(/Connection lost before server confirmed message acceptance/i)).toBeInTheDocument();

      unmount();

      // URL revoked
      expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-att-1');
      // ZERO remote delete
      expect(deleteAttachment).not.toHaveBeenCalled();
    });

    it('unmount immediately after Send (awaiting_acceptance) performs ZERO deleteAttachment calls', async () => {
      vi.mocked(streamSendMessage).mockImplementation(async () => {
        await new Promise(() => {}); // pending
      });

      const { unmount } = renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Test Session A')).toBeInTheDocument();
      });

      const file = new File(['content'], 'test.png', { type: 'image/png' });
      await act(async () => {
        fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
      });

      act(() => {
        fireEvent.click(screen.getByTestId('send-message-button'));
      });

      unmount();

      // ZERO remote delete
      expect(deleteAttachment).not.toHaveBeenCalled();
    });
  });

  describe('7. Effect Loop Prevention (Item 10)', () => {
    it('does not enter infinite listConversations loop when listConversations returns fresh array instances', async () => {
      let callCount = 0;
      vi.mocked(api.listConversations).mockImplementation(async () => {
        callCount++;
        return {
          items: [
            {
              id: 'conv-fresh-1',
              title: 'Fresh Title',
              character_id: 'aura',
              owner_id: 'chris',
              created_at: '2026-09-25T00:00:00Z',
              updated_at: '2026-09-25T00:00:00Z',
            },
          ],
          total: 1,
        };
      });

      renderWithBackend();

      await waitFor(() => {
        expect(screen.getByText('Fresh Title')).toBeInTheDocument();
      });

      // Wait a short moment to ensure no infinite effect re-triggering
      await new Promise((r) => setTimeout(r, 100));

      // listConversations should be called exactly once
      expect(callCount).toBe(1);
    });
  });
});
