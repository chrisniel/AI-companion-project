import React, { useState, useMemo, useCallback, useEffect } from 'react';
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
  Loader2,
  AlertCircle,
  WifiOff,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { SearchInput } from '../ui/SearchInput';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { MemoryEntry, MemoryCategory } from '../../types';
import { MemoryItemCard } from './memory/MemoryItemCard';
import { MemoryEditorModal } from './memory/MemoryEditorModal';
import { MemoryDeleteConfirmModal } from './memory/MemoryDeleteConfirmModal';
import { useTheme } from '../../context/ThemeContext';
import { useBackend } from '../../context/BackendContext';
import {
  listMemories,
  createMemory,
  updateMemory,
  deleteMemory,
  MemoryOut,
} from '../../services/api/memoryApi';

function mapMemoryOutToEntry(out: MemoryOut): MemoryEntry {
  let cat: MemoryCategory = 'Fact';
  const lowerCat = out.category?.toLowerCase() || '';
  if (lowerCat === 'preference') cat = 'Preference';
  else if (lowerCat === 'profile' || lowerCat === 'context') cat = 'Profile';
  else if (lowerCat === 'project') cat = 'Project';
  else if (lowerCat === 'event') cat = 'Event';
  else if (lowerCat === 'temporary') cat = 'Temporary';
  else if (lowerCat === 'fact') cat = 'Fact';

  return {
    id: out.id,
    content: out.content,
    category: cat,
    source: out.source_type ? `${out.source_type.charAt(0).toUpperCase()}${out.source_type.slice(1)}` : 'Local AI Runtime',
    confidence: Math.min(1, Math.max(0, out.importance > 1 ? out.importance / 2 : out.importance)),
    lastUpdated: new Date(out.created_at).toLocaleDateString([], {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }),
    isArchived: false,
    tags: [cat.toLowerCase()],
  };
}

type StatusFilter = 'active' | 'archived' | 'all';
type SortOption = 'recent' | 'confidence' | 'category';

export const MemoryView: React.FC = () => {
  const { mode } = useTheme();
  const { isOnline } = useBackend();
  const [memories, setMemories] = useState<MemoryEntry[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<string | null>(null);
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

  const loadLiveMemories = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);
    try {
      const res = await listMemories();
      const mapped = (res.items || []).map(mapMemoryOutToEntry);
      setMemories(mapped);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to connect to memory service';
      setLoadError(msg);
      setMemories([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadLiveMemories();
  }, [loadLiveMemories]);

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
        // Default: most recent first (ID/created comparison)
        return b.id.localeCompare(a.id);
      });
  }, [memories, statusFilter, selectedCategory, searchQuery, sortBy]);

  // Handlers for live memory controls
  const handleEdit = (memory: MemoryEntry) => {
    setMemoryToEdit(memory);
    setIsEditorOpen(true);
  };

  const handleCreateNew = () => {
    setMemoryToEdit(null);
    setIsEditorOpen(true);
  };

  const handleSaveMemory = async (data: Partial<MemoryEntry>) => {
    try {
      let apiCat: 'fact' | 'preference' | 'context' = 'fact';
      if (data.category === 'Preference') apiCat = 'preference';
      else if (data.category === 'Profile') apiCat = 'context';

      if (data.id) {
        await updateMemory(data.id, {
          content: data.content,
          category: apiCat,
        });
        showToast('Memory record updated.');
      } else {
        await createMemory(data.content || '', apiCat);
        showToast('New semantic memory indexed successfully.');
      }
      setIsEditorOpen(false);
      setMemoryToEdit(null);
      await loadLiveMemories();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to save memory record.';
      showToast(`Error: ${msg}`);
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

  const handleConfirmDelete = async () => {
    if (memoryToDelete) {
      try {
        await deleteMemory(memoryToDelete.id);
        showToast('Memory permanently deleted from store.');
        setMemoryToDelete(null);
        await loadLiveMemories();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to delete memory.';
        showToast(`Error: ${msg}`);
      }
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
        {!isOnline && (
          <div className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between gap-3 text-xs text-amber-300">
            <div className="flex items-center gap-2">
              <WifiOff className="w-4 h-4 text-amber-400 flex-shrink-0" />
              <span>
                <strong>Runtime Offline: </strong> Memory query and SQLite FTS5 updates are paused until Local AI Runtime reconnects.
              </span>
            </div>
            <Badge variant="warning" size="sm" className="font-mono text-[10px]">
              Offline
            </Badge>
          </div>
        )}

        {loadError && (
          <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 flex items-center justify-between gap-3 text-xs text-rose-300">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-400 flex-shrink-0" />
              <span>{loadError}</span>
            </div>
            <NeumorphicButton size="xs" variant="secondary" onClick={loadLiveMemories}>
              Retry
            </NeumorphicButton>
          </div>
        )}

        {isLoading ? (
          <div className="p-12 rounded-3xl surface-base border border-[var(--color-border-subtle)] text-center space-y-3">
            <Loader2 className="w-8 h-8 animate-spin text-[var(--color-accent)] mx-auto opacity-75" />
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Querying Local AI Runtime...
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Fetching semantic memory records from SQLite FTS5 store.
            </p>
          </div>
        ) : filteredMemories.length > 0 ? (
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
              {memories.length === 0 ? 'No memory records yet' : 'No matching memories found'}
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] max-w-sm mx-auto">
              {memories.length === 0
                ? "No memories have been stored in the SQLite FTS5 database yet. Click 'Add Memory' above to record a user fact or preference."
                : `No memory records matched category "${selectedCategory}" with query "${searchQuery}".`}
            </p>
            {memories.length > 0 && (
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
            )}
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
