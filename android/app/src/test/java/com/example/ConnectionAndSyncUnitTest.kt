package com.example

import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.OfflineFeatureMatrix
import com.example.domain.model.SyncStatus
import com.example.ui.shell.AppViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Comprehensive unit test suite for Batch 12: Offline, Synchronization, and Connection UX.
 */
class ConnectionAndSyncUnitTest {

    private lateinit var appViewModel: AppViewModel

    @Before
    fun setUp() {
        appViewModel = AppViewModel()
    }

    // ==========================================
    // 1. CONNECTION MODES & MOCK STATES
    // ==========================================

    @Test
    fun `connection modes support all 5 required states`() {
        val states = CoreConnectionState.entries.toSet()
        val expectedStates = setOf(
            CoreConnectionState.Local,
            CoreConnectionState.Remote,
            CoreConnectionState.Connecting,
            CoreConnectionState.Reconnecting,
            CoreConnectionState.Offline
        )
        assertEquals(5, states.size)
        assertEquals(expectedStates, states)
    }

    @Test
    fun `isOnline property correctly categorizes connection states`() {
        assertTrue(CoreConnectionState.Local.isOnline)
        assertTrue(CoreConnectionState.Remote.isOnline)
        assertFalse(CoreConnectionState.Connecting.isOnline)
        assertFalse(CoreConnectionState.Reconnecting.isOnline)
        assertFalse(CoreConnectionState.Offline.isOnline)
    }

    @Test
    fun `cycleConnectionState cycles through all 5 states in order`() {
        appViewModel.setConnectionState(CoreConnectionState.Local)
        assertEquals(CoreConnectionState.Local, appViewModel.uiState.value.connectionInfo.state)

        appViewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Remote, appViewModel.uiState.value.connectionInfo.state)

        appViewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Connecting, appViewModel.uiState.value.connectionInfo.state)

        appViewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Reconnecting, appViewModel.uiState.value.connectionInfo.state)

        appViewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Offline, appViewModel.uiState.value.connectionInfo.state)

        appViewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Local, appViewModel.uiState.value.connectionInfo.state)
    }

    // ==========================================
    // 2. OFFLINE CAPABILITY MATRIX
    // ==========================================

    @Test
    fun `offline matrix includes required local functionality`() {
        val availableTitles = OfflineFeatureMatrix.availableOffline.map { it.title }

        assertTrue(availableTitles.any { it.contains("Alarms", ignoreCase = true) })
        assertTrue(availableTitles.any { it.contains("Tasks", ignoreCase = true) })
        assertTrue(availableTitles.any { it.contains("Schedule", ignoreCase = true) })
        assertTrue(availableTitles.any { it.contains("Health", ignoreCase = true) })
        assertTrue(availableTitles.any { it.contains("Settings", ignoreCase = true) })
    }

    @Test
    fun `offline matrix communicates unavailable PC functions`() {
        val unavailableTitles = OfflineFeatureMatrix.unavailableOffline.map { it.title }

        assertTrue(unavailableTitles.any { it.contains("Assistant", ignoreCase = true) })
        assertTrue(unavailableTitles.any { it.contains("Tools", ignoreCase = true) })
        assertTrue(unavailableTitles.any { it.contains("Model", ignoreCase = true) })
    }

    // ==========================================
    // 3. SYNC STATUS & TRANSITIONS
    // ==========================================

    @Test
    fun `sync status supports all 5 required states`() {
        val expectedStatuses = setOf(
            SyncStatus.SYNCHRONIZED,
            SyncStatus.PENDING,
            SyncStatus.CONFLICT,
            SyncStatus.STALE,
            SyncStatus.FAILED
        )
        assertEquals(5, SyncStatus.entries.size)
        assertEquals(expectedStatuses, SyncStatus.entries.toSet())
    }

    @Test
    fun `setSyncStatus and cycleSyncStatus work correctly`() {
        appViewModel.setSyncStatus(SyncStatus.SYNCHRONIZED)
        assertEquals(SyncStatus.SYNCHRONIZED, appViewModel.uiState.value.connectionInfo.syncStatus)

        appViewModel.cycleSyncStatus()
        assertEquals(SyncStatus.PENDING, appViewModel.uiState.value.connectionInfo.syncStatus)

        appViewModel.cycleSyncStatus()
        assertEquals(SyncStatus.CONFLICT, appViewModel.uiState.value.connectionInfo.syncStatus)

        appViewModel.cycleSyncStatus()
        assertEquals(SyncStatus.STALE, appViewModel.uiState.value.connectionInfo.syncStatus)

        appViewModel.cycleSyncStatus()
        assertEquals(SyncStatus.FAILED, appViewModel.uiState.value.connectionInfo.syncStatus)
    }

    @Test
    fun `resolveSyncConflict resolves status back to synchronized`() {
        appViewModel.setSyncStatus(SyncStatus.CONFLICT)
        assertEquals(SyncStatus.CONFLICT, appViewModel.uiState.value.connectionInfo.syncStatus)

        appViewModel.resolveSyncConflict(keepLocal = true)
        assertEquals(SyncStatus.SYNCHRONIZED, appViewModel.uiState.value.connectionInfo.syncStatus)
        assertEquals(0, appViewModel.uiState.value.connectionInfo.pendingChangesCount)
    }

    @Test
    fun `retrySync succeeds when online and marks failed when offline`() {
        appViewModel.setConnectionState(CoreConnectionState.Local)
        appViewModel.setSyncStatus(SyncStatus.PENDING)
        appViewModel.retrySync()
        assertEquals(SyncStatus.SYNCHRONIZED, appViewModel.uiState.value.connectionInfo.syncStatus)

        appViewModel.setConnectionState(CoreConnectionState.Offline)
        appViewModel.retrySync()
        assertEquals(SyncStatus.FAILED, appViewModel.uiState.value.connectionInfo.syncStatus)
    }

    // ==========================================
    // 4. CLOUD FALLBACK & UI STATE CONSTRAINTS
    // ==========================================

    @Test
    fun `cloud fallback is disabled by default adhering to no automatic cloud fallback constraint`() {
        assertFalse(appViewModel.uiState.value.connectionInfo.isCloudFallbackEnabled)
    }

    @Test
    fun `offline capabilities sheet visibility toggles correctly`() {
        assertFalse(appViewModel.uiState.value.showOfflineCapabilitiesSheet)

        appViewModel.toggleOfflineCapabilitiesSheet(true)
        assertTrue(appViewModel.uiState.value.showOfflineCapabilitiesSheet)

        appViewModel.toggleOfflineCapabilitiesSheet(false)
        assertFalse(appViewModel.uiState.value.showOfflineCapabilitiesSheet)
    }

    @Test
    fun `banners can be dismissed and re-enabled on state change`() {
        assertTrue(appViewModel.uiState.value.showConnectionBanner)
        appViewModel.dismissConnectionBanner()
        assertFalse(appViewModel.uiState.value.showConnectionBanner)

        appViewModel.setConnectionState(CoreConnectionState.Offline)
        assertTrue(appViewModel.uiState.value.showConnectionBanner)

        assertTrue(appViewModel.uiState.value.showSyncBanner)
        appViewModel.dismissSyncBanner()
        assertFalse(appViewModel.uiState.value.showSyncBanner)

        appViewModel.setSyncStatus(SyncStatus.FAILED)
        assertTrue(appViewModel.uiState.value.showSyncBanner)
    }
}
