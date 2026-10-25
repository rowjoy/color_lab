package com.example.color_lab

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.os.Process
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.sin

private data class Note(val frequency: Double, val durationMs: Int)
private const val GAME_AUDIO_TAG = "ColorLabGameAudio"
private const val WATER_POUR_ASSET = "assets/audio/pour_bottle_clean.mp3"

class MainActivity : FlutterActivity() {
    private val audioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.colorlab/game_audio")
            .setMethodCallHandler { call, result ->
                if (call.method != "play") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val effect = call.argument<String>("effect")
                if (effect == "waterPour") {
                    val amount = (call.argument<Int>("amount") ?: 2).coerceIn(1, 4)
                    val durationMs = (call.argument<Int>("durationMs") ?: 450 + amount * 260)
                        .coerceIn(710, 1_490)
                    audioExecutor.execute { playWaterPour(durationMs) }
                    result.success(null)
                    return@setMethodCallHandler
                }
                val notes = notesFor(effect)
                if (notes == null) {
                    result.error("unknown_effect", "Unsupported game sound", null)
                } else {
                    audioExecutor.execute { play(notes) }
                    result.success(null)
                }
            }
    }

    private fun notesFor(effect: String?): List<Note>? = when (effect) {
        "tap" -> listOf(Note(640.0, 45))
        "invalid" -> listOf(Note(190.0, 90))
        "pour" -> listOf(Note(520.0, 55), Note(430.0, 75), Note(360.0, 95))
        "move" -> listOf(Note(720.0, 55), Note(900.0, 70))
        "shoot" -> listOf(Note(300.0, 55), Note(900.0, 120))
        "stick" -> listOf(Note(260.0, 50), Note(150.0, 90))
        "pop" -> listOf(Note(520.0, 50), Note(800.0, 65), Note(1100.0, 90))
        "fall" -> listOf(Note(720.0, 65), Note(360.0, 150))
        "swap" -> listOf(Note(600.0, 45), Note(880.0, 65))
        "lose" -> listOf(Note(392.0, 110), Note(330.0, 110), Note(262.0, 140), Note(196.0, 220))
        "row" -> listOf(Note(210.0, 100), Note(130.0, 130))
        "win" -> listOf(Note(523.0, 105), Note(659.0, 105), Note(784.0, 105), Note(1047.0, 220))
        else -> null
    }

    private fun play(notes: List<Note>) {
        val sampleRate = 44_100
        val channelMask = AudioFormat.CHANNEL_OUT_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minimumBufferBytes = AudioTrack.getMinBufferSize(sampleRate, channelMask, encoding)
        check(minimumBufferBytes > 0) { "No supported game audio buffer for $sampleRate Hz" }
        val samples = ArrayList<Short>()
        notes.forEach { note ->
            val count = sampleRate * note.durationMs / 1000
            for (i in 0 until count) {
                val t = i.toDouble() / sampleRate
                val attack = (i / (sampleRate * 0.008)).coerceAtMost(1.0)
                val release = ((count - i) / (sampleRate * 0.025)).coerceAtMost(1.0)
                val envelope = minOf(attack, release)
                val wave = sin(2.0 * PI * note.frequency * t) * envelope * 0.60
                samples.add((wave * Short.MAX_VALUE).toInt().toShort())
            }
        }
        playPcm(ShortArray(samples.size) { samples[it] })
    }

    private fun playWaterPour(durationMs: Int) {
        val assetKey = FlutterInjector.instance()
            .flutterLoader()
            .getLookupKeyForAsset(WATER_POUR_ASSET)
        try {
            assets.openFd(assetKey).use { descriptor ->
                val player = MediaPlayer()
                try {
                    player.setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build())
                    player.setDataSource(
                        descriptor.fileDescriptor,
                        descriptor.startOffset,
                        descriptor.length,
                    )
                    player.prepare()
                    player.setVolume(1f, 1f)
                    player.start()
                    val deadline = System.nanoTime() + durationMs * 1_000_000L
                    while (player.isPlaying && System.nanoTime() < deadline) {
                        Thread.sleep(4)
                    }
                    if (player.isPlaying) player.stop()
                } finally {
                    player.release()
                }
            }
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (error: Exception) {
            Log.e(GAME_AUDIO_TAG, "Water-pour recording playback failed", error)
        }
    }

    private fun playPcm(pcm: ShortArray) {
        val sampleRate = 44_100
        val channelMask = AudioFormat.CHANNEL_OUT_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minimumBufferBytes = AudioTrack.getMinBufferSize(sampleRate, channelMask, encoding)
        check(minimumBufferBytes > 0) { "No supported game audio buffer for $sampleRate Hz" }
        val track = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            .setAudioFormat(AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(encoding)
                .setChannelMask(channelMask)
                .build())
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(maxOf(pcm.size * 2, minimumBufferBytes))
            .build()
        try {
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            check(track.state == AudioTrack.STATE_INITIALIZED) { "AudioTrack did not initialize" }
            track.setVolume(1f)
            val written = track.write(pcm, 0, pcm.size, AudioTrack.WRITE_BLOCKING)
            check(written == pcm.size) { "AudioTrack wrote $written of ${pcm.size} samples" }
            track.play()
            val deadline = System.nanoTime() + 2_000_000_000L
            while (track.playbackHeadPosition < written && System.nanoTime() < deadline) {
                Thread.sleep(4)
            }
            track.stop()
            track.release()
        } catch (error: Exception) {
            Log.e(GAME_AUDIO_TAG, "Native game sound playback failed", error)
            track.release()
        }
    }

    override fun onDestroy() {
        audioExecutor.shutdownNow()
        super.onDestroy()
    }
}
