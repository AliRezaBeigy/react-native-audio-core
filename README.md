<h1 align="center">React Native Audio Player</h1>

<div align="center">
    <p><a href="https://github.com/AliRezaBeigy/react-native-audio-core/blob/master/LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="MIT License"></a>
    <a href="http://makeapullrequest.com"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge" alt="PR&#39;s Welcome"></a>
    <img src="https://img.shields.io/npm/v/react-native-audio-core?style=for-the-badge" alt="npm">
    <img src="https://img.shields.io/npm/dt/react-native-audio-core?style=for-the-badge" alt="npm">
    <img src="https://img.shields.io/github/stars/AliRezaBeigy/react-native-audio-core?style=for-the-badge" alt="GitHub Repo stars"></p>
</div>

<p align="center">
<img src="banner.png" alt="Banner" height="300">
</p>
A React Native library for seamless audio playback on iOS and Android. Effortlessly play local audio files or stream from remote URLs with a developer-friendly API.

## Features

- **Cross-Platform**: Works on both iOS and Android with a unified API.
- **Flexible Playback**: Supports local audio files and remote streaming (HTTP/HTTPS).
- **Simple Controls**: Play, pause, resume, and stop audio with intuitive methods.
- **Type-Safe**: Includes TypeScript definitions for a better developer experience.

## Installation

Install the module via npm or Yarn:

```bash
npm install react-native-audio-core
```

or

```bash
yarn add react-native-audio-core
```

### iOS Setup
1. Run `pod install` in the `ios/` directory:
   ```bash
   cd ios && pod install
   ```
2. Ensure the `AVFoundation.framework` is linked in your Xcode project (usually handled automatically).

### Android Setup
No additional setup is required. The module uses the native `MediaPlayer` for playback.

## Usage

Import and use the `AudioWrapper` to play audio in your React Native app:

```javascript
import Audio from 'react-native-audio-core';

// Play a local audio file
await Audio.play(require('./sound.mp3'))
  .then(() => console.log('Playing local audio'))
  .catch(error => console.error('Error:', error));

// Play a remote audio stream
await Audio.play('https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3')
  .then(() => console.log('Playing remote audio'))
  .catch(error => console.error('Error:', error));

// Control playback
Audio.pause();
Audio.resume();
Audio.stop();
```

### Example App
The repository includes an example app to demonstrate usage. To run it:

```bash
yarn example
```

This launches a demo app with buttons to play, pause, resume, and stop local and remote audio.

## API Reference

### `Audio.play(resource: number | string): Promise<void>`
Plays an audio file.
- `resource`: Either a local asset (e.g., `require('./sound.mp3')`) or a remote URL (e.g., `'https://example.com/audio.mp3'`).
- Resolves when playback starts, or rejects on error.

### `Audio.pause(): void`
Pauses the current audio playback.

### `Audio.resume(): void`
Resumes paused audio playback.

### `Audio.stop(): void`
Stops playback and releases resources.

## Contributing
Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) and submit pull requests or issues on [GitHub](https://github.com/AliRezaBeigy/react-native-audio-core).

## License
This project is licensed under the [MIT License](LICENSE).

## Support
If you encounter issues or have questions, please file an issue on the [GitHub repository](https://github.com/AliRezaBeigy/react-native-audio-core/issues).

---

Built with ❤️ by [AliReza Beigy](https://github.com/AliRezaBeigy). Star the repo if you find it useful!
