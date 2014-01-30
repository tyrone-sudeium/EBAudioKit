//
//  EBAudioPlayer.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class EBAudioPlayerItem;
@class EBAudioPlayer;
@protocol EBAudioPlayerDelegate <NSObject>
// Fires whenever current item changes, current item duration changes,
// playback state changes.
- (void) audioPlayerStatusChanged: (EBAudioPlayer*) player;
// While the player is currently playing, this method will fire every
// positionUpdateInterval seconds.
- (void) audioPlayerPositionChanged: (EBAudioPlayer*) player;
@end

@interface EBAudioPlayer : NSObject
@property (nonatomic, copy) NSArray *playbackQueue;
@property (nonatomic, weak) id<EBAudioPlayerDelegate> delegate;
@property (nonatomic, readonly) EBAudioPlayerItem *currentItem;
@property (nonatomic, readonly) NSUInteger positionInQueue;
// Defaults to 1/30 - 30 times per second.
@property (nonatomic, assign) NSTimeInterval positionUpdateInterval;
@property (nonatomic, readonly, getter = isPlaying) BOOL playing;

- (void) play;
- (void) pause;
- (void) stop;
- (void) skipNext;
- (void) skipPrevious;
- (void) seekTo: (CMTime) seekTime;
- (void) skipTo: (NSUInteger) index;

@end
