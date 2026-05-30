#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Catches NSException from AVAudioPlayerNode operations (invalid engine graph /
/// session / buffer-format mismatch) so they surface as NSError instead of
/// aborting the process.
@interface LowLatencyNoteAudioSafePlay : NSObject

+ (BOOL)playNode:(AVAudioPlayerNode *)node error:(NSError *_Nullable *_Nullable)error;

/// Wraps -[AVAudioPlayerNode scheduleBuffer:atTime:options:completionHandler:].
/// scheduleBuffer raises an NSException (e.g. buffer format != connected output
/// format) that would otherwise terminate the app.
+ (BOOL)scheduleBuffer:(AVAudioPCMBuffer *)buffer
                onNode:(AVAudioPlayerNode *)node
     completionHandler:(void (^_Nullable)(void))completionHandler
                 error:(NSError *_Nullable *_Nullable)error;

/// Same as above but fires the handler only after the audio has actually been
/// played back (AVAudioPlayerNodeCompletionDataPlayedBack), so the caller can
/// recycle the node without truncating the note's tail.
+ (BOOL)scheduleBuffer:(AVAudioPCMBuffer *)buffer
                onNode:(AVAudioPlayerNode *)node
     playedBackHandler:(void (^_Nullable)(void))completionHandler
                 error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
