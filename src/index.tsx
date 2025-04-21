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
      await Audio.play(source.uri, true);
    } else {
      throw new Error(
        'Invalid resource: Must be a number (local asset) or string (URL)'
      );
    }
  },
  pause: () => Audio.pause(),
  resume: () => Audio.resume(),
  stop: () => Audio.stop(),
};

export default AudioWrapper;
