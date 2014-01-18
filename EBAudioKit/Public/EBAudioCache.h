//
//  EBAudioCache.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EBAudioCachedItem : NSObject <NSCoding>
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) uint64_t byteSize;
@property (nonatomic, readonly) NSIndexSet *cachedIndexes;
// By default, we set this to key when you set key.
@property (nonatomic, copy) NSString *remoteURL;

// You definitely don't want to call this before setting byteSize.
- (void) cacheData: (NSData*) data representingRangeInFile: (NSRange) range;
- (void) close;

// You definitely don't want to call this unless you're sure these bytes are available.
// You definitely don't want to call this after you've called close.
- (const uint8_t*) getBytesLength: (NSUInteger) maxLen fromOffset: (NSUInteger) offset;

@end

@interface EBAudioCache : NSObject
@property (nonatomic, strong) NSURL *cacheURL;

// The default cache lives at <sandbox>/Library/Caches/com.sudeium.EBAudioKit.EBAudioCache/
+ (instancetype) defaultCache;
+ (void) setDefaultCache: (EBAudioCache*) defaultCache;

- (NSURL*) cachePathForKey: (NSString*) key;

// Returns a new cached item if it doesn't exist
- (EBAudioCachedItem*) cachedItemForKey: (NSString*) key;

- (BOOL) hasItemForKey: (NSString*) key;

- (void) synchronize;
- (void) cleanup;

@end
