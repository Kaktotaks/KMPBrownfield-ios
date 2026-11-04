#import <Foundation/Foundation.h>
#import <Shared/Shared.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift-implemented `@objc protocol VoicePlayerBackend` (VoicePlayerBackend.swift).
@protocol VoicePlayerBackend;

/// The Kotlin-facing `AudioPlayer` (an Objective-C protocol, `SharedAudioPlayer`), implemented in Objective-C.
///
/// Why this file exists: `AudioPlayer.prepare(path): Long` is exported as
/// `- (int64_t)preparePath:error:` + `swift_error(nonnull_error)`, i.e. Swift sees `throws -> Int64`, and the Swift
/// compiler refuses to let ANY Swift class implement an `@objc` requirement that `throws` and returns a non-object
/// ("throwing method cannot be an implementation of an '@objc' requirement because it returns a value of type 'Int64'").
/// So this thin class implements the Kotlin protocol and forwards everything to a Swift `VoicePlayerBackend`
/// (AVAudioPlayer in the app, fakes in tests/previews). It can be deleted if shared changes `prepare` to return Unit/NSNumber.
@interface VoicePlayerAdapter : NSObject <SharedAudioPlayer>
- (instancetype)initWithBackend:(id<VoicePlayerBackend>)backend NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
