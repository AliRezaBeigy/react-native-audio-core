import { useState } from 'react';
import { Text, View, StyleSheet, Button } from 'react-native';
import Audio from 'react-native-audio-core';

export default function App() {
  const [status, setStatus] = useState('Ready');

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

  return (
    <View style={styles.container}>
      <Text style={styles.status}>{status}</Text>
      <View style={styles.buttonContainer}>
        <Button title="Play" onPress={playSound} />
        <Button title="Pause" onPress={pauseSound} />
        <Button title="Resume" onPress={resumeSound} />
        <Button title="Stop" onPress={stopSound} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  status: {
    fontSize: 18,
    marginBottom: 20,
  },
  buttonContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-around',
    width: '100%',
    gap: 10,
  },
});
