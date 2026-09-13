import '@testing-library/jest-dom/vitest';
import React, { useState } from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { WorkspaceErrorBoundary } from '../components/workspace/WorkspaceErrorBoundary';

const ThrowingComponent: React.FC<{ shouldThrow: boolean }> = ({ shouldThrow }) => {
  if (shouldThrow) {
    throw new Error('Simulated crash inside child workspace view');
  }
  return <div data-testid="child-content">Workspace Child View Active</div>;
};

const TestHarness: React.FC<{ onReset?: () => void }> = ({ onReset }) => {
  const [shouldThrow, setShouldThrow] = useState(false);

  return (
    <div>
      <header data-testid="app-header">App Header Still Active</header>
      <nav data-testid="app-nav">App Navigation Still Active</nav>
      <WorkspaceErrorBoundary onReset={onReset} fallbackTitle="Workspace View Crashed">
        <ThrowingComponent shouldThrow={shouldThrow} />
      </WorkspaceErrorBoundary>
      <button data-testid="trigger-crash" onClick={() => setShouldThrow(true)}>
        Trigger Crash
      </button>
      <footer data-testid="app-footer">App Shell Footer Active</footer>
    </div>
  );
};

describe('WorkspaceErrorBoundary', () => {
  let originalConsoleError: typeof console.error;

  beforeEach(() => {
    originalConsoleError = console.error;
    console.error = vi.fn(); // Suppress React error boundary noise in test output
  });

  afterEach(() => {
    console.error = originalConsoleError;
  });

  it('renders child content normally when no error occurs', () => {
    render(
      <WorkspaceErrorBoundary>
        <div data-testid="normal-view">Normal View</div>
      </WorkspaceErrorBoundary>
    );

    expect(screen.getByTestId('normal-view')).toBeInTheDocument();
    expect(screen.getByText('Normal View')).toBeInTheDocument();
  });

  it('catches child crash without blanking the application shell', () => {
    render(<TestHarness />);

    expect(screen.getByTestId('child-content')).toBeInTheDocument();

    // Trigger crash in child
    fireEvent.click(screen.getByTestId('trigger-crash'));

    // Child is caught by ErrorBoundary
    expect(screen.queryByTestId('child-content')).not.toBeInTheDocument();

    // Application shell outside boundary remains fully functional
    expect(screen.getByTestId('app-header')).toBeInTheDocument();
    expect(screen.getByTestId('app-nav')).toBeInTheDocument();
    expect(screen.getByTestId('app-footer')).toBeInTheDocument();

    // Error recovery card is rendered
    expect(screen.getByText('Workspace View Crashed')).toBeInTheDocument();
    expect(
      screen.getByText(/The application shell and navigation remain functional/i)
    ).toBeInTheDocument();
    expect(
      screen.getByText('Simulated crash inside child workspace view')
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /retry view/i })).toBeInTheDocument();
  });

  it('invokes onReset handler when Return to Home button is clicked', () => {
    const onResetMock = vi.fn();
    render(<TestHarness onReset={onResetMock} />);

    // Trigger crash
    fireEvent.click(screen.getByTestId('trigger-crash'));

    expect(screen.getByText('Workspace View Crashed')).toBeInTheDocument();

    const homeBtn = screen.getByRole('button', { name: /return to home/i });
    expect(homeBtn).toBeInTheDocument();

    fireEvent.click(homeBtn);
    expect(onResetMock).toHaveBeenCalledTimes(1);
  });

  it('clears error state when Retry View button is clicked', () => {
    let throwError = true;
    const ConditionalThrower = () => {
      if (throwError) {
        throw new Error('Transient error');
      }
      return <div>Recovered Child Content</div>;
    };

    render(
      <WorkspaceErrorBoundary>
        <ConditionalThrower />
      </WorkspaceErrorBoundary>
    );

    expect(screen.getByText('Workspace View Crashed')).toBeInTheDocument();

    // Now make child non-throwing and click retry
    throwError = false;
    fireEvent.click(screen.getByRole('button', { name: /retry view/i }));

    expect(screen.getByText('Recovered Child Content')).toBeInTheDocument();
  });
});
