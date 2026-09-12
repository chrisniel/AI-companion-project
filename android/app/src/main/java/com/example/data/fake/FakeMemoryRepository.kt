package com.example.data.fake

import com.example.domain.model.MemoryCategory
import com.example.domain.model.MemoryItem
import com.example.domain.repository.MemoryRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.UUID

/**
 * In-memory repository implementing Mobile Memory features for Local AI Core (Batch 10).
 * Pre-populates readable, human-friendly memory records across all 6 categories.
 */
class FakeMemoryRepository : MemoryRepository {

    private val initialMemories = listOf(
        MemoryItem(
            id = "mem_profile_01",
            title = "Primary User Profile",
            content = "Software Architect and AI researcher focusing on privacy-first edge intelligence. Prefers concise, highly structured technical summaries and direct action over verbose chatter.",
            category = MemoryCategory.PROFILE,
            tags = listOf("Identity", "Architect", "Primary"),
            createdAt = "Sep 01, 2026",
            updatedAt = "Sep 08, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_pref_01",
            title = "Kotlin & Compose Code Style",
            content = "Always write clean Kotlin with Jetpack Compose using the Soft Glass theme tokens. Adhere to Material Design 3 guidelines with standard 8.dp grid spacing and accessible touch targets.",
            category = MemoryCategory.PREFERENCE,
            tags = listOf("Compose", "M3", "CodeStyle"),
            createdAt = "Sep 02, 2026",
            updatedAt = "Sep 07, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_pref_02",
            title = "Voice Synthesis Audio Pitch",
            content = "Prefers Aura Contralto (pitch 1.0x, warm & supportive timbre) for morning briefings and Nexus Tenor for quick technical diagnostic confirmations.",
            category = MemoryCategory.PREFERENCE,
            tags = listOf("Voice", "Audio", "Characters"),
            createdAt = "Sep 04, 2026",
            updatedAt = "Sep 05, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_fact_01",
            title = "Home Lab Private LAN Topology",
            content = "Local AI Core PC host is reachable over local private Wi-Fi via mDNS discovery. All outbound analytics are disabled at the firewall layer.",
            category = MemoryCategory.FACT,
            tags = listOf("Network", "LAN", "Privacy"),
            createdAt = "Aug 28, 2026",
            updatedAt = "Sep 01, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_project_01",
            title = "Local AI Android Companion",
            content = "Developing an edge-first companion application with Soft Glass aesthetic. Phase 1 focused on Core Shell and Voice Mode; Phase 2 expands to Tasks, Health, Characters, Models, Devices, and Memory.",
            category = MemoryCategory.PROJECT,
            tags = listOf("Android", "LocalAI", "Sprint2026"),
            createdAt = "Aug 20, 2026",
            updatedAt = "Sep 09, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_event_01",
            title = "Quantized Model Benchmark Sprint",
            content = "Scheduled evaluation of Llama 3.1 8B Q4_K_M vs Q5_K_M on Qualcomm Hexagon NPU. Target token rate: minimum 18 tokens per second on local hardware.",
            category = MemoryCategory.EVENT,
            tags = listOf("Benchmark", "NPU", "Evaluation"),
            createdAt = "Sep 06, 2026",
            updatedAt = "Sep 09, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_temp_01",
            title = "Ephemeral Companion Channel",
            content = "Internal channel bound to local node for encrypted streaming chunk telemetry during assistant interaction. Synchronized over private peer mesh.",
            category = MemoryCategory.TEMPORARY,
            tags = listOf("Channel", "Telemetry", "ExpiresSoon"),
            createdAt = "Sep 10, 2026",
            updatedAt = "Sep 10, 2026",
            isArchived = false
        ),
        MemoryItem(
            id = "mem_archived_01",
            title = "Legacy Companion Node Link",
            content = "Historical pairing token for local test node. Superseded by Local AI Core private peer mesh. Retained for historical reference.",
            category = MemoryCategory.FACT,
            tags = listOf("Legacy", "Archived", "Pairing"),
            createdAt = "Jul 15, 2026",
            updatedAt = "Aug 01, 2026",
            isArchived = true
        )
    )

    private val _memories = MutableStateFlow(initialMemories)
    override val memories: StateFlow<List<MemoryItem>> = _memories.asStateFlow()

    override fun searchMemories(query: String, category: MemoryCategory?, showArchived: Boolean): List<MemoryItem> {
        val q = query.trim().lowercase()
        return _memories.value.filter { item ->
            val matchesArchive = item.isArchived == showArchived
            val matchesCategory = category == null || item.category == category
            val matchesQuery = q.isEmpty() ||
                    item.title.lowercase().contains(q) ||
                    item.content.lowercase().contains(q) ||
                    item.tags.any { it.lowercase().contains(q) }
            matchesArchive && matchesCategory && matchesQuery
        }
    }

    override fun getMemory(id: String): MemoryItem? {
        return _memories.value.find { it.id == id }
    }

    override fun saveMemory(item: MemoryItem) {
        _memories.update { current ->
            val index = current.indexOfFirst { it.id == item.id }
            if (index >= 0) {
                current.toMutableList().apply { set(index, item) }
            } else {
                listOf(item) + current
            }
        }
    }

    override fun toggleArchive(id: String) {
        _memories.update { current ->
            current.map { item ->
                if (item.id == id) {
                    item.copy(isArchived = !item.isArchived)
                } else item
            }
        }
    }

    override fun deleteMemory(id: String) {
        _memories.update { current ->
            current.filterNot { it.id == id }
        }
    }
}
