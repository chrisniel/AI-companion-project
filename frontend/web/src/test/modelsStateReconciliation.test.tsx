import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { ModelsView } from '../components/workspace/ModelsView';
import { Header } from '../components/layout/Header';
import { BackendProvider } from '../context/BackendContext';
import { ThemeProvider } from '../context/ThemeContext';
import * as api from '../services/api';
import { ModelStatusResponse } from '../services/api/modelApi';

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
      {
        id: 'qwen3-vl-2b-thinking',
        display_name: 'Qwen3-VL-2B-Thinking',
        family: 'Qwen',
        variant: 'thinking',
        primary_file: 'models/qwen3-vl-2b-thinking.gguf',
        companion_files: [],
        capabilities: ['chat', 'reasoning'],
        recommended_profiles: ['eco', 'balanced'],
        estimated_vram_gb: 2.3,
        estimated_ram_gb: 1.2,
        quantization: 'Q4_K_M',
        parameters: '2.4B',
        context_limit: 2048,
        license: 'Apache-2.0',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: 1.7,
      },
    ]),
  };
});

function createMockStatus(overrides: Partial<ModelStatusResponse> = {}): ModelStatusResponse {
  return {
    provider: 'llama_cpp',
    engine_version: 'b10936',
    router_running: true,
    managed_by_core: true,
    runtime_state: 'MODEL_READY',
    active_model: 'qwen3-vl-4b-instruct',
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
    available_models: ['qwen3-vl-2b-instruct.gguf', 'qwen3-vl-4b-instruct.gguf', 'qwen3-vl-2b-thinking.gguf'],
    ...overrides,
  };
}

describe('Phase 4: Models Web UI State Reconciliation & Truthfulness', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
  });

  it('1. backend active model hydrates UI without relying on m-1 default', async () => {
    const status = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
      runtime_state: 'MODEL_READY',
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    // Should display Loaded / Awake in header and hero
    await waitFor(() => {
      expect(screen.getAllByText(/Loaded \/ Awake/i).length).toBeGreaterThan(0);
    });

    // 2B card must be labeled Loaded
    await waitFor(() => {
      const card2b = document.getElementById('model-card-qwen3-vl-2b-instruct');
      expect(card2b).not.toBeNull();
      expect(card2b?.textContent).toContain('Loaded');
    });
  });

  it('2. selected model and active model stay distinct and heartbeat does not override selection', async () => {
    // Backend reports 4B as loaded
    const status = createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      model_loaded: true,
      model_awake: true,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Qwen3-VL-4B-Instruct').length).toBeGreaterThanOrEqual(1);
    });

    // User clicks on 2B card to select it
    const card2b = document.getElementById('model-card-qwen3-vl-2b-instruct');
    expect(card2b).not.toBeNull();
    fireEvent.click(card2b!);

    // 2B card must now show Selected
    await waitFor(() => {
      expect(card2b?.textContent).toContain('Selected');
    });

    // 4B card must still show Loaded
    const card4b = document.getElementById('model-card-qwen3-vl-4b-instruct');
    expect(card4b?.textContent).toContain('Loaded');
    expect(card4b?.textContent).not.toContain('Selected');

    // Simulate heartbeat polling returning the same status
    // Selected card MUST NOT be reverted back to 4B!
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      seconds_until_idle: 800,
    }));

    // Wait a tick and verify 2B is STILL Selected
    await waitFor(() => {
      expect(card2b?.textContent).toContain('Selected');
    });
  });

  it('3. remount does not revert loaded model to m-1', async () => {
    const status = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
      model_loaded: true,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    const { unmount } = render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      const card2b = document.getElementById('model-card-qwen3-vl-2b-instruct');
      expect(card2b?.textContent).toContain('Loaded');
    });

    unmount();

    // Remount
    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      const card2b = document.getElementById('model-card-qwen3-vl-2b-instruct');
      expect(card2b?.textContent).toContain('Loaded');
    });
  });

  it('4. sleeping model remains logically Loaded and does not appear as Unloaded', async () => {
    const sleepingStatus = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
      runtime_state: 'MODEL_SLEEPING',
      model_loaded: true,
      model_awake: false,
      model_resident: false,
      seconds_until_idle: 0,
      seconds_until_unload: null,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(sleepingStatus);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText(/Loaded \/ Sleeping/i).length).toBeGreaterThan(0);
    });

    // Card should show Loaded (Sleeping)
    const card2b = document.getElementById('model-card-qwen3-vl-2b-instruct');
    expect(card2b?.textContent).toContain('Loaded (Sleeping)');

    // VRAM readout in Hero must reflect VRAM Released via Sleep
    expect(screen.getByText(/VRAM Released \(Sleeping\) \[Applied\]/i)).toBeDefined();
    // Sleeping badge must be present
    expect(screen.getByText(/Native Sleep \(VRAM Released\)/i)).toBeDefined();
  });

  it('5. exact Qwen variant matching prevents false positive loaded badges', async () => {
    // Only qwen3-vl-2b-instruct is loaded
    const status = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
      model_loaded: true,
      runtime_state: 'MODEL_READY',
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      const cardInstruct = document.getElementById('model-card-qwen3-vl-2b-instruct');
      expect(cardInstruct?.textContent).toContain('Loaded');
    });

    // Other Qwen variants MUST NOT be marked Loaded!
    const cardThinking = document.getElementById('model-card-qwen3-vl-2b-thinking');
    expect(cardThinking?.textContent).not.toContain('Loaded');

    const card4b = document.getElementById('model-card-qwen3-vl-4b-instruct');
    expect(card4b?.textContent).not.toContain('Loaded');
  });

  it('6. requested vs applied profile pending state during profile transition', async () => {
    // Switching to Eco, old router stopped, new router not yet up -> applied_profile = null
    const pendingStatus = createMockStatus({
      runtime_state: 'SERVER_STOPPED',
      router_running: false,
      active_model: null,
      model_loaded: false,
      requested_profile: 'eco',
      applied_profile: null,
      applied_context_size: null,
      applied_gpu_layers: null,
      requested_mmproj_offload: false,
      applied_mmproj_offload: null,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(pendingStatus);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('Pending')).toBeDefined();
    });

    // Requested should be Eco, Applied must show Pending
    expect(screen.getByText('Pending')).toBeDefined();
    expect(screen.getAllByText(/Pending \/ Not running/i).length).toBeGreaterThan(0);
  });

  it('7. applied context size and GPU layers display truthful verified values', async () => {
    const appliedEcoStatus = createMockStatus({
      requested_profile: 'eco',
      applied_profile: 'eco',
      applied_context_size: 2048,
      applied_gpu_layers: 0,
      requested_mmproj_offload: false,
      applied_mmproj_offload: false,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(appliedEcoStatus);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('2048 [Applied]')).toBeDefined();
      expect(screen.getByText('0 layers [Applied]')).toBeDefined();
      expect(screen.getByText('CPU [Applied]')).toBeDefined();
    });
  });

  it('8. unavailable telemetry never displays fabricated numbers', async () => {
    const status = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      // Must display Unavailable for TTFT rather than fake 18ms
      expect(screen.getByText('Live metric not reported')).toBeDefined();
      // Must display Unavailable for KV Cache rather than fake 1.2 GB
      expect(screen.getByText(/KV Cache: Unavailable/i)).toBeDefined();
    });

    // Ensure fake "42.8 t/s" is NOT present anywhere
    expect(screen.queryByText(/42\.8 t\/s/i)).toBeNull();
    // Ensure fake "18 ms" is NOT present anywhere
    expect(screen.queryByText(/18 ms/i)).toBeNull();
  });

  it('9. Header model dropdown populates from verified registry and contains no legacy mock models', async () => {
    const status = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <ThemeProvider>
        <BackendProvider>
          <Header
            searchQuery=""
            onSearchChange={() => {}}
            sidebarCollapsed={false}
            onToggleSidebarCollapse={() => {}}
            assistantPanelMode="expanded"
            onCycleAssistantPanelMode={() => {}}
          />
        </BackendProvider>
      </ThemeProvider>
    );

    // Open model selector dropdown in Header
    const trigger = screen.getByTitle('Current Local Model');
    fireEvent.click(trigger);

    // Dropdown must contain verified registry entries
    await waitFor(() => {
      expect(screen.getByText(/Qwen3-VL.*2B.*Instruct/i)).toBeDefined();
      expect(screen.getByText(/Qwen3-VL.*4B.*Instruct/i)).toBeDefined();
      expect(screen.getByText(/Qwen3-VL.*2B.*Thinking/i)).toBeDefined();
    });

    // Dropdown must NOT contain legacy mock models
    expect(screen.queryByText(/Qwen2\.5/i)).toBeNull();
    expect(screen.queryByText(/DeepSeek/i)).toBeNull();
    expect(screen.queryByText(/Gemma/i)).toBeNull();
    expect(screen.queryByText(/Mistral/i)).toBeNull();
    expect(screen.queryByText(/Gemini/i)).toBeNull();
  });

  it('10. Header model dropdown reflects truthful backend status and does not locally pretend model is active before load confirmation', async () => {
    const status = createMockStatus({
      active_model: 'qwen3-vl-2b-instruct',
      model_loaded: true,
      runtime_state: 'MODEL_READY',
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);
    vi.mocked(api.loadModel).mockResolvedValue(createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      model_loaded: true,
      runtime_state: 'MODEL_READY',
    }));

    render(
      <ThemeProvider>
        <BackendProvider>
          <Header
            searchQuery=""
            onSearchChange={() => {}}
            sidebarCollapsed={false}
            onToggleSidebarCollapse={() => {}}
            assistantPanelMode="expanded"
            onCycleAssistantPanelMode={() => {}}
          />
        </BackendProvider>
      </ThemeProvider>
    );

    // Open dropdown
    const trigger = screen.getByTitle('Current Local Model');
    fireEvent.click(trigger);

    await waitFor(() => {
      // 2B should show Loaded
      const loadedBadges = screen.getAllByText('Loaded');
      expect(loadedBadges.length).toBeGreaterThan(0);
      // 4B should show Disk
      const diskBadges = screen.getAllByText('Disk');
      expect(diskBadges.length).toBeGreaterThan(0);
    });

    // Click 4B in dropdown
    const item4b = screen.getByText('Qwen3-VL-4B-Instruct');
    fireEvent.click(item4b);

    // Reuses the backend loadModel action with exact ID
    expect(api.loadModel).toHaveBeenCalledWith('qwen3-vl-4b-instruct', undefined);
  });

  it('11. When Core is offline, Header selector shows Core Offline and Profile indicates Requested only', async () => {
    vi.mocked(api.checkHealth).mockRejectedValue(new Error('Network error'));

    render(
      <ThemeProvider>
        <BackendProvider>
          <Header
            searchQuery=""
            onSearchChange={() => {}}
            sidebarCollapsed={false}
            onToggleSidebarCollapse={() => {}}
            assistantPanelMode="expanded"
            onCycleAssistantPanelMode={() => {}}
            performanceProfile="balanced"
          />
        </BackendProvider>
      </ThemeProvider>
    );

    await waitFor(() => {
      // Model button should display Core Offline
      expect(screen.getByText('Core Offline')).toBeDefined();
      // Profile indicator must explicitly indicate Requested, not Applied
      expect(screen.getByText('Requested')).toBeDefined();
    });

    // Ensure it does not falsely claim to be [Applied]
    expect(screen.queryByText(/Applied/i)).toBeNull();
  });

  it('12. variant badges render truthfully for base, thinking, instruct, and custom variants without defaulting to instruct', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([
      {
        id: 'model-base',
        display_name: 'Llama-3-8B-Base',
        family: 'Llama',
        variant: 'base',
        primary_file: 'models/llama3-base.gguf',
        companion_files: [],
        capabilities: ['chat'],
        recommended_profiles: ['balanced'],
        estimated_vram_gb: 4.0,
        estimated_ram_gb: 2.0,
        quantization: 'Q4_K_M',
        parameters: '8B',
        context_limit: 4096,
        license: 'Meta',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: 4.2,
      },
      {
        id: 'model-code',
        display_name: 'DeepSeek-Coder-6.7B',
        family: 'DeepSeek',
        variant: 'code',
        primary_file: 'models/deepseek-code.gguf',
        companion_files: [],
        capabilities: ['chat'],
        recommended_profiles: ['balanced'],
        estimated_vram_gb: 3.8,
        estimated_ram_gb: 2.0,
        quantization: 'Q4_K_M',
        parameters: '6.7B',
        context_limit: 4096,
        license: 'DeepSeek',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: 3.8,
      },
    ]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    // Verify Base and Code badges are rendered truthfully
    await waitFor(() => {
      expect(screen.getAllByText('Base').length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText('Code').length).toBeGreaterThanOrEqual(1);
    });
  });

  it('13. missing mmproj companion shows degraded warning while model remains loadable for text', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ active_model: null, model_loaded: false }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([
      {
        id: 'qwen3-vl-degraded',
        display_name: 'Qwen3-VL-2B-Degraded',
        family: 'Qwen',
        variant: 'instruct',
        primary_file: 'models/qwen3-vl-2b-instruct.gguf',
        companion_files: [{ role: 'mmproj', path: 'models/mmproj-missing.gguf' }],
        capabilities: ['chat', 'vision'],
        recommended_profiles: ['balanced'],
        estimated_vram_gb: 2.1,
        estimated_ram_gb: 1.1,
        quantization: 'Q4_K_M',
        parameters: '2.4B',
        context_limit: 2048,
        license: 'Apache-2.0',
        source: 'local',
        validation_status: 'missing_companion',
        primary_file_exists: true,
        companion_files_valid: false,
        size_gb: 1.6,
      },
    ]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    // Degraded warning appears
    await waitFor(() => {
      expect(screen.getAllByText(/Vision companion missing \(Degraded\)/i).length).toBeGreaterThan(0);
    });

    // Model must NOT be marked incompatible; load button remains available
    const card = document.getElementById('model-card-qwen3-vl-degraded');
    expect(card).not.toBeNull();
    expect(card?.textContent).not.toContain('Incompatible');
    const loadBtn = document.getElementById('model-activate-btn-qwen3-vl-degraded');
    expect(loadBtn).not.toBeNull();
    expect(loadBtn).not.toBeDisabled();
  });

  it('14. requested profile != applied profile displays explicit Profile change pending restart warning', async () => {
    const restartPendingStatus = createMockStatus({
      requested_profile: 'maximum',
      applied_profile: 'balanced',
      applied_context_size: 4096,
      applied_gpu_layers: 28,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(restartPendingStatus);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Profile change pending restart').length).toBeGreaterThan(0);
    });
  });

  it('15. missing size_gb renders Unavailable instead of 0.00 GB and does not fabricate 28-layer or 4.5 GB fallbacks', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({
      active_model: 'model-no-size',
      applied_gpu_layers: null,
      applied_profile: 'balanced',
    }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([
      {
        id: 'model-no-size',
        display_name: 'No Size Model',
        family: 'Custom',
        variant: 'instruct',
        primary_file: 'models/custom.gguf',
        companion_files: [],
        capabilities: ['chat'],
        recommended_profiles: ['balanced'],
        estimated_vram_gb: 0,
        estimated_ram_gb: 0,
        quantization: 'Q4_0',
        parameters: '7B',
        context_limit: 2048,
        license: 'Custom',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: undefined as unknown as number,
      },
    ]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Unavailable').length).toBeGreaterThan(0);
    });

    // Verify 0.00 GB is NOT displayed
    expect(screen.queryByText(/0\.00 GB/i)).toBeNull();
  });

  it('16. selected model B never inherits active model A MODEL_READY or MODEL_SLEEPING badge in hero', async () => {
    // Model A is active and MODEL_READY
    const status = createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      runtime_state: 'MODEL_READY',
      model_loaded: true,
      model_awake: true,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    // Initial state: Hero shows active Model A
    await waitFor(() => {
      expect(screen.getAllByText('Qwen3-VL-4B-Instruct').length).toBeGreaterThanOrEqual(1);
    });

    // User selects Model B (2B Instruct)
    const card2b = document.getElementById('model-card-qwen3-vl-2b-instruct');
    expect(card2b).not.toBeNull();
    fireEvent.click(card2b!);

    // Hero now displays Model B
    await waitFor(() => {
      const hero = document.getElementById('current-model-hero-card');
      expect(hero).not.toBeNull();
      expect(hero?.textContent).toContain('Qwen3-VL-2B-Instruct');
      // Hero for Model B MUST render Selected / Not Active, NOT Loaded / Awake!
      expect(hero?.textContent).toContain('Selected / Not Active');
      expect(hero?.textContent).not.toContain('Loaded / Awake');
    });
  });

  it('17. context utilization is not fabricated and does not invent fake active token percentages', async () => {
    const status = createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      model_loaded: true,
      model_awake: true,
      applied_context_size: 4096,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(status);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      // Must state that live KV token usage is Unavailable
      expect(screen.getByText(/KV Cache: Unavailable/i)).toBeInTheDocument();
    });

    // Ensure fake active token count (3840) or fake percentage is NOT present
    expect(screen.queryByText(/3840/i)).toBeNull();
    expect(screen.queryByText(/% active/i)).toBeNull();
  });

  it('18. missing RAM estimate does not become 1.2 GB fallback', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({
      active_model: 'model-zero-ram',
      applied_profile: 'balanced',
    }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([
      {
        id: 'model-zero-ram',
        display_name: 'Zero RAM Model',
        family: 'Test',
        variant: 'instruct',
        primary_file: 'models/zero-ram.gguf',
        companion_files: [],
        capabilities: ['chat'],
        recommended_profiles: ['balanced'],
        estimated_vram_gb: 2.0,
        estimated_ram_gb: 0,
        quantization: 'Q4_K_M',
        parameters: '3B',
        context_limit: 2048,
        license: 'MIT',
        source: 'local',
        validation_status: 'verified',
        primary_file_exists: true,
        companion_files_valid: true,
        size_gb: 2.0,
      },
    ]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      const hero = document.getElementById('current-model-hero-card');
      expect(hero).not.toBeNull();
      // Estimated RAM must be Unavailable, not 1.2 GB
      expect(hero?.textContent).toContain('Unavailable');
      expect(hero?.textContent).not.toContain('1.2 GB');
    });
  });

  it('19. missing requested_mmproj_offload renders Unavailable without inferring from profile', async () => {
    const statusWithoutReqMmproj = createMockStatus({
      requested_mmproj_offload: undefined,
      applied_mmproj_offload: true,
      requested_profile: 'balanced',
      applied_profile: 'balanced',
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(statusWithoutReqMmproj);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      // Vision Projector (Req) must render Unavailable, NOT GPU [Configured] or CPU [Configured]
      expect(screen.getAllByText('Unavailable').length).toBeGreaterThan(0);
      expect(screen.queryByText('GPU [Configured]')).toBeNull();
      expect(screen.queryByText('CPU [Configured]')).toBeNull();
    });
  });

  it('20. ModelDetailsModal has no fabricated sampling presets, Open Source license, or GGUF v3 format', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Qwen3-VL-4B-Instruct').length).toBeGreaterThanOrEqual(1);
    });

    // Click Details button on Model 4B
    const detailsBtn = document.getElementById('model-details-btn-qwen3-vl-4b-instruct');
    expect(detailsBtn).not.toBeNull();
    fireEvent.click(detailsBtn!);

    // Modal opens
    await waitFor(() => {
      expect(screen.getByText('Sampling parameters: Not reported by registry')).toBeInTheDocument();
    });

    // Ensure fake defaults are NOT present
    expect(screen.queryByText('0.7')).toBeNull();
    expect(screen.queryByText('0.9')).toBeNull();
    expect(screen.queryByText('1.1')).toBeNull();
    expect(screen.queryByText('Repeat Penalty')).toBeNull();
    expect(screen.queryByText('Open Source')).toBeNull();
  });
});


