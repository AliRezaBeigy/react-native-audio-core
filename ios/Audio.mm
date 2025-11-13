#import "Audio.h"

@implementation Audio

RCT_EXPORT_MODULE()

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeAudioSpecJSI>(params);
}

- (void)play:(NSString *)input
  isResource:(BOOL)isResource
     resolve:(RCTPromiseResolveBlock)resolve
      reject:(RCTPromiseRejectBlock)reject
{
    [self stopCurrentPlayback];

    if (!input || [input length] == 0) {
        reject(@"Error", @"Input is empty", nil);
        return;
    }

    NSError *error;
    if (isResource) {
        if ([input hasPrefix:@"file://"]) {
            NSURL *url = [NSURL URLWithString:input];
            if (!url) {
                reject(@"Error", @"Invalid local file URI", nil);
                return;
            }
            self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
            if (!self.player) {
                reject(@"Error", [NSString stringWithFormat:@"Failed to create player: %@", error.localizedDescription], error);
                return;
            }
        } else {
            reject(@"Error", @"Expected local file URI starting with 'file://'", nil);
            return;
        }
    } else {
        if ([input hasPrefix:@"http://"] || [input hasPrefix:@"https://"]) {
            NSURL *url = [NSURL URLWithString:input];
            if (!url) {
                reject(@"Error", @"Invalid remote URL", nil);
                return;
            }
            NSData *audioData = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&error];
            if (!audioData) {
                reject(@"Error", [NSString stringWithFormat:@"Failed to download audio data: %@", error.localizedDescription], error);
                return;
            }
            self.player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
            if (!self.player) {
                reject(@"Error", [NSString stringWithFormat:@"Failed to create player: %@", error.localizedDescription], error);
                return;
            }
        } else {
            reject(@"Error", @"Expected remote URL starting with 'http://' or 'https://'", nil);
            return;
        }
    }

    self.player.delegate = self;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [self.player play];

    self.resolveBlock = resolve;
    self.rejectBlock = reject;
}

- (void)pause
{
    if (self.player) {
        [self.player pause];
    }
}

- (void)resume
{
    if (self.player) {
        [self.player play];
    }
}

- (void)stop
{
    [self stopCurrentPlayback];
}

- (void)stopCurrentPlayback
{
    if (self.player) {
        [self.player stop];
        self.player = nil;
    }
    if (self.rejectBlock) {
        self.rejectBlock(@"Stopped", @"Playback was stopped", nil);
        self.rejectBlock = nil;
        self.resolveBlock = nil;
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (flag && self.resolveBlock) {
        self.resolveBlock(nil);
    } else if (!flag && self.rejectBlock) {
        self.rejectBlock(@"Error", @"Playback did not finish successfully", nil);
    }
    self.player = nil;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    if (self.rejectBlock) {
        self.rejectBlock(@"Error", @"Decode error", error);
    }
    self.player = nil;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
}

#pragma mark - Metronome

- (void)startMetronome:(double)bpm volume:(double)volume
{
    if (self.isMetronomeRunning) {
        [self stopMetronome];
    }
    
    self.bpm = bpm;
    self.lastBPM = bpm;
    self.volume = volume;
    self.currentBeat = 0;
    self.isMetronomeRunning = YES;
    
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    [session setActive:YES error:&error];
    
    // Create audio engine
    self.metronomeEngine = [[AVAudioEngine alloc] init];
    AVAudioFormat *format = [[self.metronomeEngine mainMixerNode] outputFormatForBus:0];
    self.sampleRate = format.sampleRate;
    
    // Pre-generate tick and tock sounds (like Android) - after sampleRate is set
    [self generateClickSounds:volume];
    
    // Create source node for generating audio
    __weak typeof(self) weakSelf = self;
    self.metronomeSourceNode = [[AVAudioSourceNode alloc] initWithRenderBlock:^OSStatus(BOOL *isSilence, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, AudioBufferList *outputData) {
        @autoreleasepool {
            if (!weakSelf.isMetronomeRunning) {
                *isSilence = YES;
                return noErr;
            }
            
            // Get current audio time in seconds
            double currentTime = timestamp->mSampleTime / weakSelf.sampleRate;
            double currentBPM = weakSelf.bpm;
            
            // Fill buffer with silence initially
            float *channel0 = (float *)outputData->mBuffers[0].mData;
            for (AVAudioFrameCount i = 0; i < frameCount; i++) {
                channel0[i] = 0.0f;
            }
            
            // Initialize timing on first call (play first beat immediately)
            if (weakSelf.nextBeatTime == 0) {
                weakSelf.nextBeatTime = currentTime;
                weakSelf.lastBeatTime = currentTime;
                weakSelf.currentBeat = 0;
                weakSelf.lastBPM = currentBPM;
                
                // Play first beat immediately (like Android)
                BOOL isTick = (weakSelf.currentBeat % 2 == 0);
                [weakSelf playPreGeneratedClick:isTick inBuffer:channel0 atFrame:0 frameCount:frameCount];
                weakSelf.currentBeat++;
                double beatInterval = 60.0 / currentBPM;
                weakSelf.nextBeatTime = currentTime + beatInterval;
                weakSelf.lastBeatTime = currentTime;
            }
            
            // Handle BPM changes with proportional recalculation (like Android)
            if (currentBPM != weakSelf.lastBPM) {
                if (currentTime < weakSelf.nextBeatTime) {
                    // We're between beats - recalculate proportionally
                    double elapsedSinceLastBeat = (currentTime - weakSelf.lastBeatTime) * 1000.0; // Convert to ms
                    double oldInterval = (60.0 / weakSelf.lastBPM * 1000.0);
                    double newInterval = (60.0 / currentBPM * 1000.0);
                    
                    // Proportionally adjust: if we're X% through old interval, be X% through new interval
                    double progressRatio = elapsedSinceLastBeat / oldInterval;
                    double remainingTime = newInterval * (1.0 - progressRatio);
                    
                    // Ensure minimum 1ms delay to prevent scheduling beats too soon
                    double adjustedRemainingTime = MAX(1.0, remainingTime);
                    weakSelf.nextBeatTime = currentTime + (adjustedRemainingTime / 1000.0);
                } else {
                    // We're at or past beat time - use new BPM for next interval immediately
                    double newInterval = 60.0 / currentBPM;
                    weakSelf.nextBeatTime = currentTime + newInterval;
                }
                weakSelf.lastBPM = currentBPM;
            }
            
            // Schedule beats that fall within this buffer or near future
            double bufferEndTime = currentTime + (double)frameCount / weakSelf.sampleRate;
            double lookAhead = 0.15; // 150ms look-ahead
            double scheduleUntil = bufferEndTime + lookAhead;
            
            // Schedule all beats that should occur in this time window
            while (weakSelf.nextBeatTime < scheduleUntil) {
                double samplesUntilBeat = (weakSelf.nextBeatTime - currentTime) * weakSelf.sampleRate;
                BOOL isTick = (weakSelf.currentBeat % 2 == 0);
                
                // Schedule beat if it's in the current buffer or very near future (within 10ms)
                if (samplesUntilBeat >= -weakSelf.sampleRate * 0.01 && samplesUntilBeat < frameCount) {
                    AVAudioFrameCount frameOffset = (AVAudioFrameCount)MAX(0, samplesUntilBeat);
                    
                    // Only generate if we have room in the buffer
                    if (frameOffset < frameCount) {
                        // Play pre-generated sound (like Android)
                        [weakSelf playPreGeneratedClick:isTick
                                               inBuffer:channel0
                                                atFrame:frameOffset
                                             frameCount:frameCount - frameOffset];
                    }
                }
                
                // Move to next beat (always advance, even if we didn't generate this one)
                weakSelf.currentBeat++;
                weakSelf.lastBeatTime = weakSelf.nextBeatTime;
                
                // Calculate next beat time based on current BPM
                double beatInterval = 60.0 / weakSelf.bpm;
                weakSelf.nextBeatTime = weakSelf.nextBeatTime + beatInterval;
            }
            
            // Handle stereo if needed
            if (outputData->mNumberBuffers > 1) {
                float *channel1 = (float *)outputData->mBuffers[1].mData;
                memcpy(channel1, channel0, frameCount * sizeof(float));
            }
            
            return noErr;
        }
    }];
    
    // Connect nodes
    [self.metronomeEngine attachNode:self.metronomeSourceNode];
    [self.metronomeEngine connect:self.metronomeSourceNode
                           to:[self.metronomeEngine mainMixerNode]
                       format:format];
    
    // Start engine
    NSError *engineError = nil;
    if (![self.metronomeEngine startAndReturnError:&engineError]) {
        NSLog(@"Failed to start metronome engine: %@", engineError);
        self.isMetronomeRunning = NO;
        return;
    }
    
    // Initialize timing (will be set on first render, then first beat plays immediately)
    self.nextBeatTime = 0;
    self.lastBeatTime = 0;
    self.currentBeat = 0;
}

// Pre-generate click sounds (like Android)
- (void)generateClickSounds:(double)volume
{
    double duration = 0.04; // 40ms to cover both noise and tone (like Android)
    AVAudioFrameCount totalSamples = (AVAudioFrameCount)(duration * self.sampleRate);
    
    // Generate tick sound (2400 Hz) as float array
    float *tickFloat = (float *)malloc(totalSamples * sizeof(float));
    [self generateClickBuffer:YES buffer:tickFloat volume:volume];
    self.tickSound = [NSData dataWithBytesNoCopy:tickFloat length:totalSamples * sizeof(float) freeWhenDone:YES];
    
    // Generate tock sound (1600 Hz) as float array
    float *tockFloat = (float *)malloc(totalSamples * sizeof(float));
    [self generateClickBuffer:NO buffer:tockFloat volume:volume];
    self.tockSound = [NSData dataWithBytesNoCopy:tockFloat length:totalSamples * sizeof(float) freeWhenDone:YES];
}

// Generate click buffer (like Android's generateClickBuffer)
- (void)generateClickBuffer:(BOOL)isTick buffer:(float *)buffer volume:(double)volume
{
    double toneFreq = isTick ? 2400.0 : 1600.0;
    double filterFreq = isTick ? 2800.0 : 1800.0;
    double Q = 12.0;
    double duration = 0.03;
    
    for (AVAudioFrameCount i = 0; i < (AVAudioFrameCount)(0.04 * self.sampleRate); i++) {
        double t = (double)i / self.sampleRate;
        double sample = 0.0;
        
        // White noise component (30ms duration)
        if (t < duration) {
            double noiseValue = ((double)arc4random() / UINT32_MAX) * 2.0 - 1.0;
            double noiseEnv = [self noiseEnvelope:t];
            sample += noiseValue * noiseEnv * 0.7;
        }
        
        // Square wave tone component (40ms duration)
        if (t < 0.04) {
            double phase = fmod(t * toneFreq, 1.0);
            double squareWave = (phase < 0.5) ? 1.0 : -1.0;
            double toneEnv = [self toneEnvelope:t];
            sample += squareWave * toneEnv * 0.5;
        }
        
        // Apply high-pass filter approximation
        double filterGain = [self highPassGain:toneFreq filterFreq:filterFreq Q:Q];
        sample *= filterGain;
        
        // Apply master volume with headroom
        sample *= volume * 1.2;
        
        // Clamp to prevent clipping
        sample = fmax(-1.0, fmin(1.0, sample));
        
        buffer[i] = (float)sample;
    }
}

// Play pre-generated click sound (like Android)
- (void)playPreGeneratedClick:(BOOL)isTick
                      inBuffer:(float *)buffer
                       atFrame:(AVAudioFrameCount)frameOffset
                    frameCount:(AVAudioFrameCount)frameCount
{
    NSData *clickSound = isTick ? self.tickSound : self.tockSound;
    if (!clickSound) return;
    
    const float *soundData = (const float *)clickSound.bytes;
    AVAudioFrameCount soundSamples = (AVAudioFrameCount)(clickSound.length / sizeof(float));
    AVAudioFrameCount samplesToCopy = MIN(soundSamples, frameCount - frameOffset);
    
    // Mix with existing audio (like Android)
    for (AVAudioFrameCount i = 0; i < samplesToCopy; i++) {
        float mixed = buffer[frameOffset + i] + soundData[i];
        buffer[frameOffset + i] = fmax(-1.0f, fmin(1.0f, mixed));
    }
}

- (double)noiseEnvelope:(double)t
{
    // 0 → 0.7 in 1ms, exponential decay to 0.001 in 30ms
    if (t < 0.001) {
        return 0.7 * (t / 0.001);
    } else if (t < 0.03) {
        double decayTime = t - 0.001;
        double decayDuration = 0.029;
        return 0.7 * exp(-decayTime / decayDuration * log(0.7 / 0.001));
    }
    return 0.0;
}

- (double)toneEnvelope:(double)t
{
    // 0 → 0.5 in 2ms, exponential decay to 0.001 in 40ms
    if (t < 0.002) {
        return 0.5 * (t / 0.002);
    } else if (t < 0.04) {
        double decayTime = t - 0.002;
        double decayDuration = 0.038;
        return 0.5 * exp(-decayTime / decayDuration * log(0.5 / 0.001));
    }
    return 0.0;
}

- (double)highPassGain:(double)freq filterFreq:(double)filterFreq Q:(double)Q
{
    // Simplified high-pass filter gain approximation
    // A proper implementation would use a biquad filter
    if (freq < filterFreq) {
        double ratio = freq / filterFreq;
        return ratio * ratio * Q * 0.1; // Attenuate below cutoff
    }
    return 1.0 + (Q - 1.0) * 0.1; // Slight boost at resonance
}

- (void)stopMetronome
{
    self.isMetronomeRunning = NO;
    
    if (self.metronomeEngine) {
        [self.metronomeEngine stop];
        self.metronomeEngine = nil;
    }
    
    self.metronomeSourceNode = nil;
    self.currentBeat = 0;
    self.nextBeatTime = 0;
    self.lastBeatTime = 0;
    self.tickSound = nil;
    self.tockSound = nil;
}

- (void)setMetronomeBPM:(double)bpm
{
    self.bpm = bpm;
    // The render block will handle BPM changes with proportional recalculation (like Android)
}

- (void)setMetronomeVolume:(double)volume
{
    self.volume = volume;
    // Regenerate sounds with new volume if metronome is running (like Android)
    if (self.isMetronomeRunning) {
        [self generateClickSounds:volume];
    }
}

@end
