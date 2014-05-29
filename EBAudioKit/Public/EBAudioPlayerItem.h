//
//  EBAudioPlayerItem.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

typedef NS_ENUM(NSInteger, EBAudioPlayerItemStatus) {
    EBAudioPlayerItemStatusUnknown,
    EBAudioPlayerItemStatusReadyToPlay,
    EBAudioPlayerItemStatusFailed
};

extern NSString * const EBAudioPlayerItemStatusChangedNotification;

@interface EBAudioPlayerItem : NSObject
@property (nonatomic, readonly, strong) NSURL *URL;
@property (nonatomic, readonly) CMTime duration;
@property (nonatomic, readonly) EBAudioPlayerItemStatus status;
@property (nonatomic, readonly) CMTime position;
@property (nonatomic, readonly) BOOL playbackLikelyToKeepUp;

+ (instancetype) playerItemWithURL: (NSURL*) aURL;
- (id) initWithURL: (NSURL*) aURL;

// Returns the disparate set of bytes that have been cached
// Useful for rendering a download graph
- (NSIndexSet*) cachedRanges;

@end
