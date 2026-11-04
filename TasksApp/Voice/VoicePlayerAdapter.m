#import "VoicePlayerAdapter.h"
#import "TasksApp-Swift.h"

@implementation VoicePlayerAdapter {
    id<VoicePlayerBackend> _backend;
}

- (instancetype)initWithBackend:(id<VoicePlayerBackend>)backend {
    self = [super init];
    if (self) { _backend = backend; }
    return self;
}

- (BOOL)preparePath:(NSString *)path error:(NSError **)error {
    return [_backend prepareAtPath:path error:error];
}

- (int64_t)durationMs { return _backend.durationMs; }

- (void)play { [_backend play]; }
- (void)pause { [_backend pause]; }
- (void)seekToPositionMs:(int64_t)positionMs { [_backend seekToMs:positionMs]; }
- (void)setSpeedSpeed:(float)speed { [_backend setRate:speed]; }
- (int64_t)positionMs { return _backend.positionMs; }
- (BOOL)isPlaying { return _backend.isPlaying; }
- (void)release_ { [_backend releasePlayer]; }

- (void (^)(void))onCompletion { return _backend.onCompletion; }
- (void)setOnCompletion:(void (^)(void))onCompletion { _backend.onCompletion = onCompletion; }

@end
