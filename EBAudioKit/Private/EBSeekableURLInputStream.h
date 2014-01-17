//
//  EBSeekableURLInputStream.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 8/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBSeekableInputStream.h"

@class EBAudioCachedItem;

@interface EBSeekableURLOperation : NSOperation
@property (nonatomic, assign) NSRange downloadRange;
@property (nonatomic, copy) NSString *URLString;
@property (nonatomic, strong) EBAudioCachedItem *cacheItem;
@end

@interface EBSeekableURLInputStream : NSInputStream
@property (nonatomic, strong) EBAudioCachedItem *cacheItem;

- (void) seekToOffset: (NSUInteger) offset;

@end
