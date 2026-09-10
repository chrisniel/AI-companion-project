import React, { useState, useMemo } from 'react';
import {
  Sparkles,
  Bot,
  Activity,
  CheckSquare,
  Cpu,
  Zap,
  ArrowRight,
  HardDrive,
  ShieldCheck,
  Clock,
  AlarmClock,
  Bell,
  CheckCircle2,
  Circle,
  Plus,
  Heart,
  MoonStar,
  Footprints,
  Calendar,
  Layers,
  ChevronRight,
  Globe,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { StatusIndicator } from '../ui/StatusIndicator';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { ProgressBar } from '../ui/ProgressBar';
import { Modal } from '../ui/Modal';
import { TextInput } from '../ui/TextInput';
import { SupportedLanguageCode } from '../../types';
import { getLanguageAwareGreeting } from '../../mock/multilingualData';

export interface HomeViewProps {
  onNavigate: (sectionId: string) => void;
  activeCharacterName?: string;
  userName?: string;
}

interface QuickTask {
  id: string;
  title: string;
  category: string;
  completed: boolean;
  time?: string;
}

interface QuickReminder {
  id: string;
  title: string;
  time: string;
  active: boolean;
}

interface QuickAlarm {
  id: string;
  title: string;
  time: string;
  armed: boolean;
}

export const HomeView: React.FC<HomeViewProps> = ({
  onNavigate,
  activeCharacterName = 'Aura',
  userName = 'Chris',
}) => {
  // 1. BATCH 12.1: Dynamic Multilingual Language-Aware Greeting
  const [greetingLanguage, setGreetingLanguage] = useState<SupportedLanguageCode | 'auto_detect'>('auto_detect');

  const greetingData = useMemo(() => {
    return getLanguageAwareGreeting(greetingLanguage, userName);
  }, [greetingLanguage, userName]);

  const currentDateString = useMemo(() => {
    return new Date().toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'short',
      day: 'numeric',
    });
  }, []);

  // 2. Interactive Quick Actions Modal State
  const [activeModal, setActiveModal] = useState<'task' | 'reminder' | 'alarm' | 'assistant' | null>(null);
  const [modalInputTitle, setModalInputTitle] = useState('');
  const [modalInputTime, setModalInputTime] = useState('');

  // 3. Interactive Tasks, Reminders, and Alarms State
  const [tasks, setTasks] = useState<QuickTask[]>([
    { id: 't-1', title: 'Review llama.cpp FP16 vs Q4_K_M benchmarks', category: 'Inference', completed: true, time: '08:30 AM' },
    { id: 't-2', title: 'Audit local Chroma vector database index', category: 'Memory', completed: true, time: '09:15 AM' },
    { id: 't-3', title: 'Calibrate studio microphone VAD noise gate', category: 'Audio', completed: true, time: '10:00 AM' },
    { id: 't-4', title: 'Synchronize daily Oura biometric telemetry', category: 'Wellness', completed: true, time: '10:45 AM' },
    { id: 't-5', title: 'Test zero-telemetry firewall packet rules', category: 'Security', completed: true, time: '11:30 AM' },
    { id: 't-6', title: 'Deep Work: Core Neural Pipeline Optimization', category: 'Core', completed: false, time: '02:30 PM' },
    { id: 't-7', title: 'Export conversation embeddings to local backup', category: 'Storage', completed: false, time: '04:00 PM' },
    { id: 't-8', title: 'Review evening audio briefing schedule', category: 'Assistant', completed: false, time: '06:00 PM' },
  ]);

  const [reminders, setReminders] = useState<QuickReminder[]>([
    { id: 'r-1', title: 'Hydration & ergonomic posture check', time: 'Every 2 hours', active: true },
    { id: 'r-2', title: 'Prepare slide deck for on-device AI workshop', time: '04:00 PM', active: true },
  ]);

  const [alarms, setAlarms] = useState<QuickAlarm[]>([
    { id: 'a-1', title: 'Morning Briefing & Voice Wakeup', time: '07:30 AM', armed: true },
  ]);

  const [activeTodayTab, setActiveTodayTab] = useState<'tasks' | 'reminders' | 'alarms'>('tasks');

  // Toggle task completion
  const toggleTask = (id: string) => {
    setTasks((prev) =>
      prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t))
    );
  };

  const completedCount = tasks.filter((t) => t.completed).length;
  const openCount = tasks.filter((t) => !t.completed).length;
  const completionPercentage = Math.round((completedCount / tasks.length) * 100);

  // Handle Quick Action Submissions
  const handleSaveModal = () => {
    if (!modalInputTitle.trim()) return;

    if (activeModal === 'task') {
      const newTask: QuickTask = {
        id: `t-${Date.now()}`,
        title: modalInputTitle.trim(),
        category: 'Workspace',
        completed: false,
        time: modalInputTime.trim() || 'Next in queue',
      };
      setTasks((prev) => [newTask, ...prev]);
    } else if (activeModal === 'reminder') {
      const newReminder: QuickReminder = {
        id: `r-${Date.now()}`,
        title: modalInputTitle.trim(),
        time: modalInputTime.trim() || 'Today',
        active: true,
      };
      setReminders((prev) => [newReminder, ...prev]);
    } else if (activeModal === 'alarm') {
      const newAlarm: QuickAlarm = {
        id: `a-${Date.now()}`,
        title: modalInputTitle.trim(),
        time: modalInputTime.trim() || '08:00 AM',
        armed: true,
      };
      setAlarms((prev) => [newAlarm, ...prev]);
    }

    setModalInputTitle('');
    setModalInputTime('');
    setActiveModal(null);
  };

  return (
    <div className="space-y-6">
      {/* ========================================================= */}
      {/* 1. HEADER: Contextual Mock Greeting (Batch 12.1 Aware)    */}
      {/* ========================================================= */}
      <div className="p-6 sm:p-7 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] relative overflow-hidden">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-5">
          <div className="space-y-2 max-w-xl">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant="accent" size="sm">
                Local AI Core Online
              </Badge>
              <span className="text-xs text-[var(--color-text-secondary)] font-mono">
                {currentDateString}
              </span>
              <span className="text-xs text-[var(--color-text-muted)] font-mono hidden sm:inline">
                • 0ms Cloud Latency
              </span>

              {/* Language Switcher Chips */}
              <div className="inline-flex items-center gap-1 p-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)] ml-auto sm:ml-2">
                {[
                  { id: 'auto_detect' as const, label: 'Auto' },
                  { id: 'en' as const, label: '🇺🇸 EN' },
                  { id: 'fil' as const, label: '🇵🇭 FIL' },
                  { id: 'ja' as const, label: '🇯🇵 JA' },
                  { id: 'mixed' as const, label: '✨ Mixed' },
                ].map((l) => (
                  <button
                    key={l.id}
                    type="button"
                    onClick={() => setGreetingLanguage(l.id)}
                    className={`px-1.5 py-0.5 rounded text-[10px] font-mono transition-all ${
                      greetingLanguage === l.id
                        ? 'bg-[var(--color-accent)] text-white font-bold shadow-xs'
                        : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    {l.label}
                  </button>
                ))}
              </div>
            </div>

            <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--color-text-primary)] flex items-center gap-2">
              <span>{greetingData.greeting}</span>
              <span className="text-lg opacity-85" title={greetingData.langLabel}>{greetingData.flag}</span>
            </h1>
            <p className="text-sm text-[var(--color-text-secondary)] leading-relaxed">
              {greetingData.subtitle} <span className="font-semibold text-[var(--color-text-primary)]">{activeCharacterName}</span> is standing by on Llama-3.1-8B-Instruct with all background systems nominal.
            </p>
          </div>

          <div className="flex items-center gap-2.5 flex-shrink-0">
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
                <Bot className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    {activeCharacterName}
                  </span>
                  <StatusIndicator status="online" size="sm" showLabel={false} />
                </div>
                <span className="text-[11px] text-[var(--color-text-secondary)] font-mono">
                  State: Ready / Standby
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 2. PRIMARY DASHBOARD: Four Main Summary Areas             */}
      {/* (NEXT, TODAY, AI STATUS, WELLNESS)                         */}
      {/* ========================================================= */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* AREA 1: NEXT */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
                Next Up
              </h2>
              <Badge variant="accent" size="sm">
                in 28m
              </Badge>
            </div>

            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <span className="text-xs font-semibold text-[var(--color-accent)] uppercase tracking-wider font-mono">
                    Scheduled Focus Block
                  </span>
                  <h3 className="text-base font-bold text-[var(--color-text-primary)] mt-0.5">
                    Deep Work: Core Neural Pipeline Optimization
                  </h3>
                </div>
                <div className="text-right flex-shrink-0">
                  <span className="text-sm font-mono font-bold text-[var(--color-text-primary)]">
                    02:30 PM
                  </span>
                  <p className="text-[10px] text-[var(--color-text-muted)]">60 mins</p>
                </div>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
                {activeCharacterName} will mute non-essential alerts, buffer incoming telemetry, and allocate GPU priority to local code generation.
              </p>
            </div>
          </div>

          <div className="flex items-center justify-between pt-1">
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Next alarm: 07:30 AM tomorrow
            </span>
            <div className="flex items-center gap-2">
              <NeumorphicButton
                size="sm"
                variant="primary"
                icon={<Zap className="w-3.5 h-3.5 text-white" />}
                onClick={() => onNavigate('tasks')}
              >
                Start Early
              </NeumorphicButton>
            </div>
          </div>
        </div>

        {/* AREA 2: AI STATUS */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
                AI Status
              </h2>
              <div className="flex items-center gap-1.5">
                <StatusIndicator status="online" size="sm" showLabel={false} />
                <span className="text-xs font-semibold text-emerald-500 font-mono">
                  Active & Nominal
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2.5 text-xs font-mono">
              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Core Status
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block">
                  Online (Port 8000)
                </span>
                <span className="text-[10px] text-emerald-500">22ms loopback latency</span>
              </div>

              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Active Local Model
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block truncate">
                  Llama-3.1-8B-Instruct
                </span>
                <span className="text-[10px] text-[var(--color-accent)]">Q4_K_M • Pinned in VRAM</span>
              </div>

              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Runtime / Provider
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block truncate">
                  llama.cpp (CUDA/Metal)
                </span>
                <span className="text-[10px] text-[var(--color-text-secondary)]">33 GPU layers offloaded</span>
              </div>

              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Local / Cloud Mode
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block flex items-center gap-1 text-emerald-500">
                  <ShieldCheck className="w-3.5 h-3.5" /> 100% On-Device
                </span>
                <span className="text-[10px] text-[var(--color-text-secondary)]">Airgapped • Zero Cloud</span>
              </div>
            </div>
          </div>

          <div className="flex items-center justify-between pt-1 border-t border-[var(--color-border-subtle)] text-xs">
            <span className="text-[var(--color-text-secondary)] font-mono">
              Profile: <strong className="text-[var(--color-text-primary)]">Balanced</strong> (54°C • 42.8 t/s)
            </span>
            <button
              type="button"
              onClick={() => onNavigate('models')}
              className="text-xs font-semibold text-[var(--color-accent)] hover:underline flex items-center gap-1 font-mono"
            >
              Model Hub <ChevronRight className="w-3 h-3" />
            </button>
          </div>
        </div>

        {/* AREA 3: TODAY */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="flex items-center justify-between">
            <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
              Today
            </h2>

            {/* Quick Filter Switcher */}
            <div className="flex gap-1 p-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono">
              <button
                type="button"
                onClick={() => setActiveTodayTab('tasks')}
                className={`px-2.5 py-1 rounded-lg transition-all ${
                  activeTodayTab === 'tasks'
                    ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                    : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                Tasks ({openCount})
              </button>
              <button
                type="button"
                onClick={() => setActiveTodayTab('reminders')}
                className={`px-2.5 py-1 rounded-lg transition-all ${
                  activeTodayTab === 'reminders'
                    ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                    : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                Reminders ({reminders.length})
              </button>
              <button
                type="button"
                onClick={() => setActiveTodayTab('alarms')}
                className={`px-2.5 py-1 rounded-lg transition-all ${
                  activeTodayTab === 'alarms'
                    ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                    : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                Alarms ({alarms.length})
              </button>
            </div>
          </div>

          {/* Progress Indicator */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-xs font-mono">
              <span className="text-[var(--color-text-secondary)]">
                {completedCount} of {tasks.length} tasks completed
              </span>
              <span className="text-[var(--color-accent)] font-bold">
                {completionPercentage}% Done
              </span>
            </div>
            <ProgressBar value={completionPercentage} size="sm" variant="accent" showValue={false} />
          </div>

          {/* Tab Content Display */}
          <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
            {activeTodayTab === 'tasks' && (
              <>
                {tasks.map((task) => (
                  <div
                    key={task.id}
                    onClick={() => toggleTask(task.id)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(e) => {
                      if (e.key === ' ' || e.key === 'Enter') {
                        e.preventDefault();
                        toggleTask(task.id);
                      }
                    }}
                    className={`p-3 rounded-2xl border flex items-center justify-between gap-3 cursor-pointer transition-all ${
                      task.completed
                        ? 'surface-recessed border-[var(--color-border-subtle)] opacity-70'
                        : 'surface-raised border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40'
                    }`}
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      {task.completed ? (
                        <CheckCircle2 className="w-4 h-4 text-emerald-500 flex-shrink-0" />
                      ) : (
                        <Circle className="w-4 h-4 text-[var(--color-text-muted)] flex-shrink-0" />
                      )}
                      <span
                        className={`text-xs font-medium truncate ${
                          task.completed
                            ? 'line-through text-[var(--color-text-muted)]'
                            : 'text-[var(--color-text-primary)]'
                        }`}
                      >
                        {task.title}
                      </span>
                    </div>
                    <span className="text-[10px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
                      {task.time}
                    </span>
                  </div>
                ))}
              </>
            )}

            {activeTodayTab === 'reminders' && (
              <>
                {reminders.map((rem) => (
                  <div
                    key={rem.id}
                    className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <Bell className="w-4 h-4 text-amber-500 flex-shrink-0" />
                      <span className="text-xs font-medium text-[var(--color-text-primary)] truncate">
                        {rem.title}
                      </span>
                    </div>
                    <span className="text-[11px] font-mono text-[var(--color-accent)] flex-shrink-0">
                      {rem.time}
                    </span>
                  </div>
                ))}
              </>
            )}

            {activeTodayTab === 'alarms' && (
              <>
                {alarms.map((al) => (
                  <div
                    key={al.id}
                    className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <AlarmClock className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0" />
                      <div>
                        <span className="text-xs font-medium text-[var(--color-text-primary)] block truncate">
                          {al.title}
                        </span>
                        <span className="text-[10px] text-emerald-500 font-mono">
                          Armed • Daily
                        </span>
                      </div>
                    </div>
                    <span className="text-sm font-mono font-bold text-[var(--color-text-primary)] flex-shrink-0">
                      {al.time}
                    </span>
                  </div>
                ))}
              </>
            )}
          </div>
        </div>

        {/* AREA 4: WELLNESS */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="flex items-center justify-between">
            <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
              Wellness
            </h2>
            <Badge variant="glass" size="sm">
              Bluetooth Sync: 10m ago
            </Badge>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {/* Sleep Summary */}
            <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-semibold text-[var(--color-text-secondary)] flex items-center gap-1.5">
                  <MoonStar className="w-3.5 h-3.5 text-indigo-400" /> Sleep
                </span>
                <span className="text-[10px] font-mono text-indigo-400 font-bold">88% score</span>
              </div>
              <div>
                <span className="text-lg font-bold text-[var(--color-text-primary)] font-mono block">
                  7h 48m
                </span>
                <p className="text-[10px] text-[var(--color-text-muted)] font-mono mt-0.5">
                  Deep 1h 45m • REM 2h 10m
                </p>
              </div>
            </div>

            {/* Heart Rate Summary */}
            <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-semibold text-[var(--color-text-secondary)] flex items-center gap-1.5">
                  <Heart className="w-3.5 h-3.5 text-rose-500" /> Heart Rate
                </span>
                <span className="text-[10px] font-mono text-rose-500 font-bold">Resting</span>
              </div>
              <div>
                <span className="text-lg font-bold text-[var(--color-text-primary)] font-mono block">
                  64 <span className="text-xs text-[var(--color-text-muted)]">bpm</span>
                </span>
                <p className="text-[10px] text-[var(--color-text-muted)] font-mono mt-0.5">
                  Daily range: 58 – 114 bpm
                </p>
              </div>
            </div>

            {/* Activity / Steps Summary */}
            <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-semibold text-[var(--color-text-secondary)] flex items-center gap-1.5">
                  <Footprints className="w-3.5 h-3.5 text-emerald-500" /> Activity
                </span>
                <span className="text-[10px] font-mono text-emerald-500 font-bold">84%</span>
              </div>
              <div>
                <span className="text-lg font-bold text-[var(--color-text-primary)] font-mono block">
                  8,420
                </span>
                <p className="text-[10px] text-[var(--color-text-muted)] font-mono mt-0.5">
                  Goal: 10k • 6.2 km • 485 kcal
                </p>
              </div>
            </div>
          </div>

          <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
            <span>Continuous tracking active via connected wearables.</span>
            <button
              type="button"
              onClick={() => onNavigate('health')}
              className="text-xs font-semibold text-[var(--color-accent)] hover:underline flex items-center gap-1 font-mono flex-shrink-0"
            >
              Vitals Detail <ChevronRight className="w-3 h-3" />
            </button>
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 3. QUICK ACTIONS: Tactile Soft UI Actions                  */}
      {/* ========================================================= */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-xs font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
            Tactile Quick Actions
          </span>
          <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
            One-touch workstation execution
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <NeumorphicButton
            variant="primary"
            size="md"
            icon={<Bot className="w-4 h-4 text-white" />}
            onClick={() => onNavigate('assistant')}
            className="w-full justify-center"
          >
            Ask Assistant
          </NeumorphicButton>

          <NeumorphicButton
            size="md"
            icon={<CheckSquare className="w-4 h-4 text-[var(--color-accent)]" />}
            onClick={() => {
              setModalInputTitle('');
              setModalInputTime('');
              setActiveModal('task');
            }}
            className="w-full justify-center"
          >
            Add Task
          </NeumorphicButton>

          <NeumorphicButton
            size="md"
            icon={<Bell className="w-4 h-4 text-amber-500" />}
            onClick={() => {
              setModalInputTitle('');
              setModalInputTime('');
              setActiveModal('reminder');
            }}
            className="w-full justify-center"
          >
            Add Reminder
          </NeumorphicButton>

          <NeumorphicButton
            size="md"
            icon={<AlarmClock className="w-4 h-4 text-purple-400" />}
            onClick={() => {
              setModalInputTitle('');
              setModalInputTime('07:30 AM');
              setActiveModal('alarm');
            }}
            className="w-full justify-center"
          >
            Create Alarm
          </NeumorphicButton>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 4. RECENT ACTIVITY: Chronological Activity Feed            */}
      {/* ========================================================= */}
      <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
              Recent Activity Feed
            </h2>
          </div>
          <span className="text-xs font-mono text-[var(--color-text-muted)]">
            Chronological audit trail
          </span>
        </div>

        <div className="relative pl-6 space-y-4 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-[1.5px] before:bg-[var(--color-border-subtle)]">
          {/* Event 1: task completed */}
          <div className="relative flex items-start justify-between gap-4">
            <span className="absolute -left-6 top-1 w-5 h-5 rounded-full surface-raised border border-emerald-500/40 flex items-center justify-center text-emerald-500">
              <CheckCircle2 className="w-3 h-3" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Task Completed
                </span>
                <Badge variant="success" size="sm">
                  Task
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                Code refactoring check passed — Clean build verified with zero linter errors.
              </p>
            </div>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
              10:15 AM
            </span>
          </div>

          {/* Event 2: health synchronized */}
          <div className="relative flex items-start justify-between gap-4">
            <span className="absolute -left-6 top-1 w-5 h-5 rounded-full surface-raised border border-rose-500/40 flex items-center justify-center text-rose-500">
              <Activity className="w-3 h-3" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Health Synchronized
                </span>
                <Badge variant="glass" size="sm">
                  Telemetry
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                Biometric vitals synchronized via local Bluetooth BLE sync (Heart rate & sleep cycles).
              </p>
            </div>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
              09:42 AM
            </span>
          </div>

          {/* Event 3: alarm triggered */}
          <div className="relative flex items-start justify-between gap-4">
            <span className="absolute -left-6 top-1 w-5 h-5 rounded-full surface-raised border border-amber-500/40 flex items-center justify-center text-amber-500">
              <AlarmClock className="w-3 h-3" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Alarm Triggered
                </span>
                <Badge variant="warning" size="sm">
                  Alarm
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                Morning Briefing & Voice Wakeup alarm triggered successfully via nearfield speaker array.
              </p>
            </div>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
              07:30 AM
            </span>
          </div>

          {/* Event 4: model switched */}
          <div className="relative flex items-start justify-between gap-4">
            <span className="absolute -left-6 top-1 w-5 h-5 rounded-full surface-raised border border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-accent)]">
              <Cpu className="w-3 h-3" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Model Switched
                </span>
                <Badge variant="accent" size="sm">
                  Inference
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                Inference engine switched active context weights to Llama-3.1-8B-Instruct (Q4_K_M).
              </p>
            </div>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
              07:15 AM
            </span>
          </div>

          {/* Event 5: device connected */}
          <div className="relative flex items-start justify-between gap-4">
            <span className="absolute -left-6 top-1 w-5 h-5 rounded-full surface-raised border border-sky-400/40 flex items-center justify-center text-sky-400">
              <HardDrive className="w-3 h-3" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Device Connected
                </span>
                <Badge variant="default" size="sm">
                  Hardware
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                Studio Mic Array (USB-C) connected and calibrated with 48kHz audio buffer.
              </p>
            </div>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
              07:05 AM
            </span>
          </div>

          {/* Event 6: assistant conversation */}
          <div className="relative flex items-start justify-between gap-4">
            <span className="absolute -left-6 top-1 w-5 h-5 rounded-full surface-raised border border-purple-400/40 flex items-center justify-center text-purple-400">
              <Sparkles className="w-3 h-3" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Assistant Conversation
                </span>
                <Badge variant="glass" size="sm">
                  Assistant
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                {activeCharacterName} synthesized morning agenda, ranked 3 urgent tasks, and primed vector store.
              </p>
            </div>
            <span className="text-[11px] font-mono text-[var(--color-text-muted)] flex-shrink-0">
              06:50 AM
            </span>
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 5. INTERACTIVE MODAL FOR QUICK ACTIONS                    */}
      {/* ========================================================= */}
      <Modal
        isOpen={activeModal !== null}
        onClose={() => setActiveModal(null)}
        title={
          activeModal === 'task'
            ? 'Add New Workspace Task'
            : activeModal === 'reminder'
            ? 'Add New Reminder'
            : 'Create New Alarm'
        }
        description={
          activeModal === 'task'
            ? 'Create an operational task to be queued into your daily workstation agenda.'
            : activeModal === 'reminder'
            ? 'Set a tactile audio or visual alert for upcoming focus checkpoints.'
            : 'Configure a local hardware wake alarm and nearfield audio trigger.'
        }
        footer={
          <>
            <NeumorphicButton size="sm" onClick={() => setActiveModal(null)}>
              Cancel
            </NeumorphicButton>
            <NeumorphicButton size="sm" variant="primary" onClick={handleSaveModal}>
              Confirm & Save
            </NeumorphicButton>
          </>
        }
      >
        <div className="space-y-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              {activeModal === 'task'
                ? 'Task Title'
                : activeModal === 'reminder'
                ? 'Reminder Note'
                : 'Alarm Name'}
            </label>
            <TextInput
              value={modalInputTitle}
              onChangeValue={setModalInputTitle}
              placeholder={
                activeModal === 'task'
                  ? 'e.g., Verify GGUF quantizations'
                  : activeModal === 'reminder'
                  ? 'e.g., Hydration check'
                  : 'e.g., Standup meeting'
              }
              autoFocus
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Scheduled Time / Frequency
            </label>
            <TextInput
              value={modalInputTime}
              onChangeValue={setModalInputTime}
              placeholder={
                activeModal === 'task'
                  ? 'e.g., 03:00 PM'
                  : activeModal === 'reminder'
                  ? 'e.g., In 45 minutes'
                  : 'e.g., 07:30 AM'
              }
            />
          </div>
        </div>
      </Modal>
    </div>
  );
};
