/**
 * Static presentation metadata and provider capability definitions for Health & Wellness.
 * Pure configuration; does not contain fabricated user vitals or runtime telemetry.
 */

import { HealthPipelineStage, HealthSourceProvider } from '../../../types';

export const SUPPORTED_HEALTH_PROVIDERS: HealthSourceProvider[] = [
  {
    id: 'fitcloudpro',
    name: 'FitCloudPro',
    deviceModel: 'Smart Wellness Band K22 (BLE)',
    iconType: 'band',
    description: 'Optical photoplethysmography sensor sync via Bluetooth LE daemon',
    supportsSpO2: true,
    supportsSleepStages: false,
    supportsContinuousHR: true,
    status: 'disconnected',
    lastSyncTime: 'Never',
    sampleCount: 0,
  },
  {
    id: 'health_connect_wearos',
    name: 'Wear OS / Pixel Watch',
    deviceModel: 'Pixel Watch 2',
    iconType: 'watch',
    description: 'Native Android Health Connect provider with background batching',
    supportsSpO2: true,
    supportsSleepStages: true,
    supportsContinuousHR: true,
    status: 'disconnected',
    lastSyncTime: 'Never',
    sampleCount: 0,
  },
  {
    id: 'garmin',
    name: 'Garmin Connect',
    deviceModel: 'Forerunner 265',
    iconType: 'watch',
    description: 'Garmin Health API sync via Android Health Connect bridge',
    supportsSpO2: true,
    supportsSleepStages: true,
    supportsContinuousHR: true,
    status: 'disconnected',
    lastSyncTime: 'Never',
    sampleCount: 0,
  },
];

export function getPipelineStages(providerName: string): HealthPipelineStage[] {
  return [
    {
      step: 1,
      label: 'Wearable Sensor',
      detail: `${providerName} PPG/Accelerometer`,
      subtext: 'Continuous on-wrist telemetry capture',
      status: 'pending',
    },
    {
      step: 2,
      label: 'Companion Bridge',
      detail: 'Android Health Connect / BLE',
      subtext: 'Encrypted device synchronization',
      status: 'pending',
    },
    {
      step: 3,
      label: 'Local AI Runtime',
      detail: 'Local SQLite Health Store',
      subtext: 'Zero-cloud persistent circadian index',
      status: 'pending',
    },
    {
      step: 4,
      label: 'Intelligence Engine',
      detail: 'Circadian Context Synthesis',
      subtext: 'Contextual prompt augmentation for assistant',
      status: 'pending',
    },
  ];
}
