import React from 'react';
import { SectionHeader } from '../ui/SectionHeader';
import { Button } from '../ui/Button';
import { TextInput } from '../ui/TextInput';
import { Badge } from '../ui/Badge';
import { Card } from '../ui/Card';
import { ComponentState } from '../../types';

export const StateMatrixShowcase: React.FC = () => {
  const allStates: {
    id: ComponentState;
    name: string;
    description: string;
    accessibilityNotes: string;
  }[] = [
    {
      id: 'default',
      name: 'Default',
      description: 'Resting initial state ready for user interaction.',
      accessibilityNotes: 'Standard contrast meeting WCAG AA.',
    },
    {
      id: 'hover',
      name: 'Hover',
      description: 'Elevation lift (-0.5px) and subtle brightness shift.',
      accessibilityNotes: 'Cursor pointer feedback + shadow expansion.',
    },
    {
      id: 'focused',
      name: 'Focused',
      description: 'Distinct 2px accent ring outline with 2px offset.',
      accessibilityNotes: 'Visible keyboard focus indicator, never rely on shadow alone.',
    },
    {
      id: 'pressed',
      name: 'Pressed',
      description: 'Depressed inner shadow with subtle physical displacement.',
      accessibilityNotes: 'Active state feedback during mousedown or keypress.',
    },
    {
      id: 'selected',
      name: 'Selected',
      description: 'Accent tint, bold typography, and highlight ring.',
      accessibilityNotes: 'aria-selected / aria-checked attributes synced.',
    },
    {
      id: 'disabled',
      name: 'Disabled',
      description: 'Reduced opacity (45%), pointer events cleared, no shadows.',
      accessibilityNotes: 'aria-disabled="true" and tabIndex="-1".',
    },
    {
      id: 'loading',
      name: 'Loading',
      description: 'Synchronous spinning loader with disabled pointer actions.',
      accessibilityNotes: 'Screen reader aria-busy announcement.',
    },
    {
      id: 'success',
      name: 'Success',
      description: 'Emerald tint with checkmark icon and positive border.',
      accessibilityNotes: 'Color + iconography indicator (not color alone).',
    },
    {
      id: 'warning',
      name: 'Warning',
      description: 'Amber warning border with alert triangle glyph.',
      accessibilityNotes: 'Color + iconography indicator.',
    },
    {
      id: 'error',
      name: 'Error',
      description: 'Rose danger border with alert circle glyph and helper text.',
      accessibilityNotes: 'Clear error description + iconography.',
    },
  ];

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      <SectionHeader
        title="10-State Comprehensive Verification Matrix"
        description="Every component rigorously demonstrates the 10 required interaction and validation states."
        badge={<Badge variant="accent">Accessibility Audited</Badge>}
      />

      <div className="space-y-4">
        {allStates.map((st) => (
          <div
            key={st.id}
            className="p-5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-4"
          >
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <div className="flex items-center gap-3">
                <span className="w-6 h-6 rounded-lg bg-accent-gradient text-white flex items-center justify-center text-xs font-bold font-mono">
                  {st.id[0].toUpperCase()}
                </span>
                <div>
                  <h4 className="text-sm font-bold text-[var(--color-text-primary)]">{st.name}</h4>
                  <p className="text-xs text-[var(--color-text-secondary)]">{st.description}</p>
                </div>
              </div>

              <span className="text-[11px] font-mono text-[var(--color-accent)] bg-[var(--color-accent)]/10 px-2.5 py-1 rounded-md self-start sm:self-auto">
                {st.accessibilityNotes}
              </span>
            </div>

            {/* Live Component Row in this state */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-3 border-t border-[var(--color-border-subtle)] items-center">
              <div>
                <Button variant="primary" state={st.id} size="sm">
                  {st.name} Button
                </Button>
              </div>

              <div>
                <Button variant="secondary" state={st.id} size="sm">
                  {st.name} Secondary
                </Button>
              </div>

              <div>
                <TextInput
                  state={st.id}
                  defaultValue={st.name}
                  placeholder="Input state..."
                  className="text-xs py-1.5"
                />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
