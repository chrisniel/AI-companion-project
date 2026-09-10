import React from 'react';
import { Monitor, Check, ChevronDown, Sparkles } from 'lucide-react';
import { AssistantPanelMode } from '../../types';

export type DesktopSimulationPreset = 'auto' | 1280 | 1366 | 1440 | 1920;

export interface DesktopSizeSelectorProps {
  currentPreset: DesktopSimulationPreset;
  onSelectPreset: (preset: DesktopSimulationPreset) => void;
  actualWidth: number;
}

export const DESKTOP_PRESETS: {
  id: DesktopSimulationPreset;
  label: string;
  sublabel: string;
  description: string;
  priorityBehavior: string;
}[] = [
  {
    id: 'auto',
    label: 'Auto (Viewport)',
    sublabel: 'Hardware Realtime',
    description: 'Adapts dynamically to the physical window dimensions.',
    priorityBehavior: 'Dynamic space priority based on window.innerWidth',
  },
  {
    id: 1280,
    label: '1280px',
    sublabel: 'Narrow Desktop',
    description: 'Limited width desktop viewport.',
    priorityBehavior: '1. Hide Assistant Panel • 2. Collapse Sidebar to Icons • 3. Preserve Workspace',
  },
  {
    id: 1366,
    label: '1366px',
    sublabel: 'Compact Laptop',
    description: 'Standard compact laptop display (1366x768).',
    priorityBehavior: '1. Collapse Assistant Panel to Icon Rail • 2. Expand Sidebar • 3. Preserve Workspace',
  },
  {
    id: 1440,
    label: '1440px',
    sublabel: 'Standard Desktop',
    description: 'Comfortable high-density workstation display.',
    priorityBehavior: 'Full sidebar + Expanded Assistant Panel + Full workspace',
  },
  {
    id: 1920,
    label: '1920px',
    sublabel: 'Ultra-Wide HD',
    description: 'Full 1080p widescreen workstation canvas.',
    priorityBehavior: 'Expanded sidebar (w-64) + Full Assistant Panel (w-80) + Max-w-7xl Workspace',
  },
];

export const DesktopSizeSelector: React.FC<DesktopSizeSelectorProps> = ({
  currentPreset,
  onSelectPreset,
  actualWidth,
}) => {
  const [isOpen, setIsOpen] = React.useState(false);
  const dropdownRef = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const activeOption =
    DESKTOP_PRESETS.find((p) => p.id === currentPreset) || DESKTOP_PRESETS[0];

  return (
    <div className="relative inline-block" ref={dropdownRef}>
      {/* Trigger Button */}
      <button
        id="desktop-size-selector-btn"
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-label={`Desktop resolution selector. Currently ${activeOption.label} (${actualWidth}px)`}
        className="px-2.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-mono flex items-center gap-1.5 hover:border-[var(--color-accent)]/40 transition-colors cursor-pointer select-none focus-visible:ring-2 focus-visible:ring-[var(--color-accent)]"
        title="Test desktop widths: 1280, 1366, 1440, 1920"
      >
        <Monitor className="w-3.5 h-3.5 text-[var(--color-accent)]" />
        <span className="hidden xl:inline text-[var(--color-text-secondary)]">Desktop:</span>
        <span className="font-bold text-[var(--color-text-primary)]">
          {currentPreset === 'auto' ? `${actualWidth}px` : `${currentPreset}px`}
        </span>
        <ChevronDown className={`w-3 h-3 text-[var(--color-text-muted)] transition-transform duration-150 ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div
          role="listbox"
          className="absolute right-0 mt-1.5 w-80 rounded-2xl glass-panel-elevated p-2 space-y-1 z-50 animate-in fade-in zoom-in-95 duration-100 shadow-xl border border-[var(--color-border-subtle)]"
        >
          <div className="px-2.5 py-1.5 border-b border-[var(--color-border-subtle)]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-[var(--color-text-primary)]">
                Desktop Space Priority
              </span>
              <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-[var(--color-surface-secondary)] text-[var(--color-accent)] font-semibold">
                Actual: {actualWidth}px
              </span>
            </div>
            <p className="text-[10px] text-[var(--color-text-muted)] mt-0.5">
              Strict desktop preservation: Assistant panel collapses first, then sidebar to icons. Never converts to mobile UI.
            </p>
          </div>

          <div className="space-y-0.5 pt-1">
            {DESKTOP_PRESETS.map((preset) => {
              const isSelected = currentPreset === preset.id;
              return (
                <button
                  key={String(preset.id)}
                  type="button"
                  role="option"
                  aria-selected={isSelected}
                  onClick={() => {
                    onSelectPreset(preset.id);
                    setIsOpen(false);
                  }}
                  className={`w-full text-left px-2.5 py-2 rounded-xl text-xs transition-all flex items-start justify-between gap-2 cursor-pointer ${
                    isSelected
                      ? 'surface-raised text-[var(--color-text-primary)] border border-[var(--color-accent)]/50 shadow-xs'
                      : 'hover:bg-[var(--color-surface-secondary)]/50 text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  <div className="space-y-0.5 min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-[var(--color-text-primary)] font-mono">
                        {preset.label}
                      </span>
                      <span className="text-[10px] text-[var(--color-text-muted)]">
                        {preset.sublabel}
                      </span>
                    </div>
                    <div className="text-[10px] text-[var(--color-text-secondary)]">
                      {preset.description}
                    </div>
                    <div className="text-[9px] font-mono text-[var(--color-accent)]">
                      {preset.priorityBehavior}
                    </div>
                  </div>

                  {isSelected && (
                    <Check className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0 mt-0.5" />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};
