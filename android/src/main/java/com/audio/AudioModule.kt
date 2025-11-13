package com.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import androidx.core.net.toUri
import kotlin.math.*
import kotlin.random.Random
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

@ReactModule(name = AudioModule.NAME)
class AudioModule(reactContext: ReactApplicationContext) :
  NativeAudioSpec(reactContext) {

  private var mediaPlayer: MediaPlayer? = null

  // Metronome properties
  private var metronomeAudioTrack: AudioTrack? = null
  private var metronomeThread: Thread? = null
  private val isMetronomeRunning = AtomicBoolean(false)
  private val metronomeBPM = AtomicReference(60.0)
  private val metronomeVolume = AtomicReference(0.5)
  private val currentBeat = AtomicInteger(0)
  private val sampleRate = 44100
  
  // Pre-generated click sounds (as 16-bit PCM for better compatibility)
  private var tickSound: ByteArray? = null
  private var tockSound: ByteArray? = null

  override fun getName(): String {
    return NAME
  }

  override fun play(input: String, isResource: Boolean, promise: Promise) {
    try {
      mediaPlayer?.release()
      mediaPlayer = MediaPlayer().apply {
        if (isResource) {
          val resourceId = reactApplicationContext.resources.getIdentifier(
            input, "raw", reactApplicationContext.packageName
          )
          if (resourceId == 0) {
            throw IllegalArgumentException("Resource not found: $input")
          }
          val resolvedUri =
            "android.resource://${reactApplicationContext.packageName}/$resourceId".toUri()
          setDataSource(reactApplicationContext, resolvedUri)
        } else
          setDataSource(input)
        prepare()
        setOnCompletionListener {
          release()
          mediaPlayer = null
          promise.resolve(null)
        }
        setOnErrorListener { _, what, extra ->
          release()
          mediaPlayer = null
          promise.reject("Error", "Playback error: code $what, extra $extra")
          true
        }
        start()
      }
    } catch (e: Exception) {
      mediaPlayer?.release()
      mediaPlayer = null
      promise.reject("Error", "Failed to play audio: ${e.message}")
    }
  }

  override fun pause() {
    mediaPlayer?.pause()
  }

  override fun resume() {
    mediaPlayer?.start()
  }

  override fun stop() {
    mediaPlayer?.stop()
    mediaPlayer?.release()
    mediaPlayer = null
  }

  override fun startMetronome(bpm: Double, volume: Double) {
    if (isMetronomeRunning.get()) {
      stopMetronome()
    }

    metronomeBPM.set(bpm)
    metronomeVolume.set(volume)
    currentBeat.set(0)
    isMetronomeRunning.set(true)

    // Pre-generate tick and tock sounds
    android.util.Log.d("Metronome", "Generating click sounds...")
    generateClickSounds(volume)
    android.util.Log.d("Metronome", "Click sounds generated: tick=${tickSound?.size}, tock=${tockSound?.size}")

    val bufferSize = AudioTrack.getMinBufferSize(
      sampleRate,
      AudioFormat.CHANNEL_OUT_MONO,
      AudioFormat.ENCODING_PCM_16BIT
    )
    
    android.util.Log.d("Metronome", "Min buffer size: $bufferSize")

    val audioAttributes = AudioAttributes.Builder()
      .setUsage(AudioAttributes.USAGE_MEDIA)
      .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
      .setFlags(AudioAttributes.FLAG_LOW_LATENCY)
      .build()

    val audioFormat = AudioFormat.Builder()
      .setSampleRate(sampleRate)
      .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
      .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
      .build()

    try {
      // Use a smaller buffer to reduce latency - just enough to prevent underruns
    val minBufferBytes = bufferSize * 2
    val desiredBufferBytes = (sampleRate * 2 * 0.2).toInt() // 200ms of 16-bit mono audio for low latency
    
    metronomeAudioTrack = AudioTrack.Builder()
        .setAudioAttributes(audioAttributes)
        .setAudioFormat(audioFormat)
        .setBufferSizeInBytes(maxOf(minBufferBytes, desiredBufferBytes))
        .setTransferMode(AudioTrack.MODE_STREAM)
        .build()
    
    android.util.Log.d("Metronome", "AudioTrack buffer size: ${metronomeAudioTrack?.bufferSizeInFrames} frames")

      // Set volume - use setVolume with float (0.0 to 1.0) instead of deprecated method
      val volumeResult = metronomeAudioTrack?.setVolume(volume.toFloat())
      android.util.Log.d("Metronome", "Set volume result: $volumeResult, requested=$volume")
      
      // Also try the stream volume as fallback
      try {
        val audioManager = reactApplicationContext.getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
        val currentVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
        val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
        android.util.Log.d("Metronome", "System volume: $currentVolume/$maxVolume")
      } catch (e: Exception) {
        android.util.Log.w("Metronome", "Could not get system volume: ${e.message}")
      }
      
      val playState = metronomeAudioTrack?.play()
      android.util.Log.d("Metronome", "AudioTrack play() returned: $playState, state=${metronomeAudioTrack?.playState}")
      
      if (metronomeAudioTrack?.playState != AudioTrack.PLAYSTATE_PLAYING) {
        android.util.Log.e("Metronome", "AudioTrack failed to start playing! State: ${metronomeAudioTrack?.playState}")
        // Try to start again
        metronomeAudioTrack?.play()
        android.util.Log.d("Metronome", "Retried play(), state=${metronomeAudioTrack?.playState}")
      }
    } catch (e: Exception) {
      android.util.Log.e("Metronome", "Error creating AudioTrack: ${e.message}", e)
      isMetronomeRunning.set(false)
      return
    }

    // Pre-fill buffer with silence to prevent underruns
    val silenceBuffer = ByteArray(bufferSize * 2) // 2 buffer sizes of silence
    
    // Pre-fill buffer BEFORE starting thread to ensure AudioTrack is ready
    try {
      metronomeAudioTrack?.write(silenceBuffer, 0, silenceBuffer.size, AudioTrack.WRITE_BLOCKING)
      android.util.Log.d("Metronome", "Pre-filled buffer with ${silenceBuffer.size} bytes of silence")
    } catch (e: Exception) {
      android.util.Log.e("Metronome", "Error pre-filling buffer: ${e.message}")
    }
    
    // Play first beat immediately (no delay)
    val isTick = (currentBeat.get() % 2 == 0)
    val firstClickSound = if (isTick) tickSound else tockSound
    if (firstClickSound != null && metronomeAudioTrack != null) {
      try {
        var totalWritten = 0
        while (totalWritten < firstClickSound.size) {
          val bytesWritten = metronomeAudioTrack?.write(
            firstClickSound, 
            totalWritten, 
            firstClickSound.size - totalWritten, 
            AudioTrack.WRITE_BLOCKING
          ) ?: 0
          if (bytesWritten <= 0) break
          totalWritten += bytesWritten
        }
        currentBeat.incrementAndGet()
        android.util.Log.d("Metronome", "Played first beat immediately")
      } catch (e: Exception) {
        android.util.Log.e("Metronome", "Error playing first beat: ${e.message}")
      }
    }
    
    // Use a more reliable timing approach with nanoTime for precision
    metronomeThread = Thread {
      // Set thread priority to maximum for better timing precision
      android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
      android.util.Log.d("Metronome", "Thread started, BPM=$bpm")
      
      // Record the actual start time using nanoTime for better precision
      val startTimeNanos = System.nanoTime()
      var lastBeatTimeNanos = startTimeNanos
      var lastBPM = bpm
      val beatIntervalNanos = (60.0 / bpm * 1_000_000_000).toLong()
      var nextBeatTimeNanos = startTimeNanos + beatIntervalNanos // Next beat after one interval (first beat already played)
      
      while (isMetronomeRunning.get()) {
        val currentTimeNanos = System.nanoTime()
        val currentBPM = metronomeBPM.get()
        
        // If BPM changed, recalculate nextBeatTime immediately based on elapsed time
        if (currentBPM != lastBPM) {
          if (currentTimeNanos < nextBeatTimeNanos) {
            // We're between beats - recalculate proportionally
            val elapsedSinceLastBeat = (currentTimeNanos - lastBeatTimeNanos) / 1_000_000.0 // Convert to ms
            val oldInterval = (60.0 / lastBPM * 1000)
            val newInterval = (60.0 / currentBPM * 1000)
            
            // Proportionally adjust: if we're X% through old interval, be X% through new interval
            val progressRatio = elapsedSinceLastBeat / oldInterval
            val remainingTime = newInterval * (1.0 - progressRatio)
            
            // Ensure minimum 1ms delay to prevent scheduling beats too soon
            val adjustedRemainingTime = maxOf(1.0, remainingTime)
            nextBeatTimeNanos = currentTimeNanos + (adjustedRemainingTime * 1_000_000).toLong()
            
            android.util.Log.d("Metronome", "BPM changed: $lastBPM -> $currentBPM, recalculating nextBeatTime (elapsed=${elapsedSinceLastBeat}ms, remaining=${adjustedRemainingTime}ms)")
          } else {
            // We're at or past beat time - use new BPM for next interval immediately
            val newIntervalNanos = (60.0 / currentBPM * 1_000_000_000).toLong()
            nextBeatTimeNanos = currentTimeNanos + newIntervalNanos
            android.util.Log.d("Metronome", "BPM changed: $lastBPM -> $currentBPM at beat time, next interval=${newIntervalNanos / 1_000_000}ms")
          }
          lastBPM = currentBPM
        }
        
        // Check if it's time for the next beat
        if (currentTimeNanos >= nextBeatTimeNanos) {
          val isTick = (currentBeat.get() % 2 == 0)
          val clickSound = if (isTick) tickSound else tockSound
          
          android.util.Log.d("Metronome", "Playing beat ${currentBeat.get()}, isTick=$isTick, soundSize=${clickSound?.size} bytes")
          
          if (clickSound != null && metronomeAudioTrack != null) {
            try {
              // Check AudioTrack state before writing
              val trackState = metronomeAudioTrack?.playState
              if (trackState != AudioTrack.PLAYSTATE_PLAYING) {
                android.util.Log.w("Metronome", "AudioTrack not playing! State: $trackState, restarting...")
                metronomeAudioTrack?.stop()
                metronomeAudioTrack?.play()
                // Re-fill buffer after restart
                metronomeAudioTrack?.write(silenceBuffer, 0, minOf(silenceBuffer.size, bufferSize), AudioTrack.WRITE_BLOCKING)
              }
              
              // Write the pre-generated sound (ByteArray for PCM_16BIT)
              var totalWritten = 0
              while (totalWritten < clickSound.size && isMetronomeRunning.get()) {
                val bytesWritten = metronomeAudioTrack?.write(
                  clickSound, 
                  totalWritten, 
                  clickSound.size - totalWritten, 
                  AudioTrack.WRITE_BLOCKING
                ) ?: 0
                
                if (bytesWritten <= 0) {
                  android.util.Log.e("Metronome", "Failed to write audio, bytesWritten=$bytesWritten, state=${metronomeAudioTrack?.playState}")
                  break
                }
                
                totalWritten += bytesWritten
              }
              
              android.util.Log.d("Metronome", "Wrote $totalWritten/${clickSound.size} bytes, trackState=${metronomeAudioTrack?.playState}")
            } catch (e: Exception) {
              android.util.Log.e("Metronome", "Error writing audio: ${e.message}", e)
              e.printStackTrace()
            }
          } else {
            android.util.Log.e("Metronome", "Click sound or AudioTrack is null! sound=${clickSound != null}, track=${metronomeAudioTrack != null}")
          }
          
          currentBeat.incrementAndGet()
          lastBeatTimeNanos = currentTimeNanos
          lastBPM = currentBPM
          
          // Calculate next beat time based on current BPM
          val newBeatIntervalNanos = (60.0 / currentBPM * 1_000_000_000).toLong()
          nextBeatTimeNanos = currentTimeNanos + newBeatIntervalNanos
        } else {
          // Not time for beat yet - write some silence to keep buffer filled
          try {
            val timeUntilBeatMs = (nextBeatTimeNanos - currentTimeNanos) / 1_000_000
            if (timeUntilBeatMs > 50) { // Only write silence if more than 50ms until next beat
              val silenceToWrite = minOf(silenceBuffer.size, (timeUntilBeatMs * sampleRate * 2 / 1000).toInt())
              if (silenceToWrite > 0) {
                metronomeAudioTrack?.write(silenceBuffer, 0, silenceToWrite, AudioTrack.WRITE_NON_BLOCKING)
              }
            }
          } catch (e: Exception) {
            // Ignore errors when writing silence
          }
        }
        
        // Sleep for a short time to avoid busy-waiting
        // Use shorter sleep intervals to be more responsive to BPM changes
        val timeUntilBeatNanos = nextBeatTimeNanos - System.nanoTime()
        val sleepTimeMs = maxOf(1, minOf(2, timeUntilBeatNanos / 1_000_000)) // Max 2ms sleep for responsiveness
        if (sleepTimeMs > 0) {
          try {
            Thread.sleep(sleepTimeMs)
          } catch (e: InterruptedException) {
            // Thread was interrupted (likely due to BPM change), continue loop to check new BPM
            // Don't break - just continue to next iteration to check for BPM changes
            android.util.Log.d("Metronome", "Thread interrupted (likely BPM change), continuing...")
            continue
          }
        }
      }
      
      android.util.Log.d("Metronome", "Thread stopped")
    }

    metronomeThread?.start()
  }
  
  private fun generateClickSounds(volume: Double) {
    val duration = 0.04 // 40ms to cover both noise and tone
    val totalSamples = (duration * sampleRate).toInt()
    
    // Generate tick sound (2400 Hz) as 16-bit PCM
    val tickFloat = FloatArray(totalSamples)
    generateClickBuffer(true, tickFloat, volume)
    tickSound = floatToPCM16(tickFloat)
    
    // Generate tock sound (1600 Hz) as 16-bit PCM
    val tockFloat = FloatArray(totalSamples)
    generateClickBuffer(false, tockFloat, volume)
    tockSound = floatToPCM16(tockFloat)
    
    android.util.Log.d("Metronome", "Converted to PCM16: tick=${tickSound?.size} bytes, tock=${tockSound?.size} bytes")
  }
  
  private fun floatToPCM16(floatArray: FloatArray): ByteArray {
    val byteArray = ByteArray(floatArray.size * 2)
    for (i in floatArray.indices) {
      val sample = (floatArray[i] * 32767.0).toInt().coerceIn(-32768, 32767)
      byteArray[i * 2] = (sample and 0xFF).toByte()
      byteArray[i * 2 + 1] = ((sample shr 8) and 0xFF).toByte()
    }
    return byteArray
  }
  
  private fun generateClickBuffer(isTick: Boolean, buffer: FloatArray, volume: Double) {
    val toneFreq = if (isTick) 2400.0 else 1600.0
    val filterFreq = if (isTick) 2800.0 else 1800.0
    val Q = 12.0
    val duration = 0.03
    
    var maxSample = 0.0
    var minSample = 0.0
    
    for (i in buffer.indices) {
      val t = i.toDouble() / sampleRate
      var sample = 0.0

      // White noise component (30ms duration)
      if (t < duration) {
        val noiseValue = (Random.nextDouble() * 2.0 - 1.0)
        val noiseEnv = noiseEnvelope(t)
        sample += noiseValue * noiseEnv * 0.7
      }

      // Square wave tone component (40ms duration)
      if (t < 0.04) {
        val phase = (t * toneFreq) % 1.0
        val squareWave = if (phase < 0.5) 1.0 else -1.0
        val toneEnv = toneEnvelope(t)
        sample += squareWave * toneEnv * 0.5
      }

      // Apply high-pass filter approximation
      val filterGain = highPassGain(toneFreq, filterFreq, Q)
      sample *= filterGain

      // Apply master volume with headroom
      sample *= volume * 1.2

      // Clamp to prevent clipping
      sample = max(-1.0, min(1.0, sample))
      
      maxSample = max(maxSample, sample)
      minSample = min(minSample, sample)

      buffer[i] = sample.toFloat()
    }
    
    android.util.Log.d("Metronome", "Generated ${if (isTick) "tick" else "tock"} sound: max=$maxSample, min=$minSample, samples=${buffer.size}")
  }


  private fun noiseEnvelope(t: Double): Double {
    // 0 → 0.7 in 1ms, exponential decay to 0.001 in 30ms
    return when {
      t < 0.001 -> 0.7 * (t / 0.001)
      t < 0.03 -> {
        val decayTime = t - 0.001
        val decayDuration = 0.029
        0.7 * exp(-decayTime / decayDuration * ln(0.7 / 0.001))
      }
      else -> 0.0
    }
  }

  private fun toneEnvelope(t: Double): Double {
    // 0 → 0.5 in 2ms, exponential decay to 0.001 in 40ms
    return when {
      t < 0.002 -> 0.5 * (t / 0.002)
      t < 0.04 -> {
        val decayTime = t - 0.002
        val decayDuration = 0.038
        0.5 * exp(-decayTime / decayDuration * ln(0.5 / 0.001))
      }
      else -> 0.0
    }
  }

  private fun highPassGain(freq: Double, filterFreq: Double, Q: Double): Double {
    // Simplified high-pass filter gain approximation
    return if (freq < filterFreq) {
      val ratio = freq / filterFreq
      ratio * ratio * Q * 0.1 // Attenuate below cutoff
    } else {
      1.0 + (Q - 1.0) * 0.1 // Slight boost at resonance
    }
  }

  override fun stopMetronome() {
    android.util.Log.d("Metronome", "Stopping metronome...")
    isMetronomeRunning.set(false)

    // Interrupt the thread to wake it from sleep
    metronomeThread?.interrupt()
    
    try {
      metronomeThread?.join(500) // Wait up to 500ms for thread to finish
    } catch (e: InterruptedException) {
      // Current thread was interrupted, that's okay
      android.util.Log.d("Metronome", "Join interrupted")
    }
    
    metronomeThread = null

    try {
      metronomeAudioTrack?.stop()
      metronomeAudioTrack?.flush()
    } catch (e: Exception) {
      android.util.Log.e("Metronome", "Error stopping AudioTrack: ${e.message}")
    }
    
    try {
      metronomeAudioTrack?.release()
    } catch (e: Exception) {
      android.util.Log.e("Metronome", "Error releasing AudioTrack: ${e.message}")
    }
    
    metronomeAudioTrack = null
    currentBeat.set(0)
    
    android.util.Log.d("Metronome", "Metronome stopped")
  }

  override fun setMetronomeBPM(bpm: Double) {
    metronomeBPM.set(bpm)
    // Interrupt the thread to wake it up immediately so BPM change takes effect faster
    metronomeThread?.interrupt()
  }

  override fun setMetronomeVolume(volume: Double) {
    metronomeVolume.set(volume)
    // Regenerate sounds with new volume if metronome is running
    if (isMetronomeRunning.get()) {
      generateClickSounds(volume)
    }
  }

  companion object {
    const val NAME = "Audio"
  }
}
