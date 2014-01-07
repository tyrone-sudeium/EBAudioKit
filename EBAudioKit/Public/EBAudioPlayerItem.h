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

@interface EBAudioPlayerItem : NSObject
@property (nonatomic, readonly, strong) NSURL *URL;
@property (nonatomic, readonly) CMTime duration;
@property (nonatomic, readonly) EBAudioPlayerItemStatus status;

+ (instancetype) playerItemWithURL: (NSURL*) aURL;
- (id) initWithURL: (NSURL*) aURL;

@end
