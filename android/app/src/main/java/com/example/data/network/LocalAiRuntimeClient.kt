package com.example.data.network

import com.example.data.network.dto.HealthDto
import com.example.data.network.dto.RemoteTaskDto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * HTTP client for communicating with the host PC Local AI Runtime.
 */
class LocalAiRuntimeClient(
    private val okHttpClient: OkHttpClient = defaultClient()
) {

    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    /**
     * Public liveness and reachability check.
     */
    suspend fun checkHealth(baseUrl: String): Result<HealthDto> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/api/v1/health"
        val request = Request.Builder()
            .url(url)
            .get()
            .build()

        val startTime = System.currentTimeMillis()
        try {
            okHttpClient.newCall(request).execute().use { response ->
                val durationMs = (System.currentTimeMillis() - startTime).toInt().coerceAtLeast(1)
                if (!response.isSuccessful) {
                    return@withContext Result.failure(
                        IOException("Health check failed with HTTP ${response.code}")
                    )
                }
                val bodyStr = response.body?.string().orEmpty()
                val json = if (bodyStr.isNotEmpty()) JSONObject(bodyStr) else JSONObject()
                val status = json.optString("status", "healthy")
                Result.success(HealthDto(status = status, latencyMs = durationMs))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Verify device pairing token against runtime.
     */
    suspend fun verifyToken(baseUrl: String, token: String): Result<Boolean> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/api/v1/auth/verify"
        val request = Request.Builder()
            .url(url)
            .post("{}".toRequestBody(jsonMediaType))
            .addHeader("Authorization", "Bearer $token")
            .build()

        try {
            okHttpClient.newCall(request).execute().use { response ->
                when (response.code) {
                    200 -> Result.success(true)
                    401 -> Result.success(false)
                    else -> Result.failure(IOException("Verify token returned HTTP ${response.code}"))
                }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Retrieve all tasks owned by authenticated user.
     */
    suspend fun getTasks(baseUrl: String, token: String?): Result<List<RemoteTaskDto>> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/api/v1/tasks"
        val builder = Request.Builder().url(url).get()
        if (!token.isNullOrBlank()) {
            builder.addHeader("Authorization", "Bearer $token")
        }

        try {
            okHttpClient.newCall(builder.build()).execute().use { response ->
                if (!response.isSuccessful) {
                    return@withContext Result.failure(IOException("List tasks returned HTTP ${response.code}"))
                }
                val bodyStr = response.body?.string().orEmpty()
                val json = JSONObject(bodyStr)
                val itemsArray = json.optJSONArray("items") ?: JSONArray()
                val tasks = mutableListOf<RemoteTaskDto>()
                for (i in 0 until itemsArray.length()) {
                    val item = itemsArray.getJSONObject(i)
                    tasks.add(parseRemoteTask(item))
                }
                Result.success(tasks)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Create a new task on the runtime.
     */
    suspend fun createTask(
        baseUrl: String,
        token: String?,
        title: String,
        notes: String?,
        priority: String,
        dueDate: String? = null,
        category: String? = null,
        reminderMinutesBefore: Int? = null
    ): Result<RemoteTaskDto> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/api/v1/tasks"
        val payload = JSONObject().apply {
            put("title", title)
            if (!notes.isNullOrBlank()) put("notes", notes)
            put("priority", priority.lowercase())
            if (!dueDate.isNullOrBlank()) put("due_date", dueDate)
            if (!category.isNullOrBlank()) put("category", category.lowercase())
            if (reminderMinutesBefore != null) put("reminder_minutes_before", reminderMinutesBefore)
        }

        val builder = Request.Builder()
            .url(url)
            .post(payload.toString().toRequestBody(jsonMediaType))
        if (!token.isNullOrBlank()) {
            builder.addHeader("Authorization", "Bearer $token")
        }

        try {
            okHttpClient.newCall(builder.build()).execute().use { response ->
                if (!response.isSuccessful) {
                    return@withContext Result.failure(IOException("Create task returned HTTP ${response.code}"))
                }
                val bodyStr = response.body?.string().orEmpty()
                val json = JSONObject(bodyStr)
                Result.success(parseRemoteTask(json))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Update an existing task status or fields.
     */
    suspend fun updateTask(
        baseUrl: String,
        token: String?,
        taskId: String,
        status: String? = null,
        title: String? = null,
        priority: String? = null,
        dueDate: String? = null,
        category: String? = null,
        reminderMinutesBefore: Int? = null
    ): Result<RemoteTaskDto> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/api/v1/tasks/$taskId"
        val payload = JSONObject().apply {
            if (status != null) put("status", status)
            if (title != null) put("title", title)
            if (priority != null) put("priority", priority.lowercase())
            if (!dueDate.isNullOrBlank()) put("due_date", dueDate)
            if (!category.isNullOrBlank()) put("category", category.lowercase())
            if (reminderMinutesBefore != null) put("reminder_minutes_before", reminderMinutesBefore)
        }

        val builder = Request.Builder()
            .url(url)
            .patch(payload.toString().toRequestBody(jsonMediaType))
        if (!token.isNullOrBlank()) {
            builder.addHeader("Authorization", "Bearer $token")
        }

        try {
            okHttpClient.newCall(builder.build()).execute().use { response ->
                if (!response.isSuccessful) {
                    return@withContext Result.failure(IOException("Update task returned HTTP ${response.code}"))
                }
                val bodyStr = response.body?.string().orEmpty()
                val json = JSONObject(bodyStr)
                Result.success(parseRemoteTask(json))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Permanently delete a task by ID.
     */
    suspend fun deleteTask(baseUrl: String, token: String?, taskId: String): Result<Boolean> = withContext(Dispatchers.IO) {
        val url = "$baseUrl/api/v1/tasks/$taskId"
        val builder = Request.Builder().url(url).delete()
        if (!token.isNullOrBlank()) {
            builder.addHeader("Authorization", "Bearer $token")
        }

        try {
            okHttpClient.newCall(builder.build()).execute().use { response ->
                if (response.isSuccessful) {
                    Result.success(true)
                } else {
                    Result.failure(IOException("Delete task returned HTTP ${response.code}"))
                }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun parseRemoteTask(json: JSONObject): RemoteTaskDto {
        return RemoteTaskDto(
            id = json.getString("id"),
            ownerId = json.optString("owner_id", "default_user"),
            title = json.getString("title"),
            notes = if (json.has("notes") && !json.isNull("notes")) json.getString("notes") else null,
            status = json.optString("status", "pending"),
            priority = json.optString("priority", "medium"),
            dueDate = if (json.has("due_date") && !json.isNull("due_date")) json.getString("due_date") else null,
            category = json.optString("category", "general"),
            reminderMinutesBefore = if (json.has("reminder_minutes_before") && !json.isNull("reminder_minutes_before")) json.getInt("reminder_minutes_before") else null,
            reminderAt = if (json.has("reminder_at") && !json.isNull("reminder_at")) json.getString("reminder_at") else null,
            isDeleted = json.optBoolean("is_deleted", false),
            createdAt = if (json.has("created_at") && !json.isNull("created_at")) json.getString("created_at") else null,
            updatedAt = if (json.has("updated_at") && !json.isNull("updated_at")) json.getString("updated_at") else null
        )
    }

    companion object {
        fun defaultClient(): OkHttpClient {
            return OkHttpClient.Builder()
                .connectTimeout(5, TimeUnit.SECONDS)
                .readTimeout(8, TimeUnit.SECONDS)
                .writeTimeout(8, TimeUnit.SECONDS)
                .retryOnConnectionFailure(true)
                .build()
        }
    }
}
