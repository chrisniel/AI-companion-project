import '@testing-library/jest-dom/vitest';
import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { AssistantView, classifyStreamError } from '../components/workspace/AssistantView';
import { BackendProvider } from '../context/BackendContext';
import * as api from '../services/api';
import { ModelStatusResponse } from '../services/api/modelApi';
import { streamSendMessage } from '../services/api/conversationApi';

// Mock API calls
vi.mock('../services/api', async () => {
  const actual = await vi.importActual<typeof import('../services/api')>('../services/api');
  return {
    ...actual,
    checkHealth: vi.fn().mockResolvedValue({ status: 'healthy' }),
    getModelStatus: vi.fn(),
    loadModel: vi.fn(),
    unloadModel: vi.fn(),
    updateModelProfile: vi.fn(),
    listConversations: vi.fn().mockResolvedValue({
      items: [
        {
          id: 'conv-1',
          title: 'Daily Briefing & Local System Orchestration',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
        {
          id: 'conv-2',
          title: 'Deep Work Session',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T01:00:00Z',
          updated_at: '2026-09-14T01:00:00Z',
        },
      ],
      total: 2,
    }),
    getMessages: vi.fn().mockResolvedValue({
      items: [
        {
          id: 'msg-existing-1',
          conversation_id: 'conv-1',
          sender: 'user',
          content: 'Hello Aura',
          status: 'completed',
          sequence_no: 1,
          created_at: '2026-09-14T00:01:00Z',
        },
        {
          id: 'msg-existing-2',
          conversation_id: 'conv-1',
          sender: 'assistant',
          content: 'Good morning Chris, ready to assist.',
          status: 'completed',
          sequence_no: 2,
          created_at: '2026-09-14T00:01:05Z',
        },
      ],
      total: 2,
    }),
    fetchModelRegistry: vi.fn().mockResolvedValue([
      {
        id: 'qwen3-vl-2b-instruct',
        display_name: 'Qwen3-VL-2B-Instruct',
        family: 'Qwen',
        variant: 'instruct',
        primary_file: 'models/qwen3-vl-2b-instruct.gguf',
        companion_files: [{ role: 'mmproj', path: 'models/mmproj-qwen3-vl-2b-instruct.gguf' }],
        capabilities: ['chat', 'vision'],
        recommended_profiles: ['eco', 'balanced'],
        estimated_vram_gb: 2.1,
        estimated_ram_gb: 1.1,
        quantization: 'Q4_K_M',
        parameters: '2.4B',
        context_limit: 2048,
        license: 'Apache-2.0',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: 1.6,
      },
      {
        id: 'qwen3-vl-4b-instruct',
        display_name: 'Qwen3-VL-4B-Instruct',
        family: 'Qwen',
        variant: 'instruct',
        primary_file: 'models/qwen3-vl-4b-instruct.gguf',
        companion_files: [{ role: 'mmproj', path: 'models/mmproj-qwen3-vl-4b-instruct.gguf' }],
        capabilities: ['chat', 'vision'],
        recommended_profiles: ['balanced', 'maximum'],
        estimated_vram_gb: 4.2,
        estimated_ram_gb: 1.5,
        quantization: 'Q4_K_M',
        parameters: '4.4B',
        context_limit: 4096,
        license: 'Apache-2.0',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: 2.8,
      },
    ]),
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
    available_models: ['models/qwen3-vl-2b-instruct.gguf'],
    available_registry: ['models/qwen3-vl-2b-instruct.gguf'],
    context_size: 4096,
    gpu_layers: 28,
    idle_timeout_seconds: 300,
    seconds_until_idle: 300,
    seconds_until_unload: null,
    ...overrides,
  };
}

function createMockSseStream(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  let idx = 0;
  return new ReadableStream({
    pull(controller) {
      if (idx < chunks.length) {
        controller.enqueue(encoder.encode(chunks[idx]));
        idx++;
      } else {
        controller.close();
      }
    },
  });
}

describe('Phase 5: Assistant Web UI & SSE Stream Reliability', () => {
  let originalFetch: typeof global.fetch;

  beforeEach(() => {
    vi.clearAllMocks();
    originalFetch = global.fetch;
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-1',
          title: 'Daily Briefing & Local System Orchestration',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
        {
          id: 'conv-2',
          title: 'Deep Work Session',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T01:00:00Z',
          updated_at: '2026-09-14T01:00:00Z',
        },
      ],
      total: 2,
    });
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  describe('1. AssistantView Render & Authoritative Model Identity', () => {
    it('renders AssistantView cleanly without useCallback crash', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      // Verify header rendered and active character is present
      await waitFor(() => {
        expect(screen.getByText(/Active Persona:/i)).toBeInTheDocument();
      });
      expect(screen.getAllByText('Aura').length).toBeGreaterThan(0);
    });

    it('displays truthful active model name and applied profile without fake CUDA or mock claims', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({
          active_model: 'qwen3-vl-2b-instruct',
          applied_profile: 'balanced',
        })
      );

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      await waitFor(() => {
        // Authoritative registry display name
        expect(screen.getByText('Qwen3-VL-2B-Instruct')).toBeInTheDocument();
      });

      // Truthful runtime badge (provider from backend truth)
      expect(screen.getByText('llama.cpp')).toBeInTheDocument();

      // No fake CUDA claim
      expect(screen.queryByText('llama.cpp (CUDA)')).not.toBeInTheDocument();

      // Awake badge
      expect(screen.getByText('Awake')).toBeInTheDocument();
    });

    it('represents sleeping model truthfully with purple badge and native sleep banner', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({
          active_model: 'qwen3-vl-2b-instruct',
          runtime_state: 'MODEL_SLEEPING',
          model_resident: false,
          model_loaded: true,
          model_awake: false,
        })
      );

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      await waitFor(() => {
        expect(screen.getByText('Sleeping')).toBeInTheDocument();
      });

      // Banner explaining native sleep
      expect(
        screen.getByText(/Model is sleeping in RAM \(VRAM released\)/i)
      ).toBeInTheDocument();
      expect(screen.getByText('Native Sleep')).toBeInTheDocument();

      // Must not falsely claim model is completely unloaded
      expect(
        screen.queryByText(/Model is unloaded \(0 MB VRAM used\)/i)
      ).not.toBeInTheDocument();
    });

    it('represents unloaded state truthfully when no model is active', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({
          active_model: null,
          runtime_state: 'MODEL_UNLOADED',
          model_loaded: false,
          model_awake: false,
          model_resident: false,
        })
      );

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      await waitFor(() => {
        expect(screen.getByText('No Model Loaded')).toBeInTheDocument();
      });
      expect(
        screen.getByText(/No model is currently loaded\. Click Load Model/i)
      ).toBeInTheDocument();
    });
  });

  describe('2. Deterministic SSE Protocol & Unexpected EOF Semantics', () => {
    it('streamSendMessage succeeds with explicit done frame', async () => {
      const chunks = [
        'data: {"type":"token","content":"Hello "}\n\n',
        'data: {"type":"token","content":"world!"}\n\n',
        'data: {"type":"done","finish_reason":"stop"}\n\n',
      ];

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        body: createMockSseStream(chunks),
      } as unknown as Response);

      const onToken = vi.fn();
      const onDone = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hi',
        onToken,
        onDone,
        onError,
      });

      expect(onToken).toHaveBeenCalledTimes(2);
      expect(onToken).toHaveBeenNthCalledWith(1, 'Hello ');
      expect(onToken).toHaveBeenNthCalledWith(2, 'world!');
      expect(onDone).toHaveBeenCalledTimes(1);
      expect(onError).not.toHaveBeenCalled();
    });

    it('streamSendMessage fails cleanly when explicit error frame is received', async () => {
      const chunks = [
        'data: {"type":"token","content":"Starting generation..."}\n\n',
        'data: {"type":"error","code":"MODEL_GENERATION_FAILED","message":"Internal GPU crash"}\n\n',
      ];

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        body: createMockSseStream(chunks),
      } as unknown as Response);

      const onToken = vi.fn();
      const onDone = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hi',
        onToken,
        onDone,
        onError,
      });

      expect(onToken).toHaveBeenCalledWith('Starting generation...');
      expect(onError).toHaveBeenCalledTimes(1);
      const [err, partial] = onError.mock.calls[0];
      expect(err.code).toBe('MODEL_GENERATION_FAILED');
      expect(err.message).toBe('Internal GPU crash');
      expect(partial).toBe('Starting generation...');
      expect(onDone).not.toHaveBeenCalled();
    });

    it('streamSendMessage treats unexpected EOF before terminal done/error as STREAM_TERMINATED', async () => {
      // Stream terminates abruptly after yielding partial tokens without done or error
      const chunks = ['data: {"type":"token","content":"Halfway done"}\n\n'];

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        body: createMockSseStream(chunks),
      } as unknown as Response);

      const onToken = vi.fn();
      const onDone = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hi',
        onToken,
        onDone,
        onError,
      });

      expect(onToken).toHaveBeenCalledWith('Halfway done');
      expect(onError).toHaveBeenCalledTimes(1);
      const [err, partial] = onError.mock.calls[0];
      expect(err.code).toBe('STREAM_TERMINATED');
      expect(partial).toBe('Halfway done');
      expect(onDone).not.toHaveBeenCalled();
    });

    it('streamSendMessage handles AbortController cancellation cleanly without treating it as an error', async () => {
      const controller = new AbortController();

      global.fetch = vi.fn().mockImplementation(() => {
        controller.abort();
        const err = new Error('The user aborted a request.');
        err.name = 'AbortError';
        return Promise.reject(err);
      });

      const onToken = vi.fn();
      const onDone = vi.fn();
      const onError = vi.fn();

      await streamSendMessage({
        conversationId: 'conv-1',
        userText: 'Hi',
        signal: controller.signal,
        onToken,
        onDone,
        onError,
      });

      // Cancellation triggers clean onDone, not onError
      expect(onDone).toHaveBeenCalledTimes(1);
      expect(onError).not.toHaveBeenCalled();
    });
  });

  describe('3. Stop Generation, Empty Bubble Prevention & Selection Reconnect', () => {
    it('stop generation halts busy state immediately and avoids empty assistant bubble', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

      // Slow stream that doesn't finish immediately
      global.fetch = vi.fn().mockImplementation(() => {
        const stream = new ReadableStream({
          start() {
            // Keep open
          },
        });
        return Promise.resolve({ ok: true, body: stream });
      });

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      // Wait for conversation messages to load initially
      await screen.findByText('Good morning Chris, ready to assist.');

      // Type and send a prompt
      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'Test stop generation' } });
      const sendBtn = screen.getByTitle(/Send prompt to local model/i);
      fireEvent.click(sendBtn);

      // Busy indicator should show up
      await waitFor(() => {
        expect(screen.getByTitle('Stop generation')).toBeInTheDocument();
      });

      // Click stop generation
      const stopBtn = screen.getByTitle('Stop generation');
      fireEvent.click(stopBtn);

      // Stop button disappears, state returns to idle
      await waitFor(() => {
        expect(screen.queryByTitle('Stop generation')).not.toBeInTheDocument();
      });

      // The placeholder bubble was not left blank; it was replaced with stopped notice
      await waitFor(() => {
        expect(screen.getByText(/\*\[Generation stopped by user\]\*/)).toBeInTheDocument();
        expect(screen.getByText(/\[USER_CANCELLED\]/)).toBeInTheDocument();
      });
    });

    it('zero tokens plus stream failure replaces placeholder with visible failure notice', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        body: createMockSseStream([
          'data: {"type":"error","code":"MODEL_GENERATION_FAILED","message":"GPU out of memory"}\n\n',
        ]),
      } as unknown as Response);

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      // Wait for conversation messages to load initially
      await screen.findByText('Good morning Chris, ready to assist.');

      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'Trigger OOM' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      // Must display visible failure notice with MODEL_GENERATION_FAILED
      await waitFor(() => {
        expect(
          screen.getByText(/Model generation failed: GPU out of memory\. \[MODEL_GENERATION_FAILED\]/i)
        ).toBeInTheDocument();
      });
    });

    it('transport failure when model is loaded reports connection failed without falsely blaming model', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({
          model_loaded: true,
          model_awake: true,
          runtime_state: 'MODEL_READY',
          active_model: 'qwen3-vl-2b-instruct',
        })
      );

      // Simulate fetch transport failure (Failed to fetch) on POST /messages
      global.fetch = vi.fn().mockImplementation((url: string) => {
        if (typeof url === 'string' && url.includes('/messages') && !url.includes('skip=')) {
          return Promise.reject(new TypeError('Failed to fetch'));
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ items: [], total: 0 }),
        });
      });

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      await screen.findByText('Good morning Chris, ready to assist.');

      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'test message' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      await waitFor(() => {
        expect(
          screen.getByText(/Connection to the Assistant stream failed\. Core and model status remain available\. \[STREAM_CONNECTION_FAILED: Failed to fetch\]/i)
        ).toBeInTheDocument();
      });

      // Must NOT falsely tell user to ensure model is loaded
      expect(
        screen.queryByText(/Ensure Local AI Core is running and model is loaded/i)
      ).not.toBeInTheDocument();
    });

    it('transport failure when model is unloaded correctly reports model unloaded error', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(
        createMockStatus({
          model_loaded: false,
          model_awake: false,
          runtime_state: 'MODEL_UNLOADED',
          active_model: null,
        })
      );

      global.fetch = vi.fn().mockImplementation((url: string) => {
        if (typeof url === 'string' && url.includes('/messages') && !url.includes('skip=')) {
          return Promise.reject(new TypeError('Failed to fetch'));
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ items: [], total: 0 }),
        });
      });

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      await screen.findByText('Good morning Chris, ready to assist.');

      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'test unloaded' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      await waitFor(() => {
        expect(
          screen.getByText(/No active model loaded\. Ensure an LLM model is loaded in Models view\. \[MODEL_NOT_LOADED: Failed to fetch\]/i)
        ).toBeInTheDocument();
      });
    });

    it('transport failure when Core is offline reports CORE_OFFLINE error', async () => {
      vi.mocked(api.checkHealth).mockRejectedValue(new Error('Core unreachable'));
      vi.mocked(api.getModelStatus).mockRejectedValue(new Error('Core unreachable'));

      global.fetch = vi.fn().mockImplementation((url: string) => {
        if (typeof url === 'string' && url.includes('/messages') && !url.includes('skip=')) {
          return Promise.reject(new TypeError('Failed to fetch'));
        }
        return Promise.reject(new Error('Connection refused'));
      });

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      // In offline mode, wait for composer input to be ready
      const input = await screen.findByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'test core offline' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      await waitFor(() => {
        expect(
          screen.getByText(/Local AI Core is offline\. Ensure Local AI Core is running on :8000\. \[CORE_OFFLINE: Failed to fetch\]/i)
        ).toBeInTheDocument();
      });
    });

    it('abrupt stream EOF reports STREAM_TERMINATED code', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

      // Create stream that ends without [DONE] or type: "done"
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        body: createMockSseStream([
          'data: {"type":"token","content":"First partial token"}\n\n',
        ]),
      } as unknown as Response);

      render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      await screen.findByText('Good morning Chris, ready to assist.');

      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'Test abrupt EOF' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      await waitFor(() => {
        expect(
          screen.getByText(/STREAM_TERMINATED/i)
        ).toBeInTheDocument();
      });
    });

    describe('classifyStreamError unit tests', () => {
      const readyStatus = createMockStatus({
        runtime_state: 'MODEL_READY',
        model_loaded: true,
        model_awake: true,
        active_model: 'qwen3-vl-2b-instruct',
      });

      it('classifies USER_CANCELLED on abort', () => {
        const res = classifyStreamError(new Error('The user aborted a request.'), true, readyStatus);
        expect(res.code).toBe('USER_CANCELLED');
        expect(res.visibleMessage).toContain('[USER_CANCELLED]');
      });

      it('classifies CORE_OFFLINE when isOnline is false', () => {
        const res = classifyStreamError(new TypeError('Failed to fetch'), false, null);
        expect(res.code).toBe('CORE_OFFLINE');
        expect(res.visibleMessage).toContain('[CORE_OFFLINE: Failed to fetch]');
        expect(res.visibleMessage).toContain('Ensure Local AI Core is running on :8000');
      });

      it('classifies MODEL_NOT_LOADED when model is unloaded', () => {
        const unloaded = createMockStatus({ runtime_state: 'MODEL_UNLOADED', model_loaded: false });
        const res = classifyStreamError(new Error('LLM_UNAVAILABLE'), true, unloaded);
        expect(res.code).toBe('MODEL_NOT_LOADED');
        expect(res.visibleMessage).toContain('[MODEL_NOT_LOADED: LLM_UNAVAILABLE]');
      });

      it('classifies MODEL_SLEEPING when runtime_state is MODEL_SLEEPING', () => {
        const sleeping = createMockStatus({ runtime_state: 'MODEL_SLEEPING', model_loaded: true, model_awake: false });
        const res = classifyStreamError(new Error('Model is sleeping'), true, sleeping);
        expect(res.code).toBe('MODEL_SLEEPING');
        expect(res.visibleMessage).toContain('[MODEL_SLEEPING: Model is sleeping]');
      });

      it('classifies WAKE_FAILED when error indicates wake failure', () => {
        const res = classifyStreamError(new Error('Auto wake failed for worker'), true, readyStatus);
        expect(res.code).toBe('WAKE_FAILED');
        expect(res.visibleMessage).toContain('[WAKE_FAILED: Auto wake failed for worker]');
      });

      it('classifies STREAM_CONNECTION_FAILED on transport error when model is ready', () => {
        const res = classifyStreamError(new TypeError('Failed to fetch'), true, readyStatus);
        expect(res.code).toBe('STREAM_CONNECTION_FAILED');
        expect(res.visibleMessage).toContain('[STREAM_CONNECTION_FAILED: Failed to fetch]');
        expect(res.visibleMessage).toContain('Connection to the Assistant stream failed. Core and model status remain available.');
      });

      it('classifies STREAM_TERMINATED on premature stream EOF', () => {
        const err = Object.assign(new Error('Stream ended abruptly before explicit completion.'), { code: 'STREAM_TERMINATED' });
        const res = classifyStreamError(err, true, readyStatus);
        expect(res.code).toBe('STREAM_TERMINATED');
        expect(res.visibleMessage).toContain('[STREAM_TERMINATED: Stream ended abruptly before explicit completion.]');
      });

      it('classifies MODEL_GENERATION_FAILED on generation failure chunk', () => {
        const err = Object.assign(new Error('CUDA out of memory'), { code: 'MODEL_GENERATION_FAILED' });
        const res = classifyStreamError(err, true, readyStatus);
        expect(res.code).toBe('MODEL_GENERATION_FAILED');
        expect(res.visibleMessage).toContain('[MODEL_GENERATION_FAILED]');
      });
    });

    it('reconnecting backend preserves the active conversation selection', async () => {
      vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

      const { rerender } = render(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      // Initial load selects conv-1 from mock list
      await waitFor(() => {
        expect(
          screen.getByText('Daily Briefing & Local System Orchestration')
        ).toBeInTheDocument();
      });

      // Open drawer and switch to conv-2
      const historyBtn = screen.getByTitle('Open Conversation History');
      fireEvent.click(historyBtn);

      const conv2Item = await screen.findByText('Deep Work Session');
      fireEvent.click(conv2Item);

      // Title is updated to Deep Work Session
      await waitFor(() => {
        expect(screen.getByText('Deep Work Session')).toBeInTheDocument();
      });

      // Simulate a backend reconnect (e.g. heartbeat returns status again)
      await act(async () => {
        vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
      });

      rerender(
        <BackendProvider>
          <AssistantView />
        </BackendProvider>
      );

      // Crucial requirement: Current selection 'Deep Work Session' (conv-2) MUST NOT be wiped out back to items[0]
      expect(screen.getByText('Deep Work Session')).toBeInTheDocument();
    });
  });
});
