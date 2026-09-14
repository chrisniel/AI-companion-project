/**
 * Static presentation metadata and planned provider specifications for Health & Wellness.
 * Note: Wearable health telemetry synchronization is planned for a future Android Companion phase.
 * No real wearable health sync or database telemetry is currently implemented on the host runtime.
 */

import { HealthPipelineStage, HealthSourceProvider } from '../../../types';

export const PLANNED_HEALTH_PROVIDERS: HealthSourceProvider[] = [
  {
    id: 'health_connect_wearos',
    name: 'Android Health Connect (Planned)',
    deviceModel: 'Android Companion Bridge (Future Phase)',
    iconType: 'watch',
    description: 'Planned background batch synchronization via Android Health Connect',
    supportsSpO2: true,
    supportsSleepStages: true,
    supportsContinuousHR: true,
    status: 'disconnected',
    lastSyncTime: 'Unavailable (Planned)',
    sampleCount: 0,
  },
  {
    id: 'fitcloudpro',
    name: 'FitCloudPro / BLE (Planned)',
    deviceModel: 'Direct BLE GATT Bridge (Future Phase)',
    iconType: 'band',
    description: 'Planned optical photoplethysmography sensor sync via Bluetooth LE daemon',
    supportsSpO2: true,
    supportsSleepStages: false,
    supportsContinuousHR: true,
    status: 'disconnected',
    lastSyncTime: 'Unavailable (Planned)',
    sampleCount: 0,
  },
  {
    id: 'garmin',
    name: 'Garmin Connect (Planned)',
    deviceModel: 'Partner Health Sync (Future Phase)',
    iconType: 'watch',
    description: 'Planned Garmin Health sync via Android Health Connect integration',
    supportsSpO2: true,
    supportsSleepStages: true,
    supportsContinuousHR: true,
    status: 'disconnected',
    lastSyncTime: 'Unavailable (Planned)',
    sampleCount: 0,
  },
];

export function getPipelineStages(providerName: string): HealthPipelineStage[] {
  return [
    {
      step: 1,
      label: 'Wearable Sensor',
      detail: `${providerName}`,
      subtext: 'Hardware sensor capture (Planned)',
      status: 'pending',
    },
    {
      step: 2,
      label: 'Companion Bridge',
      detail: 'Android Health Connect / BLE',
      subtext: 'Local transport layer (Planned)',
      status: 'pending',
    },
    {
      step: 3,
      label: 'Local AI Runtime',
      detail: 'Host SQLite Health Store',
      subtext: 'Zero-cloud persistent storage (Planned)',
      status: 'pending',
    },
    {
      step: 4,
      label: 'Intelligence Engine',
      detail: 'Circadian Prompt Synthesis',
      subtext: 'Contextual prompt augmentation (Planned)',
      status: 'pending',
    },
  ];
}
