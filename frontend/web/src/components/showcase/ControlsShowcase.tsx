import React, { useState } from 'react';
import {
  Search,
  Key,
  Database,
  Cpu,
  Bot,
  Sliders,
  Sparkles,
  Volume2,
  Lock,
  Layers,
} from 'lucide-react';
import { SectionHeader } from '../ui/SectionHeader';
import { TextInput } from '../ui/TextInput';
import { SearchInput } from '../ui/SearchInput';
import { Select } from '../ui/Select';
import { Toggle } from '../ui/Toggle';
import { Slider } from '../ui/Slider';
import { Tabs } from '../ui/Tabs';
import { Badge } from '../ui/Badge';
import { Card } from '../ui/Card';

export const ControlsShowcase: React.FC = () => {
  // States for live interactive demo
  const [searchValue, setSearchValue] = useState('');
  const [textVal, setTextVal] = useState('localhost:8000/v1');
  const [apiKeyVal, setApiKeyVal] = useState('sk-local-core-mock-token');
  const [selectedModel, setSelectedModel] = useState('m-1');
  const [tabVal, setTabVal] = useState('compute');

  // Toggle states
  const [gpuOffload, setGpuOffload] = useState(true);
  const [vadEnabled, setVadEnabled] = useState(true);
  const [flashAttn, setFlashAttn] = useState(false);

  // Slider states
  const [temperature, setTemperature] = useState(70);
  const [contextTokens, setContextTokens] = useState(4096);
  const [topP, setTopP] = useState(90);

  const modelOptions = [
    {
      value: 'm-1',
      label: 'Llama-3.1-8B-Instruct',
      description: 'Q4_K_M • 4.92 GB • 16k context',
      icon: <Bot className="w-4 h-4 text-[var(--color-accent)]" />,
      badge: 'Active',
    },
    {
      value: 'm-2',
      label: 'Qwen-2.5-Coder-7B',
      description: 'Q5_K_M • 5.43 GB • 32k context',
      icon: <Cpu className="w-4 h-4 text-emerald-500" />,
    },
    {
      value: 'm-3',
      label: 'DeepSeek-R1-Distill-8B',
      description: 'Q4_K_S • 4.80 GB • Reasoning',
      icon: <Sparkles className="w-4 h-4 text-violet-500" />,
    },
  ];

  const tabItems = [
    { id: 'compute', label: 'Compute Engine', icon: <Cpu className="w-4 h-4" /> },
    { id: 'sampling', label: 'Sampling Params', icon: <Sliders className="w-4 h-4" /> },
    { id: 'memory', label: 'Context & KV', icon: <Database className="w-4 h-4" />, badge: '16k' },
  ];

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      {/* Search & Text Inputs */}
      <div className="space-y-4">
        <SectionHeader
          title="Text & Search Inputs"
          description="Tactile recessed surfaces with clean focus rings, icon slots, and validation states."
          badge={<Badge variant="accent">Tactile Recessed</Badge>}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-5 p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)]">
          <div className="space-y-4">
            <SearchInput
              value={searchValue}
              onChangeValue={setSearchValue}
              placeholder="Search local embeddings..."
            />

            <TextInput
              label="Local API Host Endpoint"
              value={textVal}
              onChange={(e) => setTextVal(e.target.value)}
              leftIcon={<Database className="w-4 h-4" />}
              helperText="Target URL for the local Python FastAPI Core."
            />
          </div>

          <div className="space-y-4">
            <TextInput
              label="Local Master Key"
              type="password"
              value={apiKeyVal}
              onChange={(e) => setApiKeyVal(e.target.value)}
              leftIcon={<Key className="w-4 h-4" />}
              state="success"
              helperText="Authenticated with local IPC tunnel."
            />

            <TextInput
              label="Error Validation Sample"
              defaultValue="invalid://core-port"
              state="error"
              error="Connection refused: port 8000 is occupied or offline."
            />
          </div>
        </div>
      </div>

      {/* Select Dropdown */}
      <div className="space-y-4">
        <SectionHeader
          title="Select & Dropdown Control"
          description="Glass-backed options menu with keyboard focus, active markers, and option descriptions."
        />

        <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] max-w-xl">
          <Select
            label="Active Local AI Model"
            options={modelOptions}
            value={selectedModel}
            onChange={setSelectedModel}
          />
        </div>
      </div>

      {/* Toggles and Switches */}
      <div className="space-y-4">
        <SectionHeader
          title="Neumorphic Toggles & Switches"
          description="Tactile recessed groove with convex raised switch thumb. Includes high-contrast color indicator for accessibility."
          badge={<Badge variant="glass">Accessible Neumorphic</Badge>}
        />

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
          <Card variant="raised" padding="md">
            <Toggle
              checked={gpuOffload}
              onChange={setGpuOffload}
              label="GPU Layer Offloading"
              description="Offload 32 of 32 layers to VRAM"
            />
          </Card>

          <Card variant="raised" padding="md">
            <Toggle
              checked={vadEnabled}
              onChange={setVadEnabled}
              label="Voice Activity Detect"
              description="Continuous low-power mic stream"
            />
          </Card>

          <Card variant="raised" padding="md">
            <Toggle
              checked={flashAttn}
              onChange={setFlashAttn}
              label="Flash Attention v2"
              description="Accelerate context ingestion"
            />
          </Card>
        </div>
      </div>

      {/* Sliders */}
      <div className="space-y-4">
        <SectionHeader
          title="Tactile Sliders"
          description="Carved recessed groove with vibrant accent gradient track and tactile raised slider thumb."
        />

        <div className="grid grid-cols-1 md:grid-cols-3 gap-5 p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)]">
          <Slider
            value={temperature}
            onChange={setTemperature}
            min={0}
            max={100}
            label="Generation Temperature"
            unit=" / 100"
          />

          <Slider
            value={contextTokens}
            onChange={setContextTokens}
            min={1024}
            max={16384}
            step={512}
            label="Context Window Size"
            unit=" tokens"
          />

          <Slider
            value={topP}
            onChange={setTopP}
            min={10}
            max={100}
            label="Nucleus Sampling (Top-P)"
            unit="%"
          />
        </div>
      </div>

      {/* Segmented Tabs */}
      <div className="space-y-4">
        <SectionHeader
          title="Segmented Tabs Controller"
          description="Smooth sliding active pill inside a soft recessed container."
          badge={<Badge variant="accent">Spring Motion</Badge>}
        />

        <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
          <Tabs items={tabItems} activeId={tabVal} onChange={setTabVal} size="md" />

          <div className="p-4 rounded-xl surface-recessed text-xs text-[var(--color-text-secondary)]">
            Active Configuration View: <strong className="text-[var(--color-text-primary)]">{tabVal.toUpperCase()}</strong>
          </div>
        </div>
      </div>
    </div>
  );
};
