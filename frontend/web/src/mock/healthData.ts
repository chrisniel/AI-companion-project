import {
  ActivityMetric,
  BloodOxygenMetric,
  HealthInsight,
  HealthPipelineStage,
  HealthSourceProvider,
  HeartRateMetric,
  SleepMetric,
} from '../types';

export const mockHealthProviders: HealthSourceProvider[] = [
  {
    id: 'fitcloudpro',
    name: 'FitCloudPro',
    deviceModel: 'Smart Wellness Band K22 (BLE)',
    iconType: 'band',
    description: 'Optical photoplethysmography sensor sync via Bluetooth LE daemon',
    supportsSpO2: true,
    supportsSleepStages: false, // FitCloudPro provides duration only, not REM/EEG stages
    supportsContinuousHR: true,
    status: 'connected',
    lastSyncTime: '4 minutes ago',
    sampleCount: 3410,
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
    status: 'idle',
    lastSyncTime: '2 hours ago',
    sampleCount: 5200,
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
    status: 'idle',
    lastSyncTime: 'Yesterday, 22:45',
    sampleCount: 8900,
  },
  {
    id: 'oura',
    name: 'Oura Ring Gen 3',
    deviceModel: 'Heritage Silver',
    iconType: 'ring',
    description: 'Circadian and nocturnal biometric sync via Health Connect export',
    supportsSpO2: true,
    supportsSleepStages: true,
    supportsContinuousHR: false,
    status: 'idle',
    lastSyncTime: 'Today, 07:30',
    sampleCount: 1840,
  },
];

export function getPipelineStages(providerName: string): HealthPipelineStage[] {
  return [
    {
      step: 1,
      label: providerName,
      detail: 'Raw Sensor Telemetry',
      subtext: 'BLE optical sample stream',
      status: 'active',
    },
    {
      step: 2,
      label: 'Health Connect',
      detail: 'Android Hub API v1.2',
      subtext: 'Unified permission sandbox',
      status: 'synced',
    },
    {
      step: 3,
      label: 'Mobile App',
      detail: 'Local AI Companion',
      subtext: 'Background SQLite cache',
      status: 'synced',
    },
    {
      step: 4,
      label: 'Local AI Core',
      detail: 'Workstation Vault',
      subtext: 'Encrypted LAN sync (offline)',
      status: 'synced',
    },
  ];
}

// Today mock metrics
export const mockHeartRateToday: HeartRateMetric = {
  currentBpm: 72,
  restingAvgBpm: 61,
  minBpm: 54,
  maxBpm: 118,
  timestamp: 'Just now (4m ago)',
  trend: [
    { time: '00:00', bpm: 58, restingBaseline: 60 },
    { time: '02:00', bpm: 55, restingBaseline: 60 },
    { time: '04:00', bpm: 54, restingBaseline: 60 },
    { time: '06:00', bpm: 59, restingBaseline: 60 },
    { time: '08:00', bpm: 74, restingBaseline: 61 },
    { time: '10:00', bpm: 82, restingBaseline: 61 },
    { time: '12:00', bpm: 78, restingBaseline: 61 },
    { time: '14:00', bpm: 96, restingBaseline: 61 },
    { time: '16:00', bpm: 112, restingBaseline: 62 },
    { time: '18:00', bpm: 84, restingBaseline: 62 },
    { time: '20:00', bpm: 76, restingBaseline: 61 },
    { time: '22:00', bpm: 68, restingBaseline: 61 },
  ],
};

export const mockSleepToday: SleepMetric = {
  totalMinutes: 408, // 6h 48m
  recentAvgMinutes: 442, // 7h 22m
  consistencyPercentage: 84,
  asleepTime: '23:34',
  wakeTime: '06:22',
  hasStageData: false, // FitCloudPro does not report REM
  stageNote: 'Sleep stage data is not available from the current provider.',
  dailyTrend: [
    { label: 'Thu', totalMinutes: 450, targetMinutes: 480 },
    { label: 'Fri', totalMinutes: 435, targetMinutes: 480 },
    { label: 'Sat', totalMinutes: 490, targetMinutes: 480 },
    { label: 'Sun', totalMinutes: 460, targetMinutes: 480 },
    { label: 'Mon', totalMinutes: 395, targetMinutes: 480 },
    { label: 'Tue', totalMinutes: 410, targetMinutes: 480 },
    { label: 'Last Night', totalMinutes: 408, targetMinutes: 480 },
  ],
};

export const mockActivityToday: ActivityMetric = {
  steps: 7840,
  stepGoal: 10000,
  activeMinutes: 44,
  activeMinutesGoal: 45,
  caloriesBurnedKcal: 420,
  distanceKm: 5.8,
  trend: [
    { label: '06:00', steps: 180, activeMinutes: 2 },
    { label: '08:00', steps: 1120, activeMinutes: 10 },
    { label: '10:00', steps: 840, activeMinutes: 4 },
    { label: '12:00', steps: 1420, activeMinutes: 8 },
    { label: '14:00', steps: 960, activeMinutes: 5 },
    { label: '16:00', steps: 2120, activeMinutes: 12 },
    { label: '18:00', steps: 890, activeMinutes: 3 },
    { label: '20:00', steps: 310, activeMinutes: 0 },
  ],
};

export const mockBloodOxygenToday: BloodOxygenMetric = {
  isAvailable: true,
  latestPercentage: 98,
  latestTimestamp: '07:15 AM',
  measurements: [
    { id: 'spo2-1', timestamp: '07:15 AM', percentage: 98, status: 'normal', condition: 'resting' },
    { id: 'spo2-2', timestamp: '02:40 AM', percentage: 97, status: 'normal', condition: 'sleep' },
    { id: 'spo2-3', timestamp: 'Yesterday, 22:15', percentage: 98, status: 'normal', condition: 'spot-check' },
    { id: 'spo2-4', timestamp: 'Yesterday, 15:30', percentage: 99, status: 'normal', condition: 'spot-check' },
  ],
};

// Week mock metrics
export const mockHeartRateWeek: HeartRateMetric = {
  currentBpm: 72,
  restingAvgBpm: 60,
  minBpm: 52,
  maxBpm: 132,
  timestamp: '7-day rolling window',
  trend: [
    { time: 'Wed', bpm: 60, restingBaseline: 60 },
    { time: 'Thu', bpm: 61, restingBaseline: 60 },
    { time: 'Fri', bpm: 59, restingBaseline: 60 },
    { time: 'Sat', bpm: 62, restingBaseline: 60 },
    { time: 'Sun', bpm: 58, restingBaseline: 60 },
    { time: 'Mon', bpm: 63, restingBaseline: 60 },
    { time: 'Today', bpm: 61, restingBaseline: 60 },
  ],
};

export const mockSleepWeek: SleepMetric = {
  totalMinutes: 3048, // 7-day sum
  recentAvgMinutes: 435, // 7h 15m
  consistencyPercentage: 86,
  asleepTime: '23:25 avg',
  wakeTime: '06:40 avg',
  hasStageData: false,
  stageNote: 'Sleep stage data is not available from the current provider.',
  dailyTrend: [
    { label: 'Wed', totalMinutes: 440, targetMinutes: 480 },
    { label: 'Thu', totalMinutes: 450, targetMinutes: 480 },
    { label: 'Fri', totalMinutes: 435, targetMinutes: 480 },
    { label: 'Sat', totalMinutes: 490, targetMinutes: 480 },
    { label: 'Sun', totalMinutes: 460, targetMinutes: 480 },
    { label: 'Mon', totalMinutes: 395, targetMinutes: 480 },
    { label: 'Tue', totalMinutes: 408, targetMinutes: 480 },
  ],
};

export const mockActivityWeek: ActivityMetric = {
  steps: 61850,
  stepGoal: 70000,
  activeMinutes: 312,
  activeMinutesGoal: 315,
  caloriesBurnedKcal: 3180,
  distanceKm: 46.2,
  trend: [
    { label: 'Wed', steps: 8900, activeMinutes: 45 },
    { label: 'Thu', steps: 9400, activeMinutes: 48 },
    { label: 'Fri', steps: 8200, activeMinutes: 40 },
    { label: 'Sat', steps: 11400, activeMinutes: 62 },
    { label: 'Sun', steps: 6800, activeMinutes: 32 },
    { label: 'Mon', steps: 9310, activeMinutes: 41 },
    { label: 'Tue', steps: 7840, activeMinutes: 44 },
  ],
};

export const mockBloodOxygenWeek: BloodOxygenMetric = {
  isAvailable: true,
  latestPercentage: 98,
  latestTimestamp: 'Today, 07:15 AM',
  measurements: [
    { id: 'spo2-w1', timestamp: 'Today, 07:15 AM', percentage: 98, status: 'normal', condition: 'resting' },
    { id: 'spo2-w2', timestamp: 'Yesterday, 22:15 PM', percentage: 98, status: 'normal', condition: 'spot-check' },
    { id: 'spo2-w3', timestamp: '2 days ago', percentage: 97, status: 'normal', condition: 'sleep' },
    { id: 'spo2-w4', timestamp: '3 days ago', percentage: 99, status: 'normal', condition: 'resting' },
    { id: 'spo2-w5', timestamp: '4 days ago', percentage: 98, status: 'normal', condition: 'spot-check' },
  ],
};

// Month mock metrics
export const mockHeartRateMonth: HeartRateMetric = {
  currentBpm: 72,
  restingAvgBpm: 60,
  minBpm: 50,
  maxBpm: 138,
  timestamp: '30-day baseline average',
  trend: [
    { time: 'Wk 1', bpm: 61, restingBaseline: 60 },
    { time: 'Wk 2', bpm: 59, restingBaseline: 60 },
    { time: 'Wk 3', bpm: 60, restingBaseline: 60 },
    { time: 'Wk 4', bpm: 61, restingBaseline: 60 },
  ],
};

export const mockSleepMonth: SleepMetric = {
  totalMinutes: 13140, // 30-day sum
  recentAvgMinutes: 438, // 7h 18m
  consistencyPercentage: 83,
  asleepTime: '23:30 avg',
  wakeTime: '06:48 avg',
  hasStageData: false,
  stageNote: 'Sleep stage data is not available from the current provider.',
  dailyTrend: [
    { label: 'Week 1', totalMinutes: 442, targetMinutes: 480 },
    { label: 'Week 2', totalMinutes: 435, targetMinutes: 480 },
    { label: 'Week 3', totalMinutes: 448, targetMinutes: 480 },
    { label: 'Week 4', totalMinutes: 426, targetMinutes: 480 },
  ],
};

export const mockActivityMonth: ActivityMetric = {
  steps: 254200,
  stepGoal: 300000,
  activeMinutes: 1280,
  activeMinutesGoal: 1350,
  caloriesBurnedKcal: 12900,
  distanceKm: 188.5,
  trend: [
    { label: 'Week 1', steps: 62400, activeMinutes: 320 },
    { label: 'Week 2', steps: 65100, activeMinutes: 340 },
    { label: 'Week 3', steps: 68300, activeMinutes: 360 },
    { label: 'Week 4', steps: 58400, activeMinutes: 260 },
  ],
};

export const mockBloodOxygenMonth: BloodOxygenMetric = {
  isAvailable: true,
  latestPercentage: 98,
  latestTimestamp: 'Today, 07:15 AM',
  measurements: [
    { id: 'spo2-m1', timestamp: 'Today, 07:15 AM', percentage: 98, status: 'normal', condition: 'resting' },
    { id: 'spo2-m2', timestamp: '3 days ago', percentage: 97, status: 'normal', condition: 'sleep' },
    { id: 'spo2-m3', timestamp: '1 week ago', percentage: 99, status: 'normal', condition: 'spot-check' },
    { id: 'spo2-m4', timestamp: '2 weeks ago', percentage: 98, status: 'normal', condition: 'spot-check' },
    { id: 'spo2-m5', timestamp: '3 weeks ago', percentage: 97, status: 'normal', condition: 'sleep' },
  ],
};

// Soft Glass Non-Diagnostic Insights
export const mockHealthInsights: HealthInsight[] = [
  {
    id: 'insight-1',
    category: 'sleep',
    title: 'Sleep Duration Trend',
    observation:
      'Your sleep duration has been below your recent average for the last few nights (6h 48m vs 7h 22m 14-day baseline).',
    tag: 'Rest Routine',
    timeframe: 'Past 3 nights',
    type: 'attention',
  },
  {
    id: 'insight-2',
    category: 'heart',
    title: 'Resting Heart Rate Stability',
    observation:
      'Resting heart rate remained steady between 58 and 63 bpm across daytime intervals, consistent with your normal recovery window.',
    tag: 'Baseline Stability',
    timeframe: 'Today',
    type: 'positive',
  },
  {
    id: 'insight-3',
    category: 'activity',
    title: 'Afternoon Movement Peak',
    observation:
      'The majority of daily steps and active minutes clustered between 14:00 and 17:30, meeting 78% of your movement goal.',
    tag: 'Pacing',
    timeframe: 'Daily cadence',
    type: 'info',
  },
  {
    id: 'insight-4',
    category: 'general',
    title: 'Sync & Ingestion Continuity',
    observation:
      'Local AI Core received 3,410 discrete telemetry readings via Android Health Connect with 99.1% temporal consistency.',
    tag: 'Pipeline',
    timeframe: 'Last sync 4m ago',
    type: 'info',
  },
];
