package me.newlines.kinflow

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity() {
    private var pendingCalendarImportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createReminderNotificationChannel()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "me.newlines.kinflow/notification_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    },
                )
                result.success(true)
            } catch (_: RuntimeException) {
                result.success(false)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "me.newlines.kinflow/invite_sharing",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openInviteShareSheet") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val url = call.argument<String>("url")
            val chooserTitle = call.argument<String>("chooserTitle")
            if (!isSafeInviteUrl(url) || !isSafeChooserTitle(chooserTitle)) {
                result.success(false)
                return@setMethodCallHandler
            }
            try {
                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, url)
                }
                startActivity(Intent.createChooser(sendIntent, chooserTitle))
                result.success(true)
            } catch (_: RuntimeException) {
                result.success(false)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "me.newlines.kinflow/calendar_import",
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickIcalendarFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingCalendarImportResult != null) {
                result.success(mapOf("status" to "unavailable"))
                return@setMethodCallHandler
            }
            try {
                pendingCalendarImportResult = result
                startActivityForResult(
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/calendar"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "text/calendar",
                                "application/ics",
                                "application/octet-stream",
                            ),
                        )
                    },
                    CALENDAR_IMPORT_REQUEST_CODE,
                )
            } catch (_: RuntimeException) {
                pendingCalendarImportResult = null
                result.success(mapOf("status" to "unavailable"))
            }
        }
    }

    @Deprecated("Deprecated in Android; FlutterActivity still forwards this callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CALENDAR_IMPORT_REQUEST_CODE) return
        val result = pendingCalendarImportResult ?: return
        pendingCalendarImportResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(mapOf("status" to "cancelled"))
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.success(mapOf("status" to "failed"))
            return
        }
        try {
            when (val read = readCalendarImport(uri)) {
                is CalendarImportRead.Selected -> result.success(
                    mapOf(
                        "status" to "selected",
                        "displayName" to read.displayName,
                        "content" to read.content,
                    ),
                )
                CalendarImportRead.TooLarge -> result.success(
                    mapOf("status" to "too_large"),
                )
                CalendarImportRead.Failed -> result.success(
                    mapOf("status" to "failed"),
                )
            }
        } catch (_: RuntimeException) {
            result.success(mapOf("status" to "failed"))
        }
    }

    private fun readCalendarImport(uri: Uri): CalendarImportRead {
        val displayName = queryDisplayName(uri) ?: return CalendarImportRead.Failed
        val stream = contentResolver.openInputStream(uri) ?: return CalendarImportRead.Failed
        val output = ByteArrayOutputStream()
        stream.use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size() + count > MAX_CALENDAR_IMPORT_BYTES) {
                    return CalendarImportRead.TooLarge
                }
                output.write(buffer, 0, count)
            }
        }
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val content = try {
            decoder.decode(ByteBuffer.wrap(output.toByteArray())).toString()
        } catch (_: Exception) {
            return CalendarImportRead.Failed
        }
        return CalendarImportRead.Selected(displayName, content)
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        ) ?: return null
        cursor.use {
            if (!it.moveToFirst()) return null
            val column = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column < 0) return null
            val value = it.getString(column)?.trim() ?: return null
            return if (
                value.isNotEmpty() &&
                value.length <= 120 &&
                value.lowercase().endsWith(".ics") &&
                value.none { character ->
                    character.code < 0x20 || character.code == 0x7f
                }
            ) value else null
        }
    }

    private fun isSafeInviteUrl(value: String?): Boolean {
        if (value == null) return false
        val uri = try {
            Uri.parse(value)
        } catch (_: RuntimeException) {
            return false
        }
        val allowedHost = getString(R.string.kinflow_auth_redirect_host).lowercase()
        val pathSegments = uri.pathSegments
        if (uri.scheme != "https" ||
            uri.host?.lowercase() != allowedHost ||
            pathSegments.size != 2 ||
            pathSegments[0] != "invite" ||
            !INVITE_TOKEN_PATTERN.matches(pathSegments[1])
        ) {
            return false
        }
        val canonical = Uri.Builder()
            .scheme("https")
            .authority(allowedHost)
            .appendPath("invite")
            .appendPath(pathSegments[1])
            .build()
            .toString()
        return value == canonical
    }

    private fun isSafeChooserTitle(value: String?): Boolean {
        return value != null &&
            value.isNotBlank() &&
            value.length <= 120 &&
            value.none { character -> character.code < 0x20 || character.code == 0x7f }
    }

    private fun createReminderNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "kinflow_reminders",
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_description)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private companion object {
        const val CALENDAR_IMPORT_REQUEST_CODE = 7314
        const val MAX_CALENDAR_IMPORT_BYTES = 262144
        val INVITE_TOKEN_PATTERN = Regex("^[A-Za-z0-9_-]{20,512}$")
    }

    private sealed interface CalendarImportRead {
        data class Selected(
            val displayName: String,
            val content: String,
        ) : CalendarImportRead

        data object TooLarge : CalendarImportRead
        data object Failed : CalendarImportRead
    }
}
