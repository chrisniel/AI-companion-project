/**
 * Health and system connectivity API services.
 */

import { apiFetch } from './client';

export interface HealthCheckResponse {
  status: string;
}

export interface SystemStatusResponse {
  status: string;
  platform: string;
  python_version: string;
  hostname: string;
  cpu_count: number;
  version: string;
  database_connected: boolean;
  timestamp: string;
}

export async function checkHealth(): Promise<HealthCheckResponse> {
  return apiFetch<HealthCheckResponse>('/api/v1/health');
}

export async function getSystemStatus(): Promise<SystemStatusResponse> {
  return apiFetch<SystemStatusResponse>('/api/v1/system/status');
}
