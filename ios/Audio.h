#import <Audio/RNAudioSpec.h>
#import <AVFoundation/AVFoundation.h>

@interface Audio : NSObject <NativeAudioSpec, AVAudioPlayerDelegate>

@property (strong, nonatomic) AVAudioPlayer *player;
@property (copy, nonatomic) RCTPromiseResolveBlock resolveBlock;
@property (copy, nonatomic) RCTPromiseRejectBlock rejectBlock;

// Metronome properties
@property (strong, nonatomic) AVAudioEngine *metronomeEngine;
@property (strong, nonatomic) AVAudioSourceNode *metronomeSourceNode;
@property (assign, nonatomic) NSInteger currentBeat;
@property (assign, nonatomic) double bpm;
@property (assign, nonatomic) double volume;
@property (assign, nonatomic) BOOL isMetronomeRunning;
@property (assign, nonatomic) double sampleRate;
@property (assign, nonatomic) NSTimeInterval nextBeatTime;
@property (assign, nonatomic) NSTimeInterval lastBeatTime;
@property (assign, nonatomic) double lastBPM;
// Pre-generated click sounds (as float arrays for iOS)
@property (strong, nonatomic) NSData *tickSound;
@property (strong, nonatomic) NSData *tockSound;

@end