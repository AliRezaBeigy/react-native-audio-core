import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  play(uri: string, isResource: boolean): Promise<void>;
  pause(): void;
  resume(): void;
  stop(): void;
  startMetronome(bpm: number, volume: number): void;
  stopMetronome(): void;
  setMetronomeBPM(bpm: number): void;
  setMetronomeVolume(volume: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Audio');
