/**
 * Model Registry API — fetches the live model list from the backend.
 * Master Plan §16.2 — ModelRegistry
 */
import { apiFetch, getApiKey } from './client';

export type ModelVariant = 'instruct' | 'thinking' | 'base' | string;
export type ModelCapability =
  | 'chat'
  | 'vision'
  | 'reasoning'
  | 'structured_output'
  | 'tool_calling'
  | 'multilingual';
export type ValidationStatus =
  | 'verified'
  | 'missing_primary'
  | 'missing_companion'
  | 'unregistered';

export interface CompanionFile {
  role: string;
  path: string;
}

export interface RegistryEntry {
  id: string;
  display_name: string;
  family: string;
  variant: ModelVariant;
  primary_file: string;
  companion_files: CompanionFile[];
  capabilities: ModelCapability[];
  recommended_profiles: string[];
  estimated_vram_gb: number;
  estimated_ram_gb: number;
  quantization: string;
  parameters: string;
  context_limit: number;
  license: string;
  source: string;
  validation_status: ValidationStatus;
  primary_file_exists: boolean;
  companion_files_valid: boolean;
  size_gb: number | null;
}

export const DEFAULT_INSTALLED_REGISTRY: RegistryEntry[] = [
  {
    id: 'qwen3-vl-2b-instruct',
    display_name: 'Qwen3-VL 2B Instruct',
    family: 'Qwen3-VL',
    variant: 'instruct',
    primary_file: 'vision/qwen3-vl-2b-instruct/Qwen_Qwen3-VL-2B-Instruct-Q4_K_M.gguf',
    companion_files: [
      { role: 'mmproj', path: 'vision/qwen3-vl-2b-instruct/mmproj-Qwen_Qwen3-VL-2B-Instruct-f16.gguf' },
    ],
    quantization: 'Q4_K_M',
    parameters: '2.0B',
    context_limit: 32768,
    capabilities: ['chat', 'vision', 'multilingual'],
    recommended_profiles: ['eco', 'balanced'],
    estimated_vram_gb: 2.4,
    estimated_ram_gb: 0.6,
    license: 'Apache-2.0',
    source: 'local',
    validation_status: 'verified',
    primary_file_exists: true,
    companion_files_valid: true,
    size_gb: 1.6,
  },
  {
    id: 'qwen3-vl-2b-thinking',
    display_name: 'Qwen3-VL 2B Thinking',
    family: 'Qwen3-VL',
    variant: 'thinking',
    primary_file: 'vision/qwen3-vl-2b-thinking/Qwen_Qwen3-VL-2B-Thinking-Q4_K_M.gguf',
    companion_files: [
      { role: 'mmproj', path: 'vision/qwen3-vl-2b-thinking/mmproj-Qwen_Qwen3-VL-2B-Thinking-f16.gguf' },
    ],
    quantization: 'Q4_K_M',
    parameters: '2.0B',
    context_limit: 32768,
    capabilities: ['chat', 'vision', 'reasoning', 'multilingual'],
    recommended_profiles: ['balanced', 'maximum'],
    estimated_vram_gb: 2.4,
    estimated_ram_gb: 0.6,
    license: 'Apache-2.0',
    source: 'local',
    validation_status: 'verified',
    primary_file_exists: true,
    companion_files_valid: true,
    size_gb: 1.6,
  },
  {
    id: 'qwen3-vl-4b-instruct',
    display_name: 'Qwen3-VL 4B Instruct',
    family: 'Qwen3-VL',
    variant: 'instruct',
    primary_file: 'vision/qwen3-vl-4b-instruct/Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf',
    companion_files: [
      { role: 'mmproj', path: 'vision/qwen3-vl-4b-instruct/mmproj-Qwen_Qwen3-VL-4B-Instruct-f16.gguf' },
    ],
    quantization: 'Q4_K_M',
    parameters: '4.0B',
    context_limit: 32768,
    capabilities: ['chat', 'vision', 'multilingual'],
    recommended_profiles: ['balanced', 'maximum'],
    estimated_vram_gb: 3.8,
    estimated_ram_gb: 0.8,
    license: 'Apache-2.0',
    source: 'local',
    validation_status: 'verified',
    primary_file_exists: true,
    companion_files_valid: true,
    size_gb: 2.8,
  },
  {
    id: 'qwen3-vl-4b-thinking',
    display_name: 'Qwen3-VL 4B Thinking',
    family: 'Qwen3-VL',
    variant: 'thinking',
    primary_file: 'vision/qwen3-vl-4b-thinking/Qwen_Qwen3-VL-4B-Thinking-Q4_K_M.gguf',
    companion_files: [
      { role: 'mmproj', path: 'vision/qwen3-vl-4b-thinking/mmproj-Qwen_Qwen3-VL-4B-Thinking-f16.gguf' },
    ],
    quantization: 'Q4_K_M',
    parameters: '4.0B',
    context_limit: 32768,
    capabilities: ['chat', 'vision', 'reasoning', 'multilingual'],
    recommended_profiles: ['balanced', 'maximum'],
    estimated_vram_gb: 3.8,
    estimated_ram_gb: 0.8,
    license: 'Apache-2.0',
    source: 'local',
    validation_status: 'verified',
    primary_file_exists: true,
    companion_files_valid: true,
    size_gb: 2.8,
  },
];

export async function fetchModelRegistry(apiKey?: string | null): Promise<RegistryEntry[]> {
  const key = apiKey || getApiKey();
  if (!key) return [];
  try {
    return await apiFetch<RegistryEntry[]>('/api/v1/models/registry');
  } catch {
    return [];
  }
}

