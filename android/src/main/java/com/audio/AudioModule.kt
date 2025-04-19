package com.audio

import android.media.MediaPlayer
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = AudioModule.NAME)
class AudioModule(reactContext: ReactApplicationContext) :
  NativeAudioSpec(reactContext) {

  private var mediaPlayer: MediaPlayer? = null

  override fun getName(): String {
    return NAME
  }

  override fun play(uri: String, promise: Promise) {
    try {
      mediaPlayer?.release()
      mediaPlayer = MediaPlayer().apply {
        setDataSource(uri)
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

  companion object {
    const val NAME = "Audio"
  }
}
