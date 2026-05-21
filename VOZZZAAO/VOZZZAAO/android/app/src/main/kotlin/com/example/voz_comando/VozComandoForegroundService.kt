package com.example.voz_comando

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.NotificationCompat

class VozComandoForegroundService : Service() {

    private var speechRecognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var wakeWords = listOf("ei bruno", "e bruno", "oi bruno", "ok bruno", "bruno")
    private var isListening = false
    private var isWakeWordDetected = false
    private var userWakeWord = "bruno"

    companion object {
        const val CHANNEL_ID = "voz_comando_wake"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "voz_comando.STOP_WAKE"
        const val EXTRA_COMMAND = "wake_command"

        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra("wake_word")?.let { word ->
            userWakeWord = word
            wakeWords = listOf("ei $word", "e $word", "oi $word", "ok $word", word)
        }
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }
        if (!isListening) {
            startWakeListening()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        stopSpeechRecognition()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Wake Word - Bruno",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Escutando 'Ei Bruno' em segundo plano"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, VozComandoForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bruno está escutando")
            .setContentText("Diga 'Ei Bruno' + comando")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Parar", stopPendingIntent)
            .build()
    }

    private fun startWakeListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: android.os.Bundle?) {
                    isListening = true
                    isWakeWordDetected = false
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    isListening = false
                }
                override fun onError(error: Int) {
                    isListening = false
                    handler.postDelayed({ restartListening() }, 500)
                }
                override fun onResults(results: android.os.Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?: return
                    processResults(matches)
                    restartListening()
                }
                override fun onPartialResults(partialResults: android.os.Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?: return
                    processPartialResults(matches)
                }
                override fun onEvent(eventType: Int, params: android.os.Bundle?) {}
            })
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        speechRecognizer?.startListening(intent)
    }

    private fun processResults(matches: List<String>) {
        val fullText = matches.firstOrNull()?.lowercase() ?: return

        if (!isWakeWordDetected) {
            val detectedWakeWord = wakeWords.firstOrNull { fullText.contains(it) }
            if (detectedWakeWord != null) {
                isWakeWordDetected = true
                val commandText = fullText.substringAfter(detectedWakeWord).trim()
                if (commandText.isNotEmpty()) {
                    openAppAndExecute(commandText)
                } else {
                    updateNotification("Bruno ouviu! Fale o comando...")
                    handler.postDelayed({ restartListening() }, 3000)
                }
            }
        }
    }

    private fun processPartialResults(matches: List<String>) {
        val text = matches.firstOrNull()?.lowercase() ?: return
        if (!isWakeWordDetected) {
            if (wakeWords.any { text.contains(it) }) {
                isWakeWordDetected = true
                updateNotification("Bruno ouviu! Fale o comando...")
            }
        }
    }

    private fun openAppAndExecute(command: String) {
        // Abre o app com o comando como extra
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_COMMAND, command)
        }
        launchIntent?.let { startActivity(it) }

        updateNotification("Executando: $command")
        handler.postDelayed({
            updateNotification("Diga 'Ei Bruno' + comando")
            isWakeWordDetected = false
            restartListening()
        }, 3000)
    }

    private fun restartListening() {
        if (isListening) return
        speechRecognizer?.destroy()
        speechRecognizer = null
        handler.postDelayed({ startWakeListening() }, 300)
    }

    private fun stopSpeechRecognition() {
        isListening = false
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun updateNotification(text: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bruno está escutando")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .build()
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
}
