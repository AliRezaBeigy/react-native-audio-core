#import <Audio/RNAudioSpec.h>
#import <AVFoundation/AVFoundation.h>

@interface Audio : NSObject <NativeAudioSpec, AVAudioPlayerDelegate>

@property (strong, nonatomic) AVAudioPlayer *player;
@property (copy, nonatomic) RCTPromiseResolveBlock resolveBlock;
@property (copy, nonatomic) RCTPromiseRejectBlock rejectBlock;

@end