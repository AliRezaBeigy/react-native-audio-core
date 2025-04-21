import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  play(uri: string, isResource: boolean): Promise<void>;
  pause(): void;
  resume(): void;
  stop(): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Audio');
