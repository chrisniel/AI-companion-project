import React, { ReactNode } from 'react';
import { AlertTriangle, RefreshCw, Home } from 'lucide-react';
import { NeumorphicButton } from '../ui/NeumorphicButton';

export interface WorkspaceErrorBoundaryProps {
  children: ReactNode;
  onReset?: () => void;
  fallbackTitle?: string;
}

interface WorkspaceErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

interface BaseComponent<P, S> {
  props: P;
  state: S;
  setState(state: Partial<S> | ((prev: S) => Partial<S>), callback?: () => void): void;
}

const ComponentBase = (React.Component || class {}) as unknown as {
  new (props: WorkspaceErrorBoundaryProps): BaseComponent<
    WorkspaceErrorBoundaryProps,
    WorkspaceErrorBoundaryState
  >;
};

export class WorkspaceErrorBoundary extends ComponentBase {
  state: WorkspaceErrorBoundaryState = { hasError: false, error: null };

  constructor(props: WorkspaceErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): WorkspaceErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: unknown): void {
    console.error('WorkspaceErrorBoundary caught error:', error, errorInfo);
  }

  handleRetry = (): void => {
    this.setState({ hasError: false, error: null });
  };

  handleReset = (): void => {
    this.setState({ hasError: false, error: null });
    this.props.onReset?.();
  };

  render(): ReactNode {
    if (this.state.hasError) {
      const errorMessage = this.state.error?.message || 'An unexpected error occurred in this workspace view.';

      return (
        <div className="w-full h-full min-h-[400px] flex items-center justify-center p-6 select-none animate-in fade-in duration-200">
          <div className="max-w-lg w-full surface-elevated border border-rose-500/30 rounded-3xl p-6 sm:p-8 shadow-2xl backdrop-blur-xl text-center space-y-6">
            <div className="w-16 h-16 rounded-2xl bg-rose-500/10 border border-rose-500/30 mx-auto flex items-center justify-center text-rose-400 glow-accent-sm">
              <AlertTriangle className="w-8 h-8 text-rose-500" />
            </div>

            <div className="space-y-2">
              <h2 className="text-lg sm:text-xl font-bold text-[var(--color-text-primary)]">
                {this.props.fallbackTitle || 'Workspace View Crashed'}
              </h2>
              <p className="text-xs sm:text-sm text-[var(--color-text-secondary)] leading-relaxed">
                The application shell and navigation remain functional, but this view encountered an unhandled exception.
              </p>
            </div>

            <div className="p-3.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-left">
              <span className="text-[10px] font-mono uppercase tracking-wider text-rose-400 font-bold block mb-1">
                Error Diagnostics
              </span>
              <p className="text-xs font-mono text-[var(--color-text-primary)] break-all max-h-32 overflow-y-auto">
                {errorMessage}
              </p>
            </div>

            <div className="flex items-center justify-center gap-3 pt-2">
              <NeumorphicButton
                size="sm"
                variant="primary"
                icon={<RefreshCw className="w-3.5 h-3.5" />}
                onClick={this.handleRetry}
              >
                Retry View
              </NeumorphicButton>

              {this.props.onReset && (
                <NeumorphicButton
                  size="sm"
                  variant="secondary"
                  icon={<Home className="w-3.5 h-3.5" />}
                  onClick={this.handleReset}
                >
                  Return to Home
                </NeumorphicButton>
              )}
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
