#import <Foundation/Foundation.h>
#import <Shared/Shared.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift-implemented `@objc protocol VoicePlayerBackend` (VoicePlayerBackend.swift).
@protocol VoicePlayerBackend;

/// The Kotlin-facing `AudioPlayer` (an Objective-C protocol, `SharedAudioPlayer`), implemented in Objective-C.
///
/// Why this file exists: Swift cannot implement `AudioPlayer` on an NSObject subclass. The protocol requirement
/// `release()` (selector `release_`) collides with `NSObject.release` ("multiple matching functions named 'release()'",
/// then "unavailable instance method 'release()' was used to satisfy a requirement"), and Swift protocol witnesses are
/// matched by Swift name, not selector. A Swift class cannot be `@objc` without NSObject either. So this thin Objective-C
/// class implements the Kotlin protocol and forwards to a Swift `VoicePlayerBackend` (AVAudioPlayer in the app, fakes in
/// tests / previews). It can be deleted if shared renames `AudioPlayer.release()` (e.g. `dispose()`).
@interface VoicePlayerAdapter : NSObject <SharedAudioPlayer>
- (instancetype)initWithBackend:(id<VoicePlayerBackend>)backend NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
