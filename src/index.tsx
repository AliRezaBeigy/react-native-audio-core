import Audio from './NativeAudio';
import { Image } from 'react-native';

const AudioWrapper = {
  play: async (resource: number | string) => {
    if (typeof resource === 'string') {
      if (resource.startsWith('http://') || resource.startsWith('https://')) {
        await Audio.play(resource, false);
      } else {
        throw new Error(
          'Invalid URL: Only HTTP/HTTPS URLs or local assets are supported'
        );
      }
    } else if (typeof resource === 'number') {
      const source = Image.resolveAssetSource(resource);
      if (!source?.uri) {
        throw new Error('Invalid audio file');
      }
      const isRemote =
        source.uri.startsWith('http://') || source.uri.startsWith('https://');
      await Audio.play(source.uri, !isRemote);
    } else {
      throw new Error(
        'Invalid resource: Must be a number (local asset) or string (URL)'
      );
    }
  },
  pause: () => Audio.pause(),
  resume: () => Audio.resume(),
  stop: () => Audio.stop(),
  startMetronome: (bpm: number = 60, volume: number = 0.5) => {
    if (bpm < 40 || bpm > 240) {
      throw new Error('BPM must be between 40 and 240');
    }
    if (volume < 0 || volume > 1) {
      throw new Error('Volume must be between 0 and 1');
    }
    Audio.startMetronome(bpm, volume);
  },
  stopMetronome: () => Audio.stopMetronome(),
  setMetronomeBPM: (bpm: number) => {
    if (bpm < 40 || bpm > 240) {
      throw new Error('BPM must be between 40 and 240');
    }
    Audio.setMetronomeBPM(bpm);
  },
  setMetronomeVolume: (volume: number) => {
    if (volume < 0 || volume > 1) {
      throw new Error('Volume must be between 0 and 1');
    }
    Audio.setMetronomeVolume(volume);
  },
};

export default AudioWrapper;
