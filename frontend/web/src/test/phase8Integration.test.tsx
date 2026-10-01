import '@testing-library/jest-dom/vitest';
import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { AssistantView } from '../components/workspace/AssistantView';
import { BackendProvider, useBackend } from '../context/BackendContext';
import { ThemeProvider } from '../context/ThemeContext';
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
    renameConversation: vi.fn(),
    generateConversationTitle: vi.fn(),
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
  {
    manifest: {
      id: 'multimodal-missing-mmproj',
      display_name: 'Multimodal Missing mmproj',
      primary_file: 'models/multimodal-missing-mmproj.gguf',
      capabilities: ['chat', 'vision'],
    },
    library_state: {
      // Vision capability absent due to missing mmproj projector file
      available_capabilities: ['chat'],
    },
    hints: {},
    runtime_model_id: 'multimodal-missing-mmproj',
    registry_source: 'installed',
  },
];

describe('Phase 8 Cross-Feature Integration Suite (8C.4 Matrix)', () => {
  const originalCreateObjectURL = URL.createObjectURL;
  const originalRevokeObjectURL = URL.revokeObjectURL;

  beforeEach(() => {
    localStorage.clear();
    localStorage.setItem('companion_api_url', 'http://127.0.0.1:8000');
    localStorage.setItem('companion_api_key', 'test-key');

    URL.createObjectURL = vi.fn().mockImplementation((blob: any) => 'blob:http://localhost/mock-blob-url');
    URL.revokeObjectURL = vi.fn();

    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.fetchModelRegistry).mockResolvedValue(mockRegistry as any);
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-integ-1',
          title: 'Integration Test Conversation',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-30T00:00:00Z',
          updated_at: '2026-09-30T00:00:00Z',
        },
      ],
      total: 1,
    });
    vi.mocked(api.getMessages).mockResolvedValue({ items: [], total: 0 });
    vi.mocked(uploadAttachment).mockResolvedValue({
      id: 'att-integ-1',
      conversation_id: 'conv-integ-1',
      message_id: null,
      filename_display: 'screenshot.png',
      mime_type: 'image/png',
      size_bytes: 2048,
      image_width: 800,
      image_height: 600,
      created_at: '2026-09-30T00:00:00Z',
    });
    vi.mocked(fetchAttachmentBlobUrl).mockResolvedValue('blob:http://localhost/mock-blob-url');
    vi.mocked(deleteAttachment).mockResolvedValue();
    vi.mocked(streamSendMessage).mockResolvedValue();
  });

  afterEach(() => {
    URL.createObjectURL = originalCreateObjectURL;
    URL.revokeObjectURL = originalRevokeObjectURL;
    vi.restoreAllMocks();
  });

  const renderWithProviders = () => {
    return render(
      <ThemeProvider>
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      </ThemeProvider>
    );
  };

  // 1. Send + reload + authenticated attachment preview
  it('Scenario 1: Send + reload + authenticated attachment preview', async () => {
    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Stage an image attachment
    const pngFile = new File(['png-content'], 'screenshot.png', { type: 'image/png' });
    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [pngFile] } });
    });

    await waitFor(() => {
      expect(screen.getByTestId('staged-card-att-integ-1')).toBeInTheDocument();
    });

    // Send with prompt
    const input = screen.getByPlaceholderText(/Message Aura/i);
    fireEvent.change(input, { target: { value: 'Analyze this diagram' } });

    await act(async () => {
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));
    });

    expect(streamSendMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 'conv-integ-1',
        userText: 'Analyze this diagram',
        attachmentIds: ['att-integ-1'],
      })
    );

    // Simulate reload where getMessages returns the persisted message with attachment
    vi.mocked(api.getMessages).mockResolvedValue({
      items: [
        {
          id: 'msg-integ-persisted',
          conversation_id: 'conv-integ-1',
          sender: 'user',
          content: 'Analyze this diagram',
          status: 'completed',
          sequence_no: 1,
          attachments: [
            {
              id: 'att-integ-1',
              filename_display: 'screenshot.png',
              mime_type: 'image/png',
              size_bytes: 2048,
            },
          ],
          created_at: '2026-09-30T00:01:00Z',
        } as any,
      ],
      total: 1,
    });

    // Re-mount / reload
    const { unmount } = renderWithProviders();

    await waitFor(() => {
      expect(api.getMessages).toHaveBeenCalledWith('conv-integ-1');
    }, { timeout: 5000 });

    // Verify authenticated preview fetch was invoked with conversation and attachment IDs
    await waitFor(() => {
      expect(fetchAttachmentBlobUrl).toHaveBeenCalledWith('conv-integ-1', 'att-integ-1');
      expect(screen.getByAltText('screenshot.png')).toBeInTheDocument();
    }, { timeout: 5000 });

    unmount();
  });

  // 2. Send + cancel mid-stream -> user message + image remain in history
  it('Scenario 2: Send + cancel mid-stream -> user message + image remain in history', async () => {
    let acceptCallback: (() => void) | undefined;
    vi.mocked(streamSendMessage).mockImplementation(async (options) => {
      acceptCallback = options.onAccepted;
      // Keep in streaming state so Stop action remains available
      return new Promise(() => {});
    });

    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Stage attachment
    const pngFile = new File(['png-content'], 'screenshot.png', { type: 'image/png' });
    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [pngFile] } });
    });

    await waitFor(() => {
      expect(screen.getByTestId('staged-card-att-integ-1')).toBeInTheDocument();
    });

    // Send
    const input = screen.getByPlaceholderText(/Message Aura/i);
    fireEvent.change(input, { target: { value: 'Inspect image' } });
    fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

    // Turn is accepted by backend
    await act(async () => {
      acceptCallback?.();
    });

    // User message with attachment is committed to visible history
    await waitFor(() => {
      expect(screen.getByText('Inspect image')).toBeInTheDocument();
      expect(screen.getByAltText('screenshot.png')).toBeInTheDocument();
    });

    // Trigger mid-stream stop/cancel
    const stopBtn = screen.getByRole('button', { name: /Stop Generation/i });
    expect(stopBtn).toBeInTheDocument();
    await act(async () => {
      fireEvent.click(stopBtn);
    });

    // After cancellation, user message and attachment preview remain permanently visible in history
    expect(screen.getByText('Inspect image')).toBeInTheDocument();
    expect(screen.getByAltText('screenshot.png')).toBeInTheDocument();
  });

  // 3. Text-only model -> attachment disabled; text-only send still works
  it('Scenario 3: Text-only model -> attachment disabled; text-only send still works', async () => {
    // Active model lacks vision
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({ active_model: 'llama-3.2-3b-instruct' })
    );

    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Paperclip button is disabled with explicit tooltip
    const paperclip = screen.getByTestId('attachment-paperclip-button');
    expect(paperclip).toBeDisabled();
    expect(paperclip).toHaveAttribute('title', 'Active model does not support image input');

    // Text-only prompt send still works normally
    const input = screen.getByPlaceholderText(/Message Aura/i);
    fireEvent.change(input, { target: { value: 'Hello text model' } });

    const sendBtn = screen.getByTitle(/Send prompt to local model/i);
    expect(sendBtn).not.toBeDisabled();

    await act(async () => {
      fireEvent.click(sendBtn);
    });

    expect(streamSendMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 'conv-integ-1',
        userText: 'Hello text model',
        attachmentIds: [],
      })
    );
  });

  // 4. Remove staged -> DELETE, URL revoked, composer card gone
  it('Scenario 4: Remove staged -> DELETE, URL revoked, composer card gone', async () => {
    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Stage image
    const file = new File(['content'], 'screenshot.png', { type: 'image/png' });
    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
    });

    await waitFor(() => {
      expect(screen.getByTestId('staged-card-att-integ-1')).toBeInTheDocument();
    });

    // Remove staged attachment
    const removeBtn = screen.getByRole('button', { name: /Remove attachment screenshot\.png/i });
    await act(async () => {
      fireEvent.click(removeBtn);
    });

    // deleteAttachment called on API
    expect(deleteAttachment).toHaveBeenCalledWith('conv-integ-1', 'att-integ-1');
    // Blob URL revoked
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:http://localhost/mock-blob-url');
    // Composer card removed
    expect(screen.queryByTestId('staged-card-att-integ-1')).not.toBeInTheDocument();
  });

  // 5. 5th image blocked
  it('Scenario 5: 5th image blocked', async () => {
    let uploadCount = 0;
    vi.mocked(uploadAttachment).mockImplementation(async (convId, file) => {
      uploadCount++;
      return {
        id: `att-quota-${uploadCount}`,
        conversation_id: convId,
        message_id: null,
        filename_display: file.name,
        mime_type: 'image/png',
        size_bytes: 1024,
        image_width: 800,
        image_height: 600,
        created_at: '2026-09-30T00:00:00Z',
      };
    });

    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Attempt to stage 5 files at once
    const files = [
      new File(['1'], 'img1.png', { type: 'image/png' }),
      new File(['2'], 'img2.png', { type: 'image/png' }),
      new File(['3'], 'img3.png', { type: 'image/png' }),
      new File(['4'], 'img4.png', { type: 'image/png' }),
      new File(['5'], 'img5.png', { type: 'image/png' }), // 5th image exceeds ceiling of 4
    ];

    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files } });
    });

    // First 4 files stage successfully
    await waitFor(() => {
      expect(screen.getByTestId('staged-card-att-quota-4')).toBeInTheDocument();
    });

    // 5th file was blocked: exactly 4 uploads executed
    expect(uploadAttachment).toHaveBeenCalledTimes(4);

    // Paperclip button is now disabled due to maximum capacity reached
    const paperclip = screen.getByTestId('attachment-paperclip-button');
    expect(paperclip).toBeDisabled();
    expect(paperclip).toHaveAttribute('title', 'Maximum 4 attachments reached');
  });

  // 6. PNG/JPEG accepted; WebP rejected with user-visible message
  it('Scenario 6: PNG/JPEG accepted; WebP rejected with user-visible message', async () => {
    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Attempt to upload WebP
    const webpFile = new File(['webp-binary'], 'graphic.webp', { type: 'image/webp' });
    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [webpFile] } });
    });

    // WebP rejected client-side with user-visible warning
    expect(screen.getByText(/"graphic\.webp": Only PNG and JPEG images are supported\./i)).toBeInTheDocument();
    expect(uploadAttachment).not.toHaveBeenCalled();

    // Now upload valid PNG
    const pngFile = new File(['png-binary'], 'valid.png', { type: 'image/png' });
    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [pngFile] } });
    });

    // PNG accepted and uploaded
    await waitFor(() => {
      expect(uploadAttachment).toHaveBeenCalledWith('conv-integ-1', pngFile);
    });
  });

  // 7. Vision -> text-only model switch -> attachment control disabled and incompatible pending attachment warned
  it('Scenario 7: Vision -> text-only model switch -> attachment control disabled and incompatible pending attachment warned', async () => {
    vi.mocked(api.loadModel).mockResolvedValue(
      createMockStatus({ active_model: 'llama-3.2-3b-instruct' })
    );

    const ModelSwitcherHelper = () => {
      const { loadModel } = useBackend();
      return (
        <button
          data-testid="test-switch-model-btn"
          onClick={() => loadModel('llama-3.2-3b-instruct')}
        >
          Switch to Text Model
        </button>
      );
    };

    render(
      <ThemeProvider>
        <BackendProvider>
          <ModelSwitcherHelper />
          <AssistantView />
        </BackendProvider>
      </ThemeProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Stage attachment under vision model
    const file = new File(['content'], 'screenshot.png', { type: 'image/png' });
    await act(async () => {
      fireEvent.change(screen.getByTestId('attachment-file-input'), { target: { files: [file] } });
    });

    await waitFor(() => {
      expect(screen.getByTestId('staged-card-att-integ-1')).toBeInTheDocument();
    });

    // Switch model to text-only model (llama-3.2-3b-instruct)
    await act(async () => {
      fireEvent.click(screen.getByTestId('test-switch-model-btn'));
    });

    // Attachment control disables and vision-loss warning is displayed
    await waitFor(() => {
      expect(screen.getByTestId('vision-loss-warning')).toBeInTheDocument();
      expect(
        screen.getByText(/Current active model does not support image input\. Remove attachments or switch to a vision-enabled model to send\./i)
      ).toBeInTheDocument();
    }, { timeout: 5000 });

    const paperclip = screen.getByTestId('attachment-paperclip-button');
    expect(paperclip).toBeDisabled();

    // Send button is disabled while incompatible attachment is staged
    const sendBtn = screen.getByTitle(/Send prompt to local model/i);
    expect(sendBtn).toBeDisabled();

    // Remove the staged attachment
    const removeBtn = screen.getByRole('button', { name: /Remove attachment screenshot\.png/i });
    await act(async () => {
      fireEvent.click(removeBtn);
    });

    // After removing incompatible attachment, warning clears and text prompt can be sent
    await waitFor(() => {
      expect(screen.queryByTestId('vision-loss-warning')).not.toBeInTheDocument();
    });

    const input = screen.getByPlaceholderText(/Message Aura/i);
    fireEvent.change(input, { target: { value: 'Text query after model switch' } });
    expect(sendBtn).not.toBeDisabled();
  });

  // 8. Missing mmproj -> vision attachment control disabled
  it('Scenario 8: Missing mmproj -> vision attachment control disabled', async () => {
    // Active model has manifest declaring chat+vision, but library_state lacks vision because mmproj is absent
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({ active_model: 'multimodal-missing-mmproj' })
    );

    renderWithProviders();

    await waitFor(() => {
      expect(screen.getByText('Integration Test Conversation')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Because mmproj is missing, hasVision is false
    const paperclip = screen.getByTestId('attachment-paperclip-button');
    expect(paperclip).toBeDisabled();
    expect(paperclip).toHaveAttribute('title', 'Active model does not support image input');
  });
});
