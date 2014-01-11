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

@interface EBAudioPlayer : NSObject
@property (nonatomic, copy) NSArray *playbackQueue;
@property (nonatomic, readonly) EBAudioPlayerItem *currentItem;

- (void) play;
- (void) pause;
- (void) stop;
- (void) skipNext;
- (void) skipPrevious;
- (void) seekTo: (CMTime) seekTime;

@end
