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

@end
