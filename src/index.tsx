import Audio from './NativeAudio';
// @ts-expect-error because resolveAssetSource is untyped
import resolveAssetSource from 'react-native/Libraries/Image/resolveAssetSource';

const AudioWrapper = {
  play: async (resource: number | string) => {
    let uri: string;

    if (typeof resource === 'string') {
      if (resource.startsWith('http://') || resource.startsWith('https://')) {
        uri = resource;
      } else {
        throw new Error(
          'Invalid URL: Only HTTP/HTTPS URLs or local assets are supported'
        );
      }
    } else if (typeof resource === 'number') {
      const source = resolveAssetSource(resource);
      if (!source?.uri) {
        throw new Error('Invalid audio file');
      }
      uri = source.uri;
    } else {
      throw new Error(
        'Invalid resource: Must be a number (local asset) or string (URL)'
      );
    }

    await Audio.play(uri);
  },
  pause: () => Audio.pause(),
  resume: () => Audio.resume(),
  stop: () => Audio.stop(),
};

export default AudioWrapper;
