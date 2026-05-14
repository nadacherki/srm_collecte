package com.srm.collecte

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import kotlin.math.max
import kotlin.math.min

class DownloadForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.srm.collecte.DOWNLOAD_START"
        const val ACTION_UPDATE = "com.srm.collecte.DOWNLOAD_UPDATE"
        const val ACTION_FINISH = "com.srm.collecte.DOWNLOAD_FINISH"
        const val ACTION_FAIL = "com.srm.collecte.DOWNLOAD_FAIL"
        const val ACTION_STOP = "com.srm.collecte.DOWNLOAD_STOP"

        private const val CHANNEL_ID = "srm_download_channel"
        private const val CHANNEL_NAME = "Téléchargement SRM"
        private const val NOTIFICATION_ID = 2411
    }

    private var foregroundStarted = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()

        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat(removeNotification = true)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_FINISH -> {
                showFinalNotification(intent, success = true)
                return START_NOT_STICKY
            }
            ACTION_FAIL -> {
                showFinalNotification(intent, success = false)
                return START_NOT_STICKY
            }
            ACTION_START, ACTION_UPDATE, null -> {
                val notification = buildProgressNotification(intent)
                startForegroundCompat(notification)
            }
            else -> {
                val notification = buildProgressNotification(intent)
                startForegroundCompat(notification)
            }
        }

        return START_NOT_STICKY
    }

    private fun showFinalNotification(intent: Intent, success: Boolean) {
        val notification = buildFinalNotification(intent, success)
        if (!foregroundStarted) {
            startForegroundCompat(notification)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
        stopForegroundCompat(removeNotification = false)
        stopSelf()
    }

    private fun buildProgressNotification(intent: Intent?): Notification {
        val title = intent?.getStringExtra("title") ?: "Téléchargement en cours"
        val text = intent?.getStringExtra("text") ?: "Préparation..."
        val progress = safeProgress(intent?.getIntExtra("progress", 0) ?: 0)
        val indeterminate = intent?.getBooleanExtra("indeterminate", false) ?: false

        return notificationBuilder(title, text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress, indeterminate)
            .build()
    }

    private fun buildFinalNotification(intent: Intent?, success: Boolean): Notification {
        val title = intent?.getStringExtra("title")
            ?: if (success) "Téléchargement terminé" else "Téléchargement interrompu"
        val text = intent?.getStringExtra("text")
            ?: if (success) "Les données offline sont à jour." else "Relancez pour reprendre."

        return notificationBuilder(title, text)
            .setSmallIcon(
                if (success) android.R.drawable.stat_sys_download_done
                else android.R.drawable.stat_notify_error
            )
            .setOngoing(false)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun notificationBuilder(title: String, text: String): Notification.Builder {
        val launchIntent = (
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
            ).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setShowWhen(false)
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        foregroundStarted = true
    }

    private fun stopForegroundCompat(removeNotification: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(
                if (removeNotification) STOP_FOREGROUND_REMOVE
                else STOP_FOREGROUND_DETACH,
            )
        } else {
            @Suppress("DEPRECATION")
            stopForeground(removeNotification)
        }
        foregroundStarted = false
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Progression du téléchargement offline SRM"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun safeProgress(value: Int): Int = min(100, max(0, value))

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
}
