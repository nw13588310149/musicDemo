#import "LowLatencyNoteAudioSafePlay.h"

@implementation LowLatencyNoteAudioSafePlay

+ (BOOL)playNode:(AVAudioPlayerNode *)node error:(NSError **)error {
  if (node == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"node is nil"}];
    }
    return NO;
  }

  @try {
    [node play];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      NSString *reason = exception.reason ?: exception.name;
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : reason}];
    }
    return NO;
  }
}

@end
