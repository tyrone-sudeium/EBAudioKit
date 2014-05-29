//
//  EBSeekableURLInputStream.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 8/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBSeekableInputStream.h"

@class EBAudioCachedItem, EBSeekableURLInputStream;

@protocol EBSeekableURLInputStreamDelegate <NSObject>
- (void) inputStreamDidChangeCacheStatus: (EBSeekableURLInputStream*) stream;
- (void) inputStreamDidFinishDownload: (EBSeekableURLInputStream*) stream;
- (void) inputStream: (EBSeekableURLInputStream*) stream didFailWithError: (NSError*) error;
@end

@interface EBURLOperation : NSOperation
@property (nonatomic, assign) NSRange downloadRange;
@property (nonatomic, copy) NSString *URLString;
@property (nonatomic, strong) EBAudioCachedItem *cacheItem;
@end

@interface EBSeekableURLInputStream : EBSeekableInputStream
@property (nonatomic, strong) EBAudioCachedItem *cacheItem;
@property (nonatomic, weak) id<EBSeekableURLInputStreamDelegate> delegate;

- (void) seekToOffset: (NSUInteger) offset;
- (void) prepareToClose;
- (BOOL) hasEntireFileCached;
- (BOOL) atEOF;

@end
