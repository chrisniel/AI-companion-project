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

export async function fetchModelRegistry(apiKey?: string | null): Promise<RegistryEntry[]> {
  const key = apiKey || getApiKey();
  if (!key) return [];
  try {
    return await apiFetch<RegistryEntry[]>('/api/v1/models/registry');
  } catch {
    return [];
  }
}
