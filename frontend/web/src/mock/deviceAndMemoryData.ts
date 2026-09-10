import {
  DeviceItem,
  AudioDeviceOption,
  AudioRoutingConfig,
  AndroidSyncItem,
  RemoteGatewayDetails,
  MemoryEntry,
  MemoryCategory,
} from '../types';

// =========================================================================
// DEVICES PAGE MOCK DATA
// =========================================================================

export const mockDevicesList: DeviceItem[] = [
  // COMPUTERS
  {
    id: 'comp-desktop',
    name: 'Workstation Host (Threadripper / RTX 4090)',
    category: 'computer',
    status: 'online',
    capability: 'CUDA Acceleration (24GB VRAM), PCIe 5.0 NVMe, Local LLM & Vector Store Host',
    lastSeen: 'Just now (Local Node)',
    assignedRole: 'Primary Cognitive Compute Host',
    iconType: 'desktop',
    ipOrAddress: '127.0.0.1 / 100.84.12.9',
    details: {
      'CPU Cores': 64,
      'System RAM': '128 GB DDR5',
      'VRAM Offload': '24 GB GDDR6X',
      'Kernel': 'Linux 6.10.6-zen',
    },
  },

  // MOBILE
  {
    id: 'mob-pixel',
    name: 'Pixel 8 Pro (Android 15)',
    category: 'mobile',
    status: 'connected',
    capability: 'Health Connect Sync, Alarms & Reminders Bridge, Push-to-Talk Voice Companion, GPS',
    lastSeen: '24s ago',
    assignedRole: 'Mobile Client & Satellite Node',
    iconType: 'phone',
    batteryLevel: 84,
    ipOrAddress: '100.84.12.14',
    details: {
      'OS Build': 'AP4A.240905.002',
      'Battery': '84% (Charging)',
      'Protocol': 'WebSocket Encrypted',
      'Ping': '18ms',
    },
  },

  // AUDIO - Microphone
  {
    id: 'aud-mic-wave',
    name: 'Elgato Wave:3 USB (Studio Array)',
    category: 'audio',
    status: 'online',
    capability: 'Cardioid Capsule, 96kHz / 24-bit PCM, Hardware Clipguard, Local VAD Stream',
    lastSeen: 'Active stream',
    assignedRole: 'Primary Voice Input',
    iconType: 'mic',
    details: {
      'Interface': 'USB 3.1 Direct',
      'Sample Rate': '96 kHz / 24-bit',
      'VAD Threshold': '-26 dB RMS',
    },
  },

  // AUDIO - Bluetooth headset
  {
    id: 'aud-headset-xm5',
    name: 'Sony WH-1000XM5 (ANC Headset)',
    category: 'audio',
    status: 'connected',
    capability: 'LDAC 990kbps bit-perfect, Dual Beamforming Microphones, Active Noise Cancellation',
    lastSeen: 'Connected (BLE 5.2)',
    assignedRole: 'Hands-free Audio & Voice Companion',
    iconType: 'headphones',
    batteryLevel: 92,
    details: {
      'Codec': 'LDAC (990 kbps)',
      'Latency': '34ms',
      'ANC Mode': 'Ambient Voice Boost',
    },
  },

  // AUDIO - System/default devices
  {
    id: 'aud-sys-pipewire',
    name: 'System Default Audio Sink (PipeWire)',
    category: 'audio',
    status: 'online',
    capability: 'Unified Low-Latency Audio Bus, Automatic Stream Mixing, Jack/ALSA Emulation',
    lastSeen: 'Always available',
    assignedRole: 'Default Desktop Audio Sink',
    iconType: 'speaker',
    details: {
      'Audio Engine': 'PipeWire 1.2.3',
      'Quantum Size': '256 samples',
      'Dynamic Routing': 'Active',
    },
  },

  // HEALTH - Health Connect
  {
    id: 'hlth-health-connect',
    name: 'Android Health Connect Hub',
    category: 'health',
    status: 'connected',
    capability: 'Encrypted On-Device Biometric Datastore, Multi-app Permission Gate, Background Aggregator',
    lastSeen: 'Synced 4m ago',
    assignedRole: 'Central Biometric Aggregator',
    iconType: 'activity',
    details: {
      'Data Points Today': 3410,
      'Read Permissions': 'Heart Rate, Sleep, SpO2, Steps',
      'Sync Frequency': 'Every 15m',
    },
  },

  // HEALTH - Smartwatch source
  {
    id: 'hlth-smartwatch',
    name: 'Smart Wellness Watch (FitCloudPro BLE)',
    category: 'health',
    status: 'connected',
    capability: 'PPG Optical Heart Rate, Continuous SpO2, Tri-axial Accelerometer, Sleep Architecture',
    lastSeen: 'Active sync (4m ago)',
    assignedRole: 'Biometric Sensor Source',
    iconType: 'watch',
    batteryLevel: 76,
    details: {
      'Sensor': 'Dual Green/Red Optical PPG',
      'HR Cadence': 'Continuous 1-min interval',
      'Firmware': 'v4.18.2',
    },
  },

  // NETWORK - Remote Gateway
  {
    id: 'net-remote-gw',
    name: 'Remote Mesh Gateway (remote-gw-home)',
    category: 'network',
    status: 'connected',
    capability: 'End-to-End Encrypted Mesh Overlay, WireGuard Protocol, Zero-Trust Access, NAT Traversal',
    lastSeen: 'Connected (14ms ping)',
    assignedRole: 'Encrypted Remote Ingress Proxy',
    iconType: 'network',
    ipOrAddress: '100.84.12.1',
    details: {
      'Mesh Provider': 'Tailscale (Replaceable)',
      'Virtual IP': '100.84.12.9',
      'Latency': '14ms',
      'Encryption': 'ChaCha20-Poly1305',
    },
  },
];

// Available Audio Devices for the Audio Device Manager
export const mockAudioInputOptions: AudioDeviceOption[] = [
  {
    id: 'in-wave3',
    name: 'Elgato Wave:3 USB (Cardioid Studio Array)',
    type: 'input',
    interfaceType: 'usb',
    sampleRate: '96 kHz / 24-bit',
    channels: '1 Channel Mono',
    isDefault: true,
  },
  {
    id: 'in-xm5-mic',
    name: 'Sony WH-1000XM5 Headset Mic (Beamforming)',
    type: 'input',
    interfaceType: 'bluetooth',
    sampleRate: '16 kHz mSBC',
    channels: '1 Channel Mono',
  },
  {
    id: 'in-sys-default',
    name: 'System Default Audio Input (PipeWire)',
    type: 'input',
    interfaceType: 'system',
    sampleRate: '48 kHz / 32-bit float',
    channels: '2 Channels Stereo',
  },
  {
    id: 'in-virtual-loopback',
    name: 'Virtual Audio Loopback Source (Assistant Mix)',
    type: 'input',
    interfaceType: 'virtual',
    sampleRate: '48 kHz / 24-bit',
    channels: '2 Channels Stereo',
  },
];

export const mockAudioOutputOptions: AudioDeviceOption[] = [
  {
    id: 'out-monitors',
    name: 'Studio Nearfield Monitors (Yamaha HS7 / USB DAC)',
    type: 'output',
    interfaceType: 'usb',
    sampleRate: '192 kHz / 24-bit',
    channels: '2 Channels Stereo',
    isDefault: true,
  },
  {
    id: 'out-xm5',
    name: 'Sony WH-1000XM5 (LDAC High-Resolution)',
    type: 'output',
    interfaceType: 'bluetooth',
    sampleRate: '96 kHz / 24-bit',
    channels: '2 Channels Stereo',
  },
  {
    id: 'out-sys-sink',
    name: 'System Default Audio Sink (PipeWire Native)',
    type: 'output',
    interfaceType: 'system',
    sampleRate: '48 kHz / 32-bit float',
    channels: '2 Channels Stereo',
  },
  {
    id: 'out-hdmi-display',
    name: 'HDMI / DisplayPort Audio (NVIDIA High Definition)',
    type: 'output',
    interfaceType: 'pci',
    sampleRate: '48 kHz / 24-bit',
    channels: '2 Channels Stereo',
  },
  {
    id: 'out-virtual-voice',
    name: 'Virtual Audio Sink (Assistant Voice Stream)',
    type: 'output',
    interfaceType: 'virtual',
    sampleRate: '48 kHz / 24-bit',
    channels: '2 Channels Stereo',
  },
];

export const initialAudioRoutingConfig: AudioRoutingConfig = {
  inputDeviceId: 'in-wave3',
  outputDeviceId: 'out-monitors',
  preferredOutputId: 'out-xm5',
  fallbackOutputId: 'out-sys-sink',
};

// Android Sync Mock Data
export const mockAndroidSyncItems: AndroidSyncItem[] = [
  {
    name: 'Alarms Synchronization',
    key: 'alarms',
    status: 'synced',
    details: '4 alarms configured (Next: 07:30 AM tomorrow)',
    lastSynced: 'Just now',
  },
  {
    name: 'Tasks & Reminders',
    key: 'tasks',
    status: 'synced',
    details: '12 active tasks synchronized with local database',
    lastSynced: '2m ago',
  },
  {
    name: 'Health & Biometrics',
    key: 'health',
    status: 'synced',
    details: 'Health Connect bridge active (3,410 biometric samples today)',
    lastSynced: '4m ago',
  },
  {
    name: 'Assistant Remote Connection',
    key: 'assistantConnection',
    status: 'connected',
    details: 'WebSocket live stream (wss://100.84.12.14:8443) • 18ms latency',
    lastSynced: 'Continuous',
  },
];

// Health Providers (Keep providers replaceable as requested)
export interface HealthSourceOption {
  id: string;
  name: string;
  deviceModel: string;
  protocol: string;
  status: 'connected' | 'standby' | 'disconnected';
  lastSynced: string;
  supportedMetrics: string[];
}

export const mockHealthSourceOptions: HealthSourceOption[] = [
  {
    id: 'fitcloudpro',
    name: 'FitCloudPro',
    deviceModel: 'Smart Wellness Band K22 (BLE)',
    protocol: 'Bluetooth LE Daemon -> Android Health Connect',
    status: 'connected',
    lastSynced: '4m ago',
    supportedMetrics: ['Heart Rate', 'Sleep Duration', 'SpO2', 'Step Count'],
  },
  {
    id: 'wearos_pixel',
    name: 'Wear OS / Pixel Watch',
    deviceModel: 'Google Pixel Watch 2',
    protocol: 'Native Health Connect API Integration',
    status: 'standby',
    lastSynced: '2 hours ago',
    supportedMetrics: ['Continuous HR', 'Sleep Stages (REM/Deep)', 'SpO2', 'Skin Temp', 'ECG'],
  },
  {
    id: 'garmin_connect',
    name: 'Garmin Connect',
    deviceModel: 'Garmin Forerunner 265',
    protocol: 'Garmin Health API Bridge -> Health Connect',
    status: 'standby',
    lastSynced: 'Yesterday, 22:45',
    supportedMetrics: ['Continuous HR', 'HRV Status', 'Sleep Stages', 'VO2 Max'],
  },
  {
    id: 'oura_ring',
    name: 'Oura Ring Gen 3',
    deviceModel: 'Oura Heritage Silver',
    protocol: 'Oura Cloud Sync -> Health Connect Export',
    status: 'standby',
    lastSynced: 'Yesterday, 08:30',
    supportedMetrics: ['Sleep Score', 'Resting HR', 'HRV', 'Body Temp Trend'],
  },
];

// Remote Gateway Providers (Generic, not architected around Tailscale being permanent)
export interface RemoteGatewayProviderOption {
  id: string;
  name: string;
  protocol: string;
  description: string;
  isCurrent: boolean;
}

export const mockGatewayProviders: RemoteGatewayProviderOption[] = [
  {
    id: 'tailscale',
    name: 'Tailscale',
    protocol: 'WireGuard (Mesh)',
    description: 'Zero-config overlay mesh with automated key exchange and DERP relays.',
    isCurrent: true,
  },
  {
    id: 'wireguard_native',
    name: 'WireGuard (Direct)',
    protocol: 'UDP Encrypted',
    description: 'Native Linux kernel WireGuard peer-to-peer tunnel without coordinator.',
    isCurrent: false,
  },
  {
    id: 'headscale',
    name: 'Headscale (Self-Hosted)',
    protocol: 'WireGuard (Self-Hosted Control)',
    description: 'Private self-hosted control plane compatible with Tailscale clients.',
    isCurrent: false,
  },
  {
    id: 'cloudflare_tunnel',
    name: 'Cloudflare Zero Trust',
    protocol: 'QUIC / HTTPS Ingress',
    description: 'Cloudflare ingress tunnel with OAuth application access proxy.',
    isCurrent: false,
  },
  {
    id: 'local_lan',
    name: 'Local LAN Direct (mDNS)',
    protocol: 'TLS 1.3 / mDNS',
    description: 'Subnet local discovery without external routing or mesh coordinator.',
    isCurrent: false,
  },
];

export const initialRemoteGatewayDetails: RemoteGatewayDetails = {
  name: 'Remote Gateway',
  provider: 'Tailscale',
  status: 'connected',
  virtualIp: '100.84.12.9',
  latencyMs: 14,
  assignedRole: 'Encrypted Remote Ingress Proxy',
  encryption: 'ChaCha20-Poly1305 (256-bit)',
  protocol: 'WireGuard Mesh v1.74',
};

// =========================================================================
// MEMORY PAGE MOCK DATA
// =========================================================================

export const initialMemoryEntries: MemoryEntry[] = [
  {
    id: 'mem-1',
    content: 'User is Chris Vance, a senior systems architect specializing in autonomous local AI infrastructure, embedded edge computing, and distributed agent systems.',
    category: 'Profile',
    source: 'Initial Setup & User Profile Dialogue',
    confidence: 0.99,
    lastUpdated: '3 days ago',
    isArchived: false,
    tags: ['identity', 'architect', 'profile'],
  },
  {
    id: 'mem-2',
    content: 'Response style preference: Strictly concise and code-first. Omit conversational filler, disclaimers, and pleasantries. Provide architectural explanations only when explicitly prompted.',
    category: 'Preference',
    source: 'Conversation with Chris (Session #14)',
    confidence: 0.97,
    lastUpdated: 'Yesterday, 18:22',
    isArchived: false,
    tags: ['style', 'concise', 'code-first'],
  },
  {
    id: 'mem-3',
    content: 'Inference preference: Always prioritize local llama.cpp / vLLM execution on the RTX 4090 GPU. Fall back to Gemini 2.0 Flash only when context exceeds 32,000 tokens.',
    category: 'Preference',
    source: 'Settings & Model Routing Directive',
    confidence: 0.98,
    lastUpdated: 'Sep 7, 2026',
    isArchived: false,
    tags: ['inference', 'gpu', 'llama.cpp', 'routing'],
  },
  {
    id: 'mem-4',
    content: 'Hardware configuration: Primary workstation runs Arch Linux 6.10 with an NVIDIA RTX 4090 (24GB VRAM), AMD Threadripper Pro (64 cores), and 128GB DDR5 system RAM.',
    category: 'Fact',
    source: 'Hardware Telemetry Daemon Ingestion',
    confidence: 1.0,
    lastUpdated: '1h ago',
    isArchived: false,
    tags: ['hardware', 'specs', 'linux', 'gpu'],
  },
  {
    id: 'mem-5',
    content: 'Biometric baseline: Chris resting heart rate during deep sleep averages 58 bpm. Sustained daytime heart rate over 82 bpm during coding sessions correlates with cognitive stress.',
    category: 'Fact',
    source: 'Health Connect Longitudinal Analysis',
    confidence: 0.92,
    lastUpdated: '4h ago',
    isArchived: false,
    tags: ['health', 'biometrics', 'baseline', 'heart-rate'],
  },
  {
    id: 'mem-6',
    content: 'Autonomous Local AI Control Center batch roadmap: Currently finalizing Batch 9 (Devices and Memory). Upcoming milestones include streaming audio pipelines and persistent background agents.',
    category: 'Project',
    source: 'Project Workspace Specification',
    confidence: 0.96,
    lastUpdated: 'Just now',
    isArchived: false,
    tags: ['roadmap', 'batch-9', 'control-center'],
  },
  {
    id: 'mem-7',
    content: 'FastAPI Backend Architecture: Exposes REST API on port 8000 and low-latency WebSocket endpoint on /ws/stream for bidirectional voice streaming and telemetry synchronization.',
    category: 'Project',
    source: 'IDE Ingestion & Schema Analyzer',
    confidence: 0.94,
    lastUpdated: '2 days ago',
    isArchived: false,
    tags: ['fastapi', 'architecture', 'websockets', 'backend'],
  },
  {
    id: 'mem-8',
    content: 'DeepSeek-R1 evaluation lab and quantization benchmark session scheduled for Friday, Sep 11 at 11:30 AM in Local Lab with GPU telemetry logging enabled.',
    category: 'Event',
    source: 'Schedule Calendar Ingestion',
    confidence: 0.95,
    lastUpdated: 'Sep 8, 2026',
    isArchived: false,
    tags: ['calendar', 'benchmarks', 'deepseek', 'event'],
  },
  {
    id: 'mem-9',
    content: 'Morning wake-up alarm set for 07:30 AM tomorrow with dawn light crescendo and gentle chimes, synchronized to both Desktop PC and Pixel 8 Pro.',
    category: 'Event',
    source: 'Android Alarms Mirror',
    confidence: 0.99,
    lastUpdated: '18m ago',
    isArchived: false,
    tags: ['alarm', 'morning', 'sync'],
  },
  {
    id: 'mem-10',
    content: 'Active debug buffer: PipeWire audio buffer configuration currently set to 256 samples (5.3ms latency) for testing potential underrun events during model warmups.',
    category: 'Temporary',
    source: 'Live Terminal Buffer',
    confidence: 0.88,
    lastUpdated: '14m ago',
    isArchived: false,
    tags: ['debug', 'audio', 'pipewire', 'scratchpad'],
  },
  {
    id: 'mem-11',
    content: 'Transient network clipboard: Mesh gateway test IP 100.84.12.14 copied to clipboard for remote SSH connectivity verification.',
    category: 'Temporary',
    source: 'Desktop Clipboard Observer',
    confidence: 0.82,
    lastUpdated: '35m ago',
    isArchived: false,
    tags: ['clipboard', 'network', 'transient'],
  },
  {
    id: 'mem-12',
    content: 'Optimal daily productivity window: Peak focus identified between 09:30-12:30 and 15:00-17:30. Avoid scheduling non-critical notifications during these intervals.',
    category: 'Profile',
    source: 'Biometric & Schedule Longitudinal Model',
    confidence: 0.91,
    lastUpdated: 'Sep 6, 2026',
    isArchived: false,
    tags: ['profile', 'circadian', 'productivity'],
  },
];
