//
//  EBAudioPlayerItem+Private.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 18/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>

@class EBSeekableURLInputStream;
@class EBAudioPlayerItem;
@protocol EBAudioPlayerItemDelegate <NSObject>
- (void) playerItemDidReachEnd: (EBAudioPlayerItem*) playerItem;
- (void) playerItemDurationChanged: (EBAudioPlayerItem*) playerItem;
@end
@interface EBAudioPlayerItem ()
@property (nonatomic, strong) EBSeekableURLInputStream *inputStream;
@property (nonatomic, strong) EBAudioDecoder *audioDecoder;
@end
