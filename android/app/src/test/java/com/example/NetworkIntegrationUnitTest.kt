package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.data.network.LocalAiRuntimeClient
import com.example.data.network.dto.HealthDto
import com.example.data.network.dto.RemoteTaskDto
import com.example.data.repository.HttpTasksRepository
import com.example.data.repository.SharedPreferencesConnectionRepository
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.MobileTask
import com.example.domain.model.SyncStatus
import com.example.domain.model.TaskPriority
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class NetworkIntegrationUnitTest {

    private lateinit var context: Context
    private lateinit var connectionRepository: SharedPreferencesConnectionRepository

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        connectionRepository = SharedPreferencesConnectionRepository(
            context = context,
            prefsName = "test_connection_prefs_${System.currentTimeMillis()}"
        )
    }

    @Test
    fun `connection repository saves and loads host configuration`() {
        connectionRepository.saveHostConfig("192.168.1.50", 8000, "companion_sec_test_token")

        val info = connectionRepository.connectionInfo.value
        assertEquals("192.168.1.50", info.host)
        assertEquals(8000, info.port)
        assertEquals("companion_sec_test_token", info.token)
        assertEquals("http://192.168.1.50:8000", connectionRepository.getBaseUrl())
        assertEquals("companion_sec_test_token", connectionRepository.getToken())
    }

    @Test
    fun `connection repository strips scheme prefixes from host`() {
        connectionRepository.saveHostConfig("http://10.0.2.2/", 8000, null)
        assertEquals("10.0.2.2", connectionRepository.connectionInfo.value.host)
        assertEquals("http://10.0.2.2:8000", connectionRepository.getBaseUrl())
        assertNull(connectionRepository.getToken())
    }

    @Test
    fun `connection repository updates connection states and latency`() {
        connectionRepository.setConnectionState(CoreConnectionState.Local)
        assertEquals(CoreConnectionState.Local, connectionRepository.connectionInfo.value.state)
        assertEquals("Local LAN Active", connectionRepository.connectionInfo.value.label)

        connectionRepository.updateLatency(15)
        assertEquals(15, connectionRepository.connectionInfo.value.latencyMs)

        connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
        assertEquals(SyncStatus.SYNCHRONIZED, connectionRepository.connectionInfo.value.syncStatus)
    }

    @Test
    fun `http tasks repository performs optimistic local updates`() = runTest {
        val initialTasks = listOf(
            MobileTask(
                id = "task-local-1",
                title = "Initial test task",
                description = "Notes",
                priority = TaskPriority.MEDIUM,
                dueDate = "Today",
                isCompleted = false
            )
        )
        val repository = HttpTasksRepository(
            connectionRepository = connectionRepository,
            runtimeClient = LocalAiRuntimeClient(),
            initialTasks = initialTasks
        )

        assertEquals(1, repository.tasks.value.size)
        assertEquals("Initial test task", repository.tasks.value.first().title)

        // Optimistic toggle
        repository.toggleTaskCompletion("task-local-1")
        assertTrue(repository.tasks.value.first().isCompleted)
        assertNotNull(repository.tasks.value.first().completedAt)

        // Optimistic add
        repository.addNewTask("New live task", "High", "14:00")
        assertEquals(2, repository.tasks.value.size)
        assertEquals("New live task", repository.tasks.value.first().title)
        assertEquals(TaskPriority.HIGH, repository.tasks.value.first().priority)

        // Optimistic delete
        repository.deleteTask("task-local-1")
        assertEquals(1, repository.tasks.value.size)
        assertEquals("New live task", repository.tasks.value.first().title)
    }

    @Test
    fun `http tasks repository handles network failure gracefully by retaining cache`() = runTest {
        val initialTasks = listOf(
            MobileTask(
                id = "cached-task-1",
                title = "Persisted offline task",
                priority = TaskPriority.LOW,
                dueDate = "Today"
            )
        )
        val repository = HttpTasksRepository(
            connectionRepository = connectionRepository,
            initialTasks = initialTasks
        )

        // Attempt refresh against unreachable host
        repository.refreshTasks()

        // Cache must remain intact
        assertEquals(1, repository.tasks.value.size)
        assertEquals("Persisted offline task", repository.tasks.value.first().title)
    }
}
