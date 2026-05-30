#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Catches NSException from -[AVAudioPlayerNode play] (invalid engine graph / session).
@interface LowLatencyNoteAudioSafePlay : NSObject

+ (BOOL)playNode:(AVAudioPlayerNode *)node error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
