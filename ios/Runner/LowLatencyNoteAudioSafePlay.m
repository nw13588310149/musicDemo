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

+ (BOOL)scheduleBuffer:(AVAudioPCMBuffer *)buffer
                onNode:(AVAudioPlayerNode *)node
     completionHandler:(void (^)(void))completionHandler
                 error:(NSError **)error {
  if (node == nil || buffer == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"node or buffer is nil"}];
    }
    return NO;
  }

  @try {
    [node scheduleBuffer:buffer atTime:nil options:0 completionHandler:completionHandler];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      NSString *reason = exception.reason ?: exception.name;
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : reason}];
    }
    return NO;
  }
}

+ (BOOL)scheduleBuffer:(AVAudioPCMBuffer *)buffer
                onNode:(AVAudioPlayerNode *)node
     playedBackHandler:(void (^)(void))completionHandler
                 error:(NSError **)error {
  if (node == nil || buffer == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"node or buffer is nil"}];
    }
    return NO;
  }

  @try {
    [node scheduleBuffer:buffer
                  atTime:nil
                 options:0
   completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack
       completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
         if (completionHandler != nil) {
           completionHandler();
         }
       }];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      NSString *reason = exception.reason ?: exception.name;
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : reason}];
    }
    return NO;
  }
}

@end
