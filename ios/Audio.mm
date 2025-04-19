#import "Audio.h"

@implementation Audio

RCT_EXPORT_MODULE()

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeAudioSpecJSI>(params);
}

- (void)play:(NSString *)uri
     resolve:(RCTPromiseResolveBlock)resolve
      reject:(RCTPromiseRejectBlock)reject
{
    [self stopCurrentPlayback];
    
    NSError *error;
    NSURL *url = [NSURL URLWithString:uri];
    if (!url) {
        reject(@"Error", @"Invalid URI", nil);
        return;
    }
    
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        NSData *audioData = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&error];
        if (!audioData) {
            NSString *errorMessage = [NSString stringWithFormat:@"Failed to download audio data: %@", error.localizedDescription];
            reject(@"Error", errorMessage, error);
            return;
        }
        
        self.player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
    } else {
        if ([uri hasPrefix:@"file://"]) {
            url = [NSURL fileURLWithPath:[uri substringFromIndex:7]];
        } else {
            NSString *assetName = [uri stringByDeletingPathExtension];
            NSString *extension = [uri pathExtension];
            url = [[NSBundle mainBundle] URLForResource:assetName withExtension:extension];
        }
        
        if (!url) {
            reject(@"Error", @"Invalid URI or asset not found", nil);
            return;
        }
        
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    }
    
    if (!self.player) {
        NSString *errorMessage = [NSString stringWithFormat:@"Failed to create player: %@", error.localizedDescription];
        reject(@"Error", errorMessage, error);
        return;
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

@end
