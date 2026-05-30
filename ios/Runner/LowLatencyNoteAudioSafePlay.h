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

/// AVAudioEngine graph mutations (attach / connect / prepare+start) raise
/// Objective-C NSExceptions on an invalid graph or session state. Swift's
/// do/catch cannot catch those, so wrap them here and surface NSError instead
/// of aborting the process.
+ (BOOL)attachNode:(AVAudioNode *)node
          toEngine:(AVAudioEngine *)engine
             error:(NSError *_Nullable *_Nullable)error;

+ (BOOL)connectNode:(AVAudioNode *)node
             toNode:(AVAudioNode *)destination
             format:(AVAudioFormat *_Nullable)format
           inEngine:(AVAudioEngine *)engine
              error:(NSError *_Nullable *_Nullable)error;

+ (BOOL)prepareAndStartEngine:(AVAudioEngine *)engine
                        error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
