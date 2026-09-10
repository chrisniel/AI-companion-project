import React from 'react';
import {
  Mic,
  Brain,
  Volume2,
  Smile,
  AlertTriangle,
  Flame,
  AlertOctagon,
  Sparkles,
} from 'lucide-react';
import { AvatarSemanticState, CharacterConfig } from '../../../types';

export interface AvatarPresentationProps {
  state: AvatarSemanticState;
  character: CharacterConfig;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  showStateBadge?: boolean;
  className?: string;
  onClick?: () => void;
}

interface StateVisualMeta {
  label: string;
  sublabel: string;
  icon: React.ElementType;
  accentColor: string;
  bgGlow: string;
  animationClass: string;
  waveformProfile: number[];
  expressionSymbol: string;
}

export const STATE_VISUAL_REGISTRY: Record<AvatarSemanticState, StateVisualMeta> = {
  idle: {
    label: 'Idle',
    sublabel: 'Calm baseline • Ready for wake sequence',
    icon: Sparkles,
    accentColor: 'var(--color-accent)',
    bgGlow: 'rgba(59, 130, 246, 0.18)',
    animationClass: 'animate-pulse',
    waveformProfile: [15, 25, 20, 30, 22, 18, 26, 16],
    expressionSymbol: '● ●',
  },
  listening: {
    label: 'Listening',
    sublabel: 'PPG / Mic VAD streaming • Receiving prompt',
    icon: Mic,
    accentColor: '#06b6d4', // Cyan
    bgGlow: 'rgba(6, 182, 212, 0.25)',
    animationClass: 'animate-bounce',
    waveformProfile: [30, 65, 80, 95, 85, 70, 50, 35],
    expressionSymbol: '◉ ◉',
  },
  thinking: {
    label: 'Thinking',
    sublabel: 'Inference pipeline • KV cache processing',
    icon: Brain,
    accentColor: '#8b5cf6', // Purple
    bgGlow: 'rgba(139, 92, 246, 0.28)',
    animationClass: 'animate-spin',
    waveformProfile: [45, 55, 75, 60, 80, 65, 45, 50],
    expressionSymbol: '◎ ◎',
  },
  speaking: {
    label: 'Speaking',
    sublabel: 'Audio synthesis active • Streaming phonemes',
    icon: Volume2,
    accentColor: '#10b981', // Emerald
    bgGlow: 'rgba(16, 185, 129, 0.28)',
    animationClass: 'animate-pulse',
    waveformProfile: [40, 90, 100, 75, 95, 85, 60, 45],
    expressionSymbol: '◠ ◠',
  },
  happy: {
    label: 'Happy',
    sublabel: 'High affinity alignment • Goal completed',
    icon: Smile,
    accentColor: '#f59e0b', // Amber / Gold
    bgGlow: 'rgba(245, 158, 11, 0.3)',
    animationClass: 'animate-bounce',
    waveformProfile: [30, 60, 85, 70, 90, 80, 65, 40],
    expressionSymbol: '^‿^',
  },
  concerned: {
    label: 'Concerned',
    sublabel: 'Biometric anomaly / Guardrail attention',
    icon: AlertTriangle,
    accentColor: '#f97316', // Orange
    bgGlow: 'rgba(249, 115, 22, 0.26)',
    animationClass: 'animate-pulse',
    waveformProfile: [25, 40, 35, 55, 45, 30, 35, 20],
    expressionSymbol: '•_•',
  },
  annoyed: {
    label: 'Annoyed',
    sublabel: 'Resource constraint / High repetition trigger',
    icon: Flame,
    accentColor: '#ef4444', // Red
    bgGlow: 'rgba(239, 68, 68, 0.28)',
    animationClass: 'animate-pulse',
    waveformProfile: [50, 75, 40, 90, 30, 85, 45, 60],
    expressionSymbol: '¬_¬',
  },
  error: {
    label: 'Error',
    sublabel: 'Inference runtime fault • Diagnostics engaged',
    icon: AlertOctagon,
    accentColor: '#e11d48', // Rose
    bgGlow: 'rgba(225, 29, 72, 0.32)',
    animationClass: 'animate-ping',
    waveformProfile: [80, 20, 90, 15, 85, 25, 75, 30],
    expressionSymbol: '×_×',
  },
};

export const AvatarPresentation: React.FC<AvatarPresentationProps> = ({
  state,
  character,
  size = 'md',
  showStateBadge = false,
  className = '',
  onClick,
}) => {
  const visual = STATE_VISUAL_REGISTRY[state] || STATE_VISUAL_REGISTRY.idle;
  const accentColor = character.avatarAccentColor || visual.accentColor;
  const StateIcon = visual.icon;

  // Size configurations
  const sizeMap = {
    sm: {
      container: 'w-12 h-12',
      canvas: 48,
      coreRadius: 12,
      stroke: 1.5,
      iconSize: 'w-3 h-3',
      textSize: 'text-[9px]',
    },
    md: {
      container: 'w-24 h-24',
      canvas: 96,
      coreRadius: 26,
      stroke: 2,
      iconSize: 'w-5 h-5',
      textSize: 'text-xs',
    },
    lg: {
      container: 'w-36 h-36',
      canvas: 144,
      coreRadius: 40,
      stroke: 2.5,
      iconSize: 'w-7 h-7',
      textSize: 'text-sm',
    },
    xl: {
      container: 'w-48 h-48 sm:w-56 sm:h-56',
      canvas: 200,
      coreRadius: 56,
      stroke: 3,
      iconSize: 'w-9 h-9',
      textSize: 'text-base',
    },
  };

  const currentSize = sizeMap[size];
  const center = currentSize.canvas / 2;
  const avatarType = character.avatarType || 'hologram_core';

  return (
    <div
      className={`relative flex flex-col items-center justify-center select-none ${className}`}
      onClick={onClick}
    >
      {/* Outer ambient aura glow */}
      <div
        className={`absolute rounded-full pointer-events-none transition-all duration-700 blur-xl ${
          size === 'sm' ? 'w-16 h-16' : size === 'md' ? 'w-32 h-32' : size === 'lg' ? 'w-48 h-48' : 'w-64 h-64'
        }`}
        style={{
          backgroundImage: `radial-gradient(circle, ${visual.accentColor} 0%, transparent 70%)`,
          opacity: state === 'speaking' ? 0.45 : state === 'listening' ? 0.4 : state === 'thinking' ? 0.35 : 0.22,
        }}
      />

      {/* SVG Procedural Avatar Geometry */}
      <div
        className={`relative ${currentSize.container} rounded-3xl surface-raised border border-[var(--color-border-subtle)] shadow-sm flex items-center justify-center overflow-hidden transition-all duration-500`}
      >
        <svg
          viewBox={`0 0 ${currentSize.canvas} ${currentSize.canvas}`}
          className="w-full h-full"
        >
          <defs>
            <linearGradient id={`avatarGrad-${character.id}`} x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor={visual.accentColor} stopOpacity="0.9" />
              <stop offset="100%" stopColor={accentColor} stopOpacity="0.5" />
            </linearGradient>
            <radialGradient id={`coreGlow-${character.id}`} cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor={visual.accentColor} stopOpacity="0.4" />
              <stop offset="100%" stopColor="transparent" stopOpacity="0" />
            </radialGradient>
          </defs>

          {/* Background Ambient Radial */}
          <circle cx={center} cy={center} r={center - 4} fill={`url(#coreGlow-${character.id})`} />

          {/* Archetype 1: Hologram Core */}
          {avatarType === 'hologram_core' && (
            <g>
              {/* Outer Orbital Ring */}
              <circle
                cx={center}
                cy={center}
                r={currentSize.coreRadius + 8}
                fill="none"
                stroke={visual.accentColor}
                strokeWidth={currentSize.stroke}
                strokeDasharray="4 4"
                className={state === 'thinking' ? 'animate-spin origin-center' : ''}
                opacity={0.65}
              />
              {/* Counter-rotating Inner Ring */}
              <circle
                cx={center}
                cy={center}
                r={currentSize.coreRadius + 2}
                fill="none"
                stroke="var(--color-border-subtle)"
                strokeWidth={1}
                strokeDasharray="8 6"
              />
            </g>
          )}

          {/* Archetype 2: Quantum Prism */}
          {avatarType === 'quantum_prism' && (
            <g className={state === 'thinking' ? 'animate-spin origin-center' : ''}>
              <polygon
                points={`
                  ${center},${center - currentSize.coreRadius - 6}
                  ${center + currentSize.coreRadius + 5},${center + currentSize.coreRadius / 2}
                  ${center - currentSize.coreRadius - 5},${center + currentSize.coreRadius / 2}
                `}
                fill="none"
                stroke={visual.accentColor}
                strokeWidth={currentSize.stroke}
                opacity={0.8}
              />
              <polygon
                points={`
                  ${center},${center + currentSize.coreRadius + 6}
                  ${center + currentSize.coreRadius + 5},${center - currentSize.coreRadius / 2}
                  ${center - currentSize.coreRadius - 5},${center - currentSize.coreRadius / 2}
                `}
                fill="none"
                stroke="var(--color-border-subtle)"
                strokeWidth={1}
                opacity={0.6}
              />
            </g>
          )}

          {/* Archetype 3: Geometric Orb */}
          {avatarType === 'geometric_orb' && (
            <g>
              <ellipse
                cx={center}
                cy={center}
                rx={currentSize.coreRadius + 6}
                ry={currentSize.coreRadius / 2.2}
                fill="none"
                stroke={visual.accentColor}
                strokeWidth={currentSize.stroke}
                strokeDasharray="3 3"
                transform={`rotate(-25 ${center} ${center})`}
                opacity={0.8}
              />
              <ellipse
                cx={center}
                cy={center}
                rx={currentSize.coreRadius + 6}
                ry={currentSize.coreRadius / 2.2}
                fill="none"
                stroke="var(--color-border-subtle)"
                strokeWidth={1}
                transform={`rotate(35 ${center} ${center})`}
                opacity={0.7}
              />
            </g>
          )}

          {/* Archetype 4: Pulse Ring */}
          {avatarType === 'pulse_ring' && (
            <g>
              <circle
                cx={center}
                cy={center}
                r={currentSize.coreRadius + 7}
                fill="none"
                stroke={visual.accentColor}
                strokeWidth={currentSize.stroke}
                opacity={0.4}
                className="animate-pulse"
              />
              <circle
                cx={center}
                cy={center}
                r={currentSize.coreRadius + 3}
                fill="none"
                stroke={visual.accentColor}
                strokeWidth={1.5}
                strokeDasharray="2 3"
              />
            </g>
          )}

          {/* Archetype 5: Sentient Glyph */}
          {avatarType === 'sentient_glyph' && (
            <g>
              <rect
                x={center - currentSize.coreRadius - 4}
                y={center - currentSize.coreRadius - 4}
                width={(currentSize.coreRadius + 4) * 2}
                height={(currentSize.coreRadius + 4) * 2}
                rx="14"
                fill="none"
                stroke={visual.accentColor}
                strokeWidth={currentSize.stroke}
                transform={`rotate(45 ${center} ${center})`}
                opacity={0.7}
              />
            </g>
          )}

          {/* Central Harmonic Spherical Core */}
          <circle
            cx={center}
            cy={center}
            r={currentSize.coreRadius - 2}
            fill={`url(#avatarGrad-${character.id})`}
            className="transition-all duration-300"
          />

          {/* Real-time State Waveform Spectrum Overlay */}
          {size !== 'sm' && (
            <g transform={`translate(${center - 24}, ${center + currentSize.coreRadius - 16})`}>
              {visual.waveformProfile.slice(0, 7).map((height, i) => {
                const barH = (height / 100) * 14;
                return (
                  <rect
                    key={i}
                    x={i * 7}
                    y={14 - barH}
                    width={3.5}
                    height={barH}
                    rx={1.5}
                    fill="var(--color-surface-elevated)"
                    opacity={state === 'speaking' || state === 'listening' ? 0.95 : 0.5}
                  />
                );
              })}
            </g>
          )}

          {/* State Emotion Glyph / Eye Expression */}
          <text
            x={center}
            y={center + (size === 'sm' ? 3 : 5)}
            textAnchor="middle"
            fill="#ffffff"
            fontSize={size === 'sm' ? '11' : size === 'md' ? '16' : size === 'lg' ? '22' : '28'}
            fontFamily="monospace"
            fontWeight="bold"
            className="select-none pointer-events-none drop-shadow-sm"
          >
            {visual.expressionSymbol}
          </text>
        </svg>

        {/* State Indicator Icon Badge (Corner Node) */}
        <div
          className={`absolute bottom-1 right-1 rounded-full p-1 surface-base border border-[var(--color-border-subtle)] shadow-xs transition-colors`}
          style={{ color: visual.accentColor }}
        >
          <StateIcon className={currentSize.iconSize} />
        </div>
      </div>

      {/* Optional State Chip Label */}
      {showStateBadge && (
        <div className="mt-2.5 flex items-center gap-1.5 px-2.5 py-1 rounded-full surface-base border border-[var(--color-border-subtle)] text-xs font-mono shadow-xs">
          <span
            className="w-2 h-2 rounded-full animate-pulse"
            style={{ backgroundColor: visual.accentColor }}
          />
          <span className="font-semibold text-[var(--color-text-primary)]">
            {visual.label}
          </span>
        </div>
      )}
    </div>
  );
};
