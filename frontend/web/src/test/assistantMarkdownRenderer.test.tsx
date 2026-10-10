import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { AssistantMarkdownRenderer } from '../components/workspace/assistant/AssistantMarkdownRenderer';

describe('AssistantMarkdownRenderer GFM Table Support', () => {
  it('renders GFM table with headers, alignment, and cells', () => {
    const markdown = `
| Name | Role | Status |
| :--- | :---: | ---: |
| Alice | Admin | Active |
| Bob | Member | Pending |
`;
    const { container } = render(<AssistantMarkdownRenderer content={markdown} />);
    const table = container.querySelector('table');
    expect(table).not.toBeNull();
    expect(screen.getByText('Name')).toBeInTheDocument();
    expect(screen.getByText('Role')).toBeInTheDocument();
    expect(screen.getByText('Status')).toBeInTheDocument();
    expect(screen.getByText('Alice')).toBeInTheDocument();
    expect(screen.getByText('Bob')).toBeInTheDocument();
  });

  it('handles escaped pipes and inline code inside table cells', () => {
    const markdown = `
| Tool | Command | Notes |
| --- | --- | --- |
| Git | \`git log | head\` | Escaped \\| pipe |
`;
    const { container } = render(<AssistantMarkdownRenderer content={markdown} />);
    const table = container.querySelector('table');
    expect(table).not.toBeNull();
    expect(screen.getByText('Git')).toBeInTheDocument();
    expect(screen.getByText('git log | head')).toBeInTheDocument();
    expect(screen.getByText('Escaped | pipe')).toBeInTheDocument();
  });

  it('renders inline formatting inside table cells', () => {
    const markdown = `
| Feature | Status | Link |
| --- | --- | --- |
| **Bold Feature** | *In Progress* | [Docs](https://example.com) |
`;
    const { container } = render(<AssistantMarkdownRenderer content={markdown} />);
    const table = container.querySelector('table');
    expect(table).not.toBeNull();
    expect(screen.getByText('Bold Feature')).toBeInTheDocument();
    expect(screen.getByText('In Progress')).toBeInTheDocument();
    const link = screen.getByRole('link', { name: 'Docs' });
    expect(link).toHaveAttribute('href', 'https://example.com');
  });

  it('ordinary text containing pipes is not treated as a table', () => {
    const markdown = `Run this command in shell: cat file.txt | grep error | sort
And another line of text.`;
    const { container } = render(<AssistantMarkdownRenderer content={markdown} />);
    const table = container.querySelector('table');
    expect(table).toBeNull();
    expect(screen.getByText(/cat file\.txt \| grep error \| sort/)).toBeInTheDocument();
  });

  it('incomplete streaming table does not crash', () => {
    const markdown = '| Header 1 | Header 2 |';
    const { container } = render(<AssistantMarkdownRenderer content={markdown} />);
    expect(container).toBeInTheDocument();
  });
});
