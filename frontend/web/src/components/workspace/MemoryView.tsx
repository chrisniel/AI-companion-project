import React, { useState, useMemo } from 'react';
import {
  Brain,
  Search,
  Plus,
  Filter,
  Layers,
  Sparkles,
  Archive,
  CheckCircle2,
  Trash2,
  User,
  HeartHandshake,
  BookOpen,
  FolderGit2,
  Calendar,
  Clock,
  ArrowUpDown,
  RefreshCw,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { SearchInput } from '../ui/SearchInput';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { MemoryEntry, MemoryCategory } from '../../types';
import { initialMemoryEntries } from '../../mock/deviceAndMemoryData';
import { MemoryItemCard } from './memory/MemoryItemCard';
import { MemoryEditorModal } from './memory/MemoryEditorModal';
import { MemoryDeleteConfirmModal } from './memory/MemoryDeleteConfirmModal';
import { useTheme } from '../../context/ThemeContext';

type StatusFilter = 'active' | 'archived' | 'all';
type SortOption = 'recent' | 'confidence' | 'category';

export const MemoryView: React.FC = () => {
  const { mode } = useTheme();
  const [memories, setMemories] = useState<MemoryEntry[]>(initialMemoryEntries);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<'All' | MemoryCategory>('All');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('active');
  const [sortBy, setSortBy] = useState<SortOption>('recent');

  // Modal states
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [memoryToEdit, setMemoryToEdit] = useState<MemoryEntry | null>(null);
  const [memoryToDelete, setMemoryToDelete] = useState<MemoryEntry | null>(null);

  // Toast feedback
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  // Category counts calculation
  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = {
      All: memories.length,
      Profile: 0,
      Preference: 0,
      Fact: 0,
      Project: 0,
      Event: 0,
      Temporary: 0,
    };
    memories.forEach((m) => {
      if (counts[m.category] !== undefined) {
        counts[m.category]++;
      }
    });
    return counts;
  }, [memories]);

  // Categories list with icons
  const categoriesList: { id: 'All' | MemoryCategory; label: string; icon: React.ReactNode }[] = [
    { id: 'All', label: 'All Categories', icon: <Layers className="w-3.5 h-3.5" /> },
    { id: 'Profile', label: 'Profile', icon: <User className="w-3.5 h-3.5" /> },
    { id: 'Preference', label: 'Preference', icon: <HeartHandshake className="w-3.5 h-3.5" /> },
    { id: 'Fact', label: 'Fact', icon: <BookOpen className="w-3.5 h-3.5" /> },
    { id: 'Project', label: 'Project', icon: <FolderGit2 className="w-3.5 h-3.5" /> },
    { id: 'Event', label: 'Event', icon: <Calendar className="w-3.5 h-3.5" /> },
    { id: 'Temporary', label: 'Temporary', icon: <Clock className="w-3.5 h-3.5" /> },
  ];

  // Filtering and sorting
  const filteredMemories = useMemo(() => {
    return memories
      .filter((mem) => {
        // Status filter
        if (statusFilter === 'active' && mem.isArchived) return false;
        if (statusFilter === 'archived' && !mem.isArchived) return false;

        // Category filter
        if (selectedCategory !== 'All' && mem.category !== selectedCategory) return false;

        // Search filter
        if (searchQuery.trim()) {
          const q = searchQuery.toLowerCase();
          const matchContent = mem.content.toLowerCase().includes(q);
          const matchSource = mem.source.toLowerCase().includes(q);
          const matchCat = mem.category.toLowerCase().includes(q);
          const matchTags = mem.tags?.some((t) => t.toLowerCase().includes(q));
          return matchContent || matchSource || matchCat || matchTags;
        }

        return true;
      })
      .sort((a, b) => {
        if (sortBy === 'confidence') {
          return b.confidence - a.confidence;
        }
        if (sortBy === 'category') {
          return a.category.localeCompare(b.category);
        }
        // Default: most recent first (mock order preserved / string comparison)
        return b.id.localeCompare(a.id);
      });
  }, [memories, statusFilter, selectedCategory, searchQuery, sortBy]);

  // Handlers for mock controls
  const handleEdit = (memory: MemoryEntry) => {
    setMemoryToEdit(memory);
    setIsEditorOpen(true);
  };

  const handleCreateNew = () => {
    setMemoryToEdit(null);
    setIsEditorOpen(true);
  };

  const handleSaveMemory = (data: Partial<MemoryEntry>) => {
    if (data.id) {
      // Edit existing
      setMemories((prev) =>
        prev.map((m) => (m.id === data.id ? ({ ...m, ...data } as MemoryEntry) : m))
      );
      showToast('Memory record updated.');
    } else {
      // Create new
      const newEntry: MemoryEntry = {
        id: `mem-${Date.now()}`,
        content: data.content || '',
        category: data.category || 'Preference',
        source: data.source || 'Manual Input',
        confidence: data.confidence || 0.95,
        lastUpdated: 'Just now',
        isArchived: false,
        tags: data.tags || [],
      };
      setMemories((prev) => [newEntry, ...prev]);
      showToast('New semantic memory indexed successfully.');
    }
  };

  const handleToggleArchive = (id: string) => {
    setMemories((prev) =>
      prev.map((m) => {
        if (m.id === id) {
          const nextState = !m.isArchived;
          showToast(nextState ? 'Memory archived.' : 'Memory restored to active context.');
          return { ...m, isArchived: nextState };
        }
        return m;
      })
    );
  };

  const handleDeletePrompt = (id: string) => {
    const mem = memories.find((m) => m.id === id);
    if (mem) {
      setMemoryToDelete(mem);
    }
  };

  const handleConfirmDelete = () => {
    if (memoryToDelete) {
      setMemories((prev) => prev.filter((m) => m.id !== memoryToDelete.id));
      showToast('Memory permanently deleted from vector store.');
      setMemoryToDelete(null);
    }
  };

  return (
    <div id="memory-view" className="space-y-6 pb-12">
      {/* Top Header Card */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Brain className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                Long-Term Semantic Memory & Vector Store
              </h1>
              <Badge variant="accent" size="sm">
                bge-large-en-v1.5
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Searchable memory categories across profile facts, preferences, project context, and scheduled events.
            </p>
          </div>
        </div>

        {/* Action button */}
        <div className="flex items-center gap-2">
          <NeumorphicButton
            variant="primary"
            size="md"
            onClick={handleCreateNew}
            icon={<Plus className="w-4 h-4" />}
          >
            Add Memory
          </NeumorphicButton>
        </div>
      </div>

      {/* Stats Summary Strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Indexed Records
          </span>
          <span className="text-lg font-bold text-[var(--color-text-primary)] mt-0.5 block">
            {memories.length}
          </span>
        </div>

        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Active in Context
          </span>
          <span className="text-lg font-bold text-emerald-400 mt-0.5 block">
            {memories.filter((m) => !m.isArchived).length}
          </span>
        </div>

        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Vector Dimension
          </span>
          <span className="text-lg font-bold text-[var(--color-accent)] mt-0.5 block">
            1024-dim
          </span>
        </div>

        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Storage Engine
          </span>
          <span className="text-lg font-bold text-[var(--color-text-primary)] mt-0.5 block truncate">
            sqlite-vec (HNSW)
          </span>
        </div>
      </div>

      {/* Search and Filter Controls */}
      <div className="p-4 sm:p-5 rounded-3xl surface-base border border-[var(--color-border-subtle)] space-y-4">
        {/* Row 1: Search Bar + Status Toggle + Sort Option */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex-1 max-w-lg">
            <SearchInput
              value={searchQuery}
              onChangeValue={setSearchQuery}
              placeholder="Search across memory content, source, category, tags..."
              sizeVariant="md"
            />
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            {/* Status Filter Toggle */}
            <div className="p-1 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center gap-1 text-xs">
              <button
                onClick={() => setStatusFilter('active')}
                className={`px-3 py-1.5 rounded-xl font-semibold transition-all cursor-pointer ${
                  statusFilter === 'active'
                    ? 'surface-raised text-[var(--color-text-primary)] shadow-xs'
                    : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]'
                }`}
              >
                Active ({memories.filter((m) => !m.isArchived).length})
              </button>
              <button
                onClick={() => setStatusFilter('archived')}
                className={`px-3 py-1.5 rounded-xl font-semibold transition-all cursor-pointer ${
                  statusFilter === 'archived'
                    ? 'surface-raised text-[var(--color-text-primary)] shadow-xs'
                    : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]'
                }`}
              >
                Archived ({memories.filter((m) => m.isArchived).length})
              </button>
              <button
                onClick={() => setStatusFilter('all')}
                className={`px-3 py-1.5 rounded-xl font-semibold transition-all cursor-pointer ${
                  statusFilter === 'all'
                    ? 'surface-raised text-[var(--color-text-primary)] shadow-xs'
                    : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]'
                }`}
              >
                All
              </button>
            </div>

            {/* Sort Selector */}
            <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)]">
              <ArrowUpDown className="w-3.5 h-3.5" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortOption)}
                style={{ colorScheme: mode }}
                className="bg-transparent text-[var(--color-text-primary)] font-medium focus:outline-none cursor-pointer"
              >
                <option value="recent" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>
                  Recently Updated
                </option>
                <option value="confidence" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>
                  Highest Confidence
                </option>
                <option value="category" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>
                  Category
                </option>
              </select>
            </div>
          </div>
        </div>

        {/* Row 2: Searchable Memory Categories Pills */}
        <div className="pt-2 border-t border-[var(--color-border-subtle)]">
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
            {categoriesList.map((cat) => {
              const isSelected = selectedCategory === cat.id;
              const count = categoryCounts[cat.id] || 0;
              return (
                <button
                  key={cat.id}
                  onClick={() => setSelectedCategory(cat.id)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-2 whitespace-nowrap transition-all duration-150 cursor-pointer ${
                    isSelected
                      ? 'surface-raised text-[var(--color-text-primary)] border border-[var(--color-accent)]/60 shadow-xs'
                      : 'surface-base text-[var(--color-text-secondary)] border border-[var(--color-border-subtle)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  <span className={isSelected ? 'text-[var(--color-accent)]' : 'text-[var(--color-text-muted)]'}>
                    {cat.icon}
                  </span>
                  <span>{cat.label}</span>
                  <span
                    className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                      isSelected
                        ? 'bg-[var(--color-accent)]/20 text-[var(--color-accent)]'
                        : 'surface-recessed text-[var(--color-text-muted)]'
                    }`}
                  >
                    {count}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Feedback Toast */}
      {toastMessage && (
        <div className="px-4 py-2.5 rounded-2xl surface-recessed border border-emerald-500/30 text-xs text-emerald-400 flex items-center gap-2 animate-fadeIn">
          <CheckCircle2 className="w-4 h-4" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Memory Entries List (Highly readable interface without heavy neumorphism) */}
      <div className="space-y-3.5">
        {filteredMemories.length > 0 ? (
          filteredMemories.map((mem) => (
            <MemoryItemCard
              key={mem.id}
              memory={mem}
              onEdit={handleEdit}
              onToggleArchive={handleToggleArchive}
              onDelete={handleDeletePrompt}
            />
          ))
        ) : (
          <div className="p-10 rounded-3xl surface-base border border-[var(--color-border-subtle)] text-center space-y-3">
            <Brain className="w-8 h-8 text-[var(--color-text-muted)] mx-auto opacity-50" />
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              No matching memories found
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] max-w-sm mx-auto">
              No memory records matched category "{selectedCategory}" with query "{searchQuery}".
            </p>
            <NeumorphicButton
              size="sm"
              variant="secondary"
              onClick={() => {
                setSearchQuery('');
                setSelectedCategory('All');
                setStatusFilter('active');
              }}
            >
              Reset Filters
            </NeumorphicButton>
          </div>
        )}
      </div>

      {/* Modals for Edit / Create and Delete Confirmation */}
      <MemoryEditorModal
        isOpen={isEditorOpen}
        onClose={() => {
          setIsEditorOpen(false);
          setMemoryToEdit(null);
        }}
        onSave={handleSaveMemory}
        memoryToEdit={memoryToEdit}
      />

      <MemoryDeleteConfirmModal
        isOpen={!!memoryToDelete}
        onClose={() => setMemoryToDelete(null)}
        onConfirm={handleConfirmDelete}
        memory={memoryToDelete}
      />
    </div>
  );
};
