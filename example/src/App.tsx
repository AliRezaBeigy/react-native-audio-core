import { useEffect, useRef, useState } from 'react';
import {
  Alert,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import Audio from 'react-native-audio-core';

export default function App() {
  const [status, setStatus] = useState('Ready');
  const [metronomeRunning, setMetronomeRunning] = useState(false);
  const [bpm, setBPM] = useState(60);
  const [volume, setVolume] = useState(0.5);
  const [logs, setLogs] = useState<string[]>([]);
  const beatCountRef = useRef(0);
  const startTimeRef = useRef<number | null>(null);
  const lastBeatTimeRef = useRef<number | null>(null);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  const addLog = (message: string) => {
    const timestamp = new Date().toLocaleTimeString();
    const logMessage = `[${timestamp}] ${message}`;
    console.log(logMessage);
    setLogs((prev) => {
      const newLogs = [logMessage, ...prev.slice(0, 19)]; // Keep last 20 logs
      return newLogs;
    });
  };

  const copyLogs = () => {
    if (logs.length === 0) {
      Alert.alert('No Logs', 'There are no logs to copy.');
      return;
    }
    const logsText = logs.join('\n');
    Clipboard.setString(logsText);
    addLog('📋 Logs copied to clipboard');
    Alert.alert('Copied', 'Logs have been copied to clipboard.');
  };

  // Track beat timing
  useEffect(() => {
    if (metronomeRunning) {
      beatCountRef.current = 0;
      startTimeRef.current = Date.now();
      lastBeatTimeRef.current = null;

      // Simulate beat tracking (since we can't get native beat events)
      // This will help us see if timing is consistent
      intervalRef.current = setInterval(
        () => {
          const now = Date.now();
          const expectedInterval = (60 / bpm) * 1000; // ms per beat

          if (lastBeatTimeRef.current) {
            const actualInterval = now - lastBeatTimeRef.current;
            const drift = actualInterval - expectedInterval;

            beatCountRef.current++;
            const isTick = beatCountRef.current % 2 === 0;
            const beatType = isTick ? 'TICK' : 'TOCK';

            addLog(
              `Beat ${beatCountRef.current} (${beatType}): Expected ${expectedInterval.toFixed(1)}ms, Actual ${actualInterval.toFixed(1)}ms, Drift: ${drift.toFixed(1)}ms`
            );

            lastBeatTimeRef.current = now;
          } else {
            lastBeatTimeRef.current = now;
            beatCountRef.current = 1;
            addLog(`Beat 1 (TICK): Started at ${now}`);
          }
        },
        (60 / bpm) * 1000
      );

      return () => {
        if (intervalRef.current) {
          clearInterval(intervalRef.current);
          intervalRef.current = null;
        }
      };
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
      beatCountRef.current = 0;
      startTimeRef.current = null;
      lastBeatTimeRef.current = null;
      return undefined;
    }
  }, [metronomeRunning, bpm]);

  const playSound = async () => {
    try {
      setStatus('Playing...');
      await Audio.play(require('./win.wav'));
      setStatus('Finished');
    } catch (error) {
      setStatus(`Error: ${error}`);
    }
  };

  const pauseSound = () => {
    Audio.pause();
    setStatus('Paused');
  };

  const resumeSound = () => {
    Audio.resume();
    setStatus('Playing...');
  };

  const stopSound = () => {
    Audio.stop();
    setStatus('Stopped');
  };

  const startMetronome = () => {
    try {
      addLog(
        `🚀 Starting metronome: BPM=${bpm}, Volume=${(volume * 100).toFixed(0)}%`
      );
      console.log('=== METRONOME START ===');
      console.log(`BPM: ${bpm}`);
      console.log(`Volume: ${volume}`);
      console.log(
        `Expected beat interval: ${((60 / bpm) * 1000).toFixed(2)}ms`
      );

      Audio.startMetronome(bpm, volume);
      setMetronomeRunning(true);
      setStatus(`Metronome: ${bpm} BPM`);
      addLog(`✅ Metronome started successfully`);
    } catch (error) {
      const errorMsg = `❌ Metronome Error: ${error}`;
      addLog(errorMsg);
      setStatus(`Metronome Error: ${error}`);
      console.error('Metronome start error:', error);
    }
  };

  const stopMetronome = () => {
    const duration = startTimeRef.current
      ? ((Date.now() - startTimeRef.current) / 1000).toFixed(2)
      : '0';
    addLog(
      `🛑 Stopping metronome (ran for ${duration}s, ${beatCountRef.current} beats)`
    );
    console.log('=== METRONOME STOP ===');
    console.log(`Total beats: ${beatCountRef.current}`);
    console.log(`Duration: ${duration}s`);

    Audio.stopMetronome();
    setMetronomeRunning(false);
    setStatus('Metronome Stopped');
    beatCountRef.current = 0;
    startTimeRef.current = null;
    lastBeatTimeRef.current = null;
  };

  const updateBPM = (newBPM: number) => {
    const clampedBPM = Math.max(40, Math.min(240, newBPM));
    const oldBPM = bpm;
    const oldInterval = ((60 / bpm) * 1000).toFixed(2);
    const newInterval = ((60 / clampedBPM) * 1000).toFixed(2);

    addLog(
      `🎵 BPM change: ${oldBPM} → ${clampedBPM} (interval: ${oldInterval}ms → ${newInterval}ms)`
    );
    console.log('=== BPM CHANGE ===');
    console.log(`Old BPM: ${oldBPM} (${oldInterval}ms interval)`);
    console.log(`New BPM: ${clampedBPM} (${newInterval}ms interval)`);

    setBPM(clampedBPM);
    if (metronomeRunning) {
      try {
        Audio.setMetronomeBPM(clampedBPM);
        setStatus(`Metronome: ${clampedBPM} BPM`);
        addLog(`✅ BPM updated to ${clampedBPM}`);
      } catch (error) {
        const errorMsg = `❌ BPM update error: ${error}`;
        addLog(errorMsg);
        setStatus(`Error: ${error}`);
        console.error('BPM update error:', error);
      }
    }
  };

  const updateVolume = (newVolume: number) => {
    const clampedVolume = Math.max(0, Math.min(1, newVolume));
    const oldVolume = volume;

    addLog(
      `🔊 Volume change: ${(oldVolume * 100).toFixed(0)}% → ${(clampedVolume * 100).toFixed(0)}%`
    );
    console.log('=== VOLUME CHANGE ===');
    console.log(`Old: ${(oldVolume * 100).toFixed(0)}%`);
    console.log(`New: ${(clampedVolume * 100).toFixed(0)}%`);

    setVolume(clampedVolume);
    if (metronomeRunning) {
      try {
        Audio.setMetronomeVolume(clampedVolume);
        addLog(`✅ Volume updated to ${(clampedVolume * 100).toFixed(0)}%`);
      } catch (error) {
        const errorMsg = `❌ Volume update error: ${error}`;
        addLog(errorMsg);
        setStatus(`Error: ${error}`);
        console.error('Volume update error:', error);
      }
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>React Native Audio Core</Text>

      {/* Audio Playback Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Audio Playback</Text>
        <Text style={styles.status}>{status}</Text>
        <View style={styles.buttonContainer}>
          <TouchableOpacity style={styles.button} onPress={playSound}>
            <Text style={styles.buttonText}>Play</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={pauseSound}>
            <Text style={styles.buttonText}>Pause</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={resumeSound}>
            <Text style={styles.buttonText}>Resume</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={stopSound}>
            <Text style={styles.buttonText}>Stop</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Metronome Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Metronome</Text>
        <Text style={styles.description}>
          Metallic tick-tock sound (40-240 BPM)
        </Text>

        {/* BPM Controls */}
        <View style={styles.controlGroup}>
          <Text style={styles.label}>BPM: {bpm}</Text>
          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={styles.smallButton}
              onPress={() => updateBPM(bpm - 5)}
            >
              <Text style={styles.buttonText}>-5</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.smallButton}
              onPress={() => updateBPM(bpm - 1)}
            >
              <Text style={styles.buttonText}>-1</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.smallButton}
              onPress={() => updateBPM(bpm + 1)}
            >
              <Text style={styles.buttonText}>+1</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.smallButton}
              onPress={() => updateBPM(bpm + 5)}
            >
              <Text style={styles.buttonText}>+5</Text>
            </TouchableOpacity>
          </View>
          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={styles.presetButton}
              onPress={() => updateBPM(60)}
            >
              <Text style={styles.buttonText}>60</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.presetButton}
              onPress={() => updateBPM(120)}
            >
              <Text style={styles.buttonText}>120</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.presetButton}
              onPress={() => updateBPM(180)}
            >
              <Text style={styles.buttonText}>180</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Volume Control */}
        <View style={styles.controlGroup}>
          <Text style={styles.label}>Volume: {Math.round(volume * 100)}%</Text>
          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={styles.smallButton}
              onPress={() => updateVolume(volume - 0.1)}
            >
              <Text style={styles.buttonText}>-10%</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.smallButton}
              onPress={() => updateVolume(volume + 0.1)}
            >
              <Text style={styles.buttonText}>+10%</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Metronome Control Buttons */}
        <View style={styles.buttonContainer}>
          {!metronomeRunning ? (
            <TouchableOpacity
              style={[styles.button, styles.primaryButton]}
              onPress={startMetronome}
            >
              <Text style={styles.buttonText}>Start Metronome</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity
              style={[styles.button, styles.stopButton]}
              onPress={stopMetronome}
            >
              <Text style={styles.buttonText}>Stop Metronome</Text>
            </TouchableOpacity>
          )}
        </View>
      </View>

      {/* Debug Logs Section */}
      <View style={styles.section}>
        <View style={styles.logHeader}>
          <Text style={styles.sectionTitle}>Debug Logs</Text>
          <View style={styles.logButtons}>
            <TouchableOpacity style={styles.copyButton} onPress={copyLogs}>
              <Text style={styles.logButtonText}>Copy</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.clearButton}
              onPress={() => {
                setLogs([]);
                addLog('Logs cleared');
              }}
            >
              <Text style={styles.logButtonText}>Clear</Text>
            </TouchableOpacity>
          </View>
        </View>
        <ScrollView
          style={styles.logContainer}
          contentContainerStyle={styles.logContent}
          nestedScrollEnabled={true}
        >
          {logs.length === 0 ? (
            <Text style={styles.logEmpty}>
              No logs yet. Start the metronome to see timing information.
            </Text>
          ) : (
            logs.map((log, index) => (
              <Text key={index} style={styles.logText}>
                {log}
              </Text>
            ))
          )}
        </ScrollView>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    padding: 20,
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 30,
    color: '#333',
  },
  section: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 20,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    marginBottom: 10,
    color: '#333',
  },
  description: {
    fontSize: 14,
    color: '#666',
    marginBottom: 15,
  },
  status: {
    fontSize: 16,
    marginBottom: 15,
    textAlign: 'center',
    color: '#666',
  },
  buttonContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 10,
    marginTop: 10,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    marginVertical: 8,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    minWidth: 80,
    alignItems: 'center',
  },
  smallButton: {
    backgroundColor: '#34C759',
    paddingHorizontal: 15,
    paddingVertical: 8,
    borderRadius: 6,
    minWidth: 60,
    alignItems: 'center',
  },
  presetButton: {
    backgroundColor: '#5856D6',
    paddingHorizontal: 20,
    paddingVertical: 8,
    borderRadius: 6,
    minWidth: 70,
    alignItems: 'center',
  },
  primaryButton: {
    backgroundColor: '#34C759',
    paddingHorizontal: 30,
    paddingVertical: 15,
  },
  stopButton: {
    backgroundColor: '#FF3B30',
    paddingHorizontal: 30,
    paddingVertical: 15,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  controlGroup: {
    marginVertical: 15,
  },
  label: {
    fontSize: 16,
    fontWeight: '500',
    marginBottom: 10,
    color: '#333',
    textAlign: 'center',
  },
  logHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  logButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  copyButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  clearButton: {
    backgroundColor: '#FF3B30',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  logButtonText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  logContainer: {
    backgroundColor: '#1a1a1a',
    borderRadius: 8,
    maxHeight: 300,
    minHeight: 100,
  },
  logContent: {
    padding: 12,
  },
  logText: {
    fontSize: 11,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    color: '#00ff00',
    marginBottom: 4,
    lineHeight: 16,
  },
  logEmpty: {
    fontSize: 12,
    color: '#999',
    fontStyle: 'italic',
    textAlign: 'center',
    padding: 20,
  },
});
