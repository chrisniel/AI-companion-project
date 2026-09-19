import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { ModelsView } from '../components/workspace/ModelsView';
import { Header } from '../components/layout/Header';
import { CurrentModelHero } from '../components/workspace/models/CurrentModelHero';
import { ModelDetailsModal } from '../components/workspace/models/ModelDetailsModal';
import { LocalModel } from '../types';
import { BackendProvider, useBackend } from '../context/BackendContext';
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
        manifest: {
          id: 'qwen3-vl-2b-instruct',
          display_name: 'Qwen3-VL-2B-Instruct',
          asset_type: 'gguf',
          family: 'Qwen',
          architecture: 'qwen3vl',
          variant: 'instruct',
          primary_file: 'models/qwen3-vl-2b-instruct.gguf',
          companion_files: [{ role: 'mmproj', path: 'models/mmproj-qwen3-vl-2b-instruct.gguf' }],
          capabilities: ['chat', 'vision'],
          input_modalities: ['text', 'image'],
          model_max_context: 2048,
          runtime_compatibility: ['llama.cpp'],
          quantization: 'Q4_K_M',
          parameters: '2.4B',
          license: 'Apache-2.0',
          source: 'local',
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: 1.6,
          companion_artifact_statuses: [
            { artifact: { role: 'mmproj', path: 'models/mmproj-qwen3-vl-2b-instruct.gguf' }, exists: true },
          ],
          available_capabilities: ['chat', 'vision'],
        },
        hints: {
          recommended_profiles: ['eco', 'balanced'],
          estimated_vram_gb: 2.1,
          estimated_ram_gb: 1.1,
        },
        runtime_model_id: 'qwen3-vl-2b-instruct',
        registry_source: 'factory',
      },
      {
        manifest: {
          id: 'qwen3-vl-4b-instruct',
          display_name: 'Qwen3-VL-4B-Instruct',
          asset_type: 'gguf',
          family: 'Qwen',
          architecture: 'qwen3vl',
          variant: 'instruct',
          primary_file: 'models/qwen3-vl-4b-instruct.gguf',
          companion_files: [{ role: 'mmproj', path: 'models/mmproj-qwen3-vl-4b-instruct.gguf' }],
          capabilities: ['chat', 'vision'],
          input_modalities: ['text', 'image'],
          model_max_context: 4096,
          runtime_compatibility: ['llama.cpp'],
          quantization: 'Q4_K_M',
          parameters: '4.4B',
          license: 'Apache-2.0',
          source: 'local',
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: 2.8,
          companion_artifact_statuses: [
            { artifact: { role: 'mmproj', path: 'models/mmproj-qwen3-vl-4b-instruct.gguf' }, exists: true },
          ],
          available_capabilities: ['chat', 'vision'],
        },
        hints: {
          recommended_profiles: ['balanced', 'maximum'],
          estimated_vram_gb: 4.2,
          estimated_ram_gb: 1.5,
        },
        runtime_model_id: 'qwen3-vl-4b-instruct',
        registry_source: 'factory',
      },
      {
        manifest: {
          id: 'qwen3-vl-2b-thinking',
          display_name: 'Qwen3-VL-2B-Thinking',
          asset_type: 'gguf',
          family: 'Qwen',
          architecture: 'qwen3vl',
          variant: 'thinking',
          primary_file: 'models/qwen3-vl-2b-thinking.gguf',
          companion_files: [],
          capabilities: ['chat', 'reasoning'],
          input_modalities: ['text'],
          model_max_context: 2048,
          runtime_compatibility: ['llama.cpp'],
          quantization: 'Q4_K_M',
          parameters: '2.4B',
          license: 'Apache-2.0',
          source: 'local',
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: 1.7,
          companion_artifact_statuses: [],
          available_capabilities: ['chat', 'reasoning'],
        },
        hints: {
          recommended_profiles: ['eco', 'balanced'],
          estimated_vram_gb: 2.3,
          estimated_ram_gb: 1.2,
        },
        runtime_model_id: 'qwen3-vl-2b-thinking',
        registry_source: 'factory',
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
      expect(document.getElementById('model-card-qwen3-vl-2b-instruct')?.textContent).toContain('Selected');
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
      expect(screen.getAllByText(/Qwen3-VL.*2B.*Instruct/i).length).toBeGreaterThanOrEqual(1);
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

  it('11. When Runtime is offline, Header selector shows Runtime Offline and Profile indicates Requested only', async () => {
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
      // Model button should display Runtime Offline
      expect(screen.getByText('Runtime Offline')).toBeDefined();
      // Profile indicator must indicate Unavailable when Runtime is offline
      expect(screen.getAllByText('Unavailable').length).toBeGreaterThanOrEqual(1);
    });

    // Ensure it does not falsely claim to be [Applied]
    expect(screen.queryByText(/Applied/i)).toBeNull();
  });

  it('12. variant badges render truthfully for base, thinking, instruct, and custom variants without defaulting to instruct', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([
      {
        manifest: {
          id: 'model-base',
          display_name: 'Llama-3-8B-Base',
          asset_type: 'gguf',
          family: 'Llama',
          architecture: 'llama',
          variant: 'base',
          parameters: '8B',
          quantization: 'Q4_K_M',
          reasoning_mode: 'unsupported',
          capabilities: ['chat'],
          input_modalities: ['text'],
          model_max_context: 4096,
          runtime_compatibility: ['llama.cpp'],
          primary_file: 'models/llama3-base.gguf',
          companion_files: [],
          chat_template: null,
          license: 'Meta',
          source: 'local',
          sha256_primary: null,
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: 4.2,
          companion_artifact_statuses: [],
          available_capabilities: ['chat'],
          capability_provenance: [{ capability: 'chat', supported: true, provenance: 'declared' }],
        },
        hints: {
          recommended_profiles: ['balanced'],
          estimated_vram_gb: 4.0,
          estimated_ram_gb: 2.0,
          generation_defaults: null,
        },
        runtime_model_id: 'model-base',
        registry_source: 'installed',
      },
      {
        manifest: {
          id: 'model-code',
          display_name: 'DeepSeek-Coder-6.7B',
          asset_type: 'gguf',
          family: 'DeepSeek',
          architecture: 'deepseek2',
          variant: 'code',
          parameters: '6.7B',
          quantization: 'Q4_K_M',
          reasoning_mode: 'unsupported',
          capabilities: ['chat'],
          input_modalities: ['text'],
          model_max_context: 4096,
          runtime_compatibility: ['llama.cpp'],
          primary_file: 'models/deepseek-code.gguf',
          companion_files: [],
          chat_template: null,
          license: 'DeepSeek',
          source: 'local',
          sha256_primary: null,
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: 3.8,
          companion_artifact_statuses: [],
          available_capabilities: ['chat'],
          capability_provenance: [{ capability: 'chat', supported: true, provenance: 'declared' }],
        },
        hints: {
          recommended_profiles: ['balanced'],
          estimated_vram_gb: 3.8,
          estimated_ram_gb: 2.0,
          generation_defaults: null,
        },
        runtime_model_id: 'model-code',
        registry_source: 'installed',
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
        manifest: {
          id: 'qwen3-vl-degraded',
          display_name: 'Qwen3-VL-2B-Degraded',
          asset_type: 'gguf',
          family: 'Qwen',
          architecture: 'qwen2',
          variant: 'instruct',
          parameters: '2.4B',
          quantization: 'Q4_K_M',
          reasoning_mode: 'unsupported',
          capabilities: ['chat', 'vision'],
          input_modalities: ['text', 'image'],
          model_max_context: 2048,
          runtime_compatibility: ['llama.cpp'],
          primary_file: 'models/qwen3-vl-2b-instruct.gguf',
          companion_files: [{ role: 'mmproj', path: 'models/mmproj-missing.gguf', sha256: null }],
          chat_template: null,
          license: 'Apache-2.0',
          source: 'local',
          sha256_primary: null,
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'missing_companion',
          primary_file_exists: true,
          size_gb: 1.6,
          companion_artifact_statuses: [
            {
              artifact: { role: 'mmproj', path: 'models/mmproj-missing.gguf', sha256: null },
              exists: false,
            },
          ],
          available_capabilities: ['chat'],
          capability_provenance: [
            { capability: 'chat', supported: true, provenance: 'declared' },
            { capability: 'vision', supported: false, provenance: 'declared' },
          ],
        },
        hints: {
          recommended_profiles: ['balanced'],
          estimated_vram_gb: 2.1,
          estimated_ram_gb: 1.1,
          generation_defaults: null,
        },
        runtime_model_id: 'qwen3-vl-degraded',
        registry_source: 'installed',
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
    // UI must not treat vision as currently available (only degraded warning is shown, not available vision badge)
    expect(card?.textContent).not.toMatch(/\bVision\b(?! companion)/);
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
        manifest: {
          id: 'model-no-size',
          display_name: 'No Size Model',
          asset_type: 'gguf',
          family: 'Custom',
          architecture: 'custom',
          variant: 'instruct',
          parameters: '7B',
          quantization: 'Q4_0',
          reasoning_mode: 'unsupported',
          capabilities: ['chat'],
          input_modalities: ['text'],
          model_max_context: 2048,
          runtime_compatibility: ['llama.cpp'],
          primary_file: 'models/custom.gguf',
          companion_files: [],
          chat_template: null,
          license: 'Custom',
          source: 'local',
          sha256_primary: null,
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: null,
          companion_artifact_statuses: [],
          available_capabilities: ['chat'],
          capability_provenance: [{ capability: 'chat', supported: true, provenance: 'declared' }],
        },
        hints: {
          recommended_profiles: ['balanced'],
          estimated_vram_gb: 0,
          estimated_ram_gb: 0,
          generation_defaults: null,
        },
        runtime_model_id: 'model-no-size',
        registry_source: 'installed',
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
        manifest: {
          id: 'model-zero-ram',
          display_name: 'Zero RAM Model',
          asset_type: 'gguf',
          family: 'Test',
          architecture: 'test',
          variant: 'instruct',
          parameters: '3B',
          quantization: 'Q4_K_M',
          reasoning_mode: 'unsupported',
          capabilities: ['chat'],
          input_modalities: ['text'],
          model_max_context: 2048,
          runtime_compatibility: ['llama.cpp'],
          primary_file: 'models/zero-ram.gguf',
          companion_files: [],
          chat_template: null,
          license: 'MIT',
          source: 'local',
          sha256_primary: null,
        },
        library_state: {
          discovery_state: 'verified',
          validation_status: 'verified',
          primary_file_exists: true,
          size_gb: 2.0,
          companion_artifact_statuses: [],
          available_capabilities: ['chat'],
          capability_provenance: [{ capability: 'chat', supported: true, provenance: 'declared' }],
        },
        hints: {
          recommended_profiles: ['balanced'],
          estimated_vram_gb: 2.0,
          estimated_ram_gb: 0,
          generation_defaults: null,
        },
        runtime_model_id: 'model-zero-ram',
        registry_source: 'installed',
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

  it('21. registry VRAM estimate is never labeled live or allocated usage and VramTargetSlider has no default 4.9 GB', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
    }));

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      // Must say VRAM Planning Breakdown, not Allocated VRAM Breakdown
      expect(screen.getByText('VRAM Planning Breakdown')).toBeInTheDocument();
    });

    // Ensure "Allocated VRAM Breakdown" is NOT in the document
    expect(screen.queryByText('Allocated VRAM Breakdown')).toBeNull();
    // Ensure "Free for Windows / Display" is NOT in the document
    expect(screen.queryByText(/Free for Windows \/ Display/i)).toBeNull();
    // Ensure default 4.9 GB is NOT present
    expect(screen.queryByText(/4\.9 GB/i)).toBeNull();
  });

  it('22. absent applied_context_size never causes configured context to display [Applied]', async () => {
    // Model is loaded, but backend reports applied_context_size as null/undefined
    const statusNoAppliedContext = createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      model_loaded: true,
      model_awake: true,
      applied_context_size: null,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(statusNoAppliedContext);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      // Must display [Configured], NOT [Applied]
      expect(screen.getByText('4,096 tokens [Configured]')).toBeInTheDocument();
    });

    expect(screen.queryByText(/4,096 tokens \[Applied\]/i)).toBeNull();
  });

  it('23. router_running alone never produces Vulkan Offload [Applied]', async () => {
    // router_running is true, but applied_gpu_layers is null
    const statusNoGpuLayers = createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
      router_running: true,
      applied_gpu_layers: null,
    });
    vi.mocked(api.getModelStatus).mockResolvedValue(statusNoGpuLayers);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      // Must say GPU Offload: Unavailable
      expect(screen.getByText('GPU Offload: Unavailable')).toBeInTheDocument();
    });

    // Must NOT claim Vulkan Offload (Core) [Applied]
    expect(screen.queryByText(/Vulkan Offload.*\[Applied\]/i)).toBeNull();
  });

  it('24. no instruction-model fallback description is fabricated when description is absent', async () => {
    const dummyModel: LocalModel = {
      id: 'model-no-desc',
      name: 'No Desc Model',
      family: 'Mystery',
      parameters: '1B',
      quantization: 'Q4_0',
      contextWindow: 2048,
      status: 'unloaded',
      engine: 'llama.cpp',
      description: '',
    };

    const { rerender } = render(
      <CurrentModelHero
        model={dummyModel}
        activeModelId={null}
      />
    );

    // CurrentModelHero must render 'Description unavailable' and NOT 'General instruction model'
    expect(screen.getByText(/Description unavailable/i)).toBeInTheDocument();
    expect(screen.queryByText(/General instruction model/i)).toBeNull();

    rerender(
      <ModelDetailsModal
        model={dummyModel}
        isOpen={true}
        onClose={vi.fn()}
        isActive={false}
        onActivate={vi.fn()}
      />
    );

    // ModelDetailsModal must render 'Description unavailable' and NOT 'Instruction-tuned transformer model'
    expect(screen.getAllByText(/Description unavailable/i).length).toBeGreaterThan(0);
    expect(screen.queryByText(/Instruction-tuned transformer model/i)).toBeNull();
  });

  it('25. ModelsView does not render fake providers, cloud routing, or mock models', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({
      active_model: 'qwen3-vl-4b-instruct',
    }));

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('Model Library')).toBeInTheDocument();
    });

    // Ensure ModelProvidersCard / mockModelProviders are NOT rendered
    expect(screen.queryByText(/Ollama/i)).toBeNull();
    expect(screen.queryByText(/Gemini API/i)).toBeNull();
    expect(screen.queryByText(/DeepSeek-R1-Distill-Qwen-8B/i)).toBeNull();

    // Ensure fake ProviderRoutingCard controls are NOT rendered
    expect(screen.queryByText(/Local First/i)).toBeNull();
    expect(screen.queryByText(/Cloud Fallback/i)).toBeNull();
    expect(screen.queryByText(/Ask before cloud use/i)).toBeNull();

    // Ensure fake AdvancedRuntimeSettings are NOT rendered
    expect(screen.queryByText(/Technical Runtime Architecture/i)).toBeNull();
    expect(screen.queryByText(/KV Cache Quantization/i)).toBeNull();
  });

  it('26. unregistered model with unknown metadata does not fabricate 4096 context, chat, vision, llama.cpp, or instruct', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ active_model: 'unknown-model', model_loaded: true }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([
      {
        manifest: {
          id: 'unknown-model',
          display_name: 'Mysterious Model',
          asset_type: 'gguf',
          family: 'UnknownFamily',
          architecture: 'unknown',
          variant: 'unknown',
          parameters: 'Unknown',
          quantization: 'Unknown',
          reasoning_mode: 'unknown',
          capabilities: [],
          input_modalities: [],
          model_max_context: null,
          runtime_compatibility: [],
          primary_file: 'models/unknown.gguf',
          companion_files: [],
          chat_template: null,
          license: 'Unknown',
          source: 'local',
          sha256_primary: null,
        },
        library_state: {
          discovery_state: 'discovered',
          validation_status: 'unregistered',
          primary_file_exists: true,
          size_gb: 1.0,
          companion_artifact_statuses: [],
          available_capabilities: [],
          capability_provenance: [],
        },
        hints: {
          recommended_profiles: [],
          estimated_vram_gb: null,
          estimated_ram_gb: null,
          generation_defaults: null,
        },
        runtime_model_id: 'unknown-model',
        registry_source: 'installed',
      },
    ]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Mysterious Model').length).toBeGreaterThanOrEqual(1);
    });

    const card = document.getElementById('model-card-unknown-model');
    expect(card).not.toBeNull();
    // Verify no fabricated 'Instruct' badge
    expect(card?.textContent).not.toContain('Instruct');
    // Verify no fabricated 'Chat' or 'Vision' badge
    expect(card?.textContent).not.toContain('Vision');
    expect(card?.textContent).not.toContain('Chat');
    // Context length must NOT fabricate 4096 or 4K
    expect(card?.textContent).not.toContain('4096');
    expect(card?.textContent).not.toContain('4k');
    // Runtime compatibility must not fabricate llama.cpp
    expect(card?.textContent).not.toContain('llama.cpp');
  });

  it('27. fresh application state before registry response has no hardcoded registry models', async () => {
    let resolveRegistry!: (value: api.RegistryEntry[]) => void;
    const pendingRegistryPromise = new Promise<api.RegistryEntry[]>((resolve) => {
      resolveRegistry = resolve;
    });
    vi.mocked(api.fetchModelRegistry).mockReturnValueOnce(pendingRegistryPromise);

    const RegistryWatcher = () => {
      const { registry } = useBackend();
      return (
        <div>
          <span data-testid="registry-count">{registry.length}</span>
          <ModelsView />
        </div>
      );
    };

    render(
      <BackendProvider>
        <RegistryWatcher />
      </BackendProvider>
    );

    // Initial state before registry API returns must be 0 entries, not hardcoded defaults
    expect(screen.getByTestId('registry-count').textContent).toBe('0');
    expect(screen.getByText('0 Models Available')).toBeInTheDocument();
    expect(screen.getByText('No Models Discovered')).toBeInTheDocument();
    expect(document.getElementById('model-card-qwen3-vl-2b-instruct')).toBeNull();

    // Clean up pending promise
    await act(async () => {
      resolveRegistry([]);
    });
  });

  it('28. backend unavailable on fresh startup: registry remains empty', async () => {
    vi.mocked(api.checkHealth).mockRejectedValue(new Error('Connection refused'));
    vi.mocked(api.getModelStatus).mockRejectedValue(new Error('Connection refused'));
    vi.mocked(api.fetchModelRegistry).mockRejectedValue(new Error('Connection refused'));

    const RegistryWatcher = () => {
      const { registry, isOnline } = useBackend();
      return (
        <div>
          <span data-testid="online-state">{isOnline ? 'online' : 'offline'}</span>
          <span data-testid="registry-count">{registry.length}</span>
          <ModelsView />
        </div>
      );
    };

    render(
      <BackendProvider>
        <RegistryWatcher />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByTestId('online-state').textContent).toBe('offline');
    });

    expect(screen.getByTestId('registry-count').textContent).toBe('0');
    expect(screen.getByText(/Local AI Runtime is offline/i)).toBeInTheDocument();
    expect(screen.getByText('0 Models Available')).toBeInTheDocument();
    expect(document.getElementById('model-card-qwen3-vl-2b-instruct')).toBeNull();
  });

  it('29. registry fetch failure: no DEFAULT_INSTALLED_REGISTRY models appear', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ model_loaded: false, active_model: null }));
    vi.mocked(api.fetchModelRegistry).mockRejectedValueOnce(new Error('500 Internal Server Error'));

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('No Models Discovered')).toBeInTheDocument();
    });

    expect(screen.getByText('0 Models Available')).toBeInTheDocument();
    expect(document.getElementById('model-card-qwen3-vl-2b-instruct')).toBeNull();
    expect(document.getElementById('model-card-qwen3-vl-4b-instruct')).toBeNull();
    expect(document.getElementById('model-card-qwen3-vl-2b-thinking')).toBeNull();
    expect(document.getElementById('model-card-qwen3-vl-4b-thinking')).toBeNull();
  });

  it('30. successful registry response: returned backend models display normally', async () => {
    const backendModel: api.RegistryEntry = {
      manifest: {
        id: 'custom-backend-model',
        display_name: 'Custom Backend Model',
        asset_type: 'gguf',
        family: 'CustomFamily',
        architecture: 'qwen3vl',
        variant: 'instruct',
        parameters: '3.0B',
        quantization: 'Q4_K_M',
        reasoning_mode: 'unsupported',
        capabilities: ['chat'],
        input_modalities: ['text'],
        model_max_context: 4096,
        runtime_compatibility: ['llama.cpp'],
        primary_file: 'models/custom.gguf',
        companion_files: [],
        license: 'MIT',
        source: 'local',
      },
      library_state: {
        discovery_state: 'verified',
        validation_status: 'verified',
        primary_file_exists: true,
        size_gb: 2.0,
        companion_artifact_statuses: [],
        available_capabilities: ['chat'],
      },
      hints: {
        recommended_profiles: ['balanced'],
        estimated_vram_gb: 2.5,
        estimated_ram_gb: 0.8,
      },
      runtime_model_id: 'custom-backend-model',
      registry_source: 'installed',
    };

    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ model_loaded: false, active_model: null }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([backendModel]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Custom Backend Model').length).toBeGreaterThanOrEqual(1);
    });

    expect(screen.getByText('1 Model Available')).toBeInTheDocument();
    expect(document.getElementById('model-card-custom-backend-model')).not.toBeNull();
  });

  it('31. successful empty registry: frontend reflects no models rather than preserving old bootstrap defaults', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ model_loaded: false, active_model: null }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([]);

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('No Models Discovered')).toBeInTheDocument();
    });

    expect(screen.getByText('0 Models Available')).toBeInTheDocument();
    expect(document.getElementById('model-card-qwen3-vl-2b-instruct')).toBeNull();
    expect(document.getElementById('model-card-qwen3-vl-4b-instruct')).toBeNull();
  });

  it('32. transient registry fetch failure AFTER a successful fetch does not replace last-known data with fabricated defaults', async () => {
    const initialModel: api.RegistryEntry = {
      manifest: {
        id: 'initial-verified-model',
        display_name: 'Initial Verified Model',
        asset_type: 'gguf',
        family: 'InitialFamily',
        architecture: 'qwen3vl',
        variant: 'instruct',
        parameters: '1.5B',
        quantization: 'Q4_K_M',
        reasoning_mode: 'unsupported',
        capabilities: ['chat'],
        input_modalities: ['text'],
        model_max_context: 4096,
        runtime_compatibility: ['llama.cpp'],
        primary_file: 'models/initial.gguf',
        companion_files: [],
        license: 'MIT',
        source: 'local',
      },
      library_state: {
        discovery_state: 'verified',
        validation_status: 'verified',
        primary_file_exists: true,
        size_gb: 1.2,
        companion_artifact_statuses: [],
        available_capabilities: ['chat'],
      },
      hints: {
        recommended_profiles: ['eco'],
        estimated_vram_gb: 1.5,
        estimated_ram_gb: 0.5,
      },
      runtime_model_id: 'initial-verified-model',
      registry_source: 'installed',
    };

    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ model_loaded: false, active_model: null }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([initialModel]);

    const TriggerComponent = () => {
      const { refreshRegistry, registry } = useBackend();
      return (
        <div>
          <button type="button" onClick={() => refreshRegistry()} data-testid="trigger-refresh">
            Refresh
          </button>
          <span data-testid="model-count">{registry.length}</span>
          <ModelsView />
        </div>
      );
    };

    render(
      <BackendProvider>
        <TriggerComponent />
      </BackendProvider>
    );

    // Initial fetch succeeds
    await waitFor(() => {
      expect(screen.getAllByText('Initial Verified Model').length).toBeGreaterThanOrEqual(1);
    });
    expect(screen.getByTestId('model-count').textContent).toBe('1');

    // Next fetch fails
    vi.mocked(api.fetchModelRegistry).mockRejectedValueOnce(new Error('Network timeout'));

    await act(async () => {
      fireEvent.click(screen.getByTestId('trigger-refresh'));
    });

    // Last-known data must be preserved, not wiped or replaced by fabricated defaults
    expect(screen.getByTestId('model-count').textContent).toBe('1');
    expect(screen.getAllByText('Initial Verified Model').length).toBeGreaterThanOrEqual(1);
    expect(document.getElementById('model-card-qwen3-vl-2b-instruct')).toBeNull();
  });

  it('33. offline ModelsView does not present hardcoded models as verified/installed', async () => {
    vi.mocked(api.checkHealth).mockRejectedValue(new Error('Offline'));
    vi.mocked(api.getModelStatus).mockRejectedValue(new Error('Offline'));
    vi.mocked(api.fetchModelRegistry).mockRejectedValue(new Error('Offline'));

    render(
      <BackendProvider>
        <ModelsView />
      </BackendProvider>
    );

    await waitFor(() => {
      expect(screen.getByText(/Local AI Runtime is offline/i)).toBeInTheDocument();
    });

    // Verify 0 models available and no verified badges from fabricated installed registry
    expect(screen.getByText('0 Models Available')).toBeInTheDocument();
    expect(screen.queryByText(/Verified/i)).toBeNull();
    expect(screen.queryByText('Qwen3-VL 2B Instruct')).toBeNull();
  });

  it('34. Header does not populate model choices from fabricated local defaults when registry is empty', async () => {
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus({ model_loaded: false, active_model: null }));
    vi.mocked(api.fetchModelRegistry).mockResolvedValueOnce([]);

    render(
      <ThemeProvider>
        <BackendProvider>
          <Header
            sidebarCollapsed={false}
            onToggleSidebarCollapse={() => {}}
            assistantPanelMode="expanded"
            onCycleAssistantPanelMode={() => {}}
          />
        </BackendProvider>
      </ThemeProvider>
    );

    await waitFor(() => {
      expect(screen.getByText('No Model Loaded')).toBeInTheDocument();
    });

    // Header model dropdown must have no fabricated choices
    expect(screen.queryByText('Qwen3-VL 2B Instruct')).toBeNull();
    expect(screen.queryByText('Qwen3-VL 4B Instruct')).toBeNull();
    expect(screen.queryByText('Qwen3-VL 2B Thinking')).toBeNull();
  });
});
