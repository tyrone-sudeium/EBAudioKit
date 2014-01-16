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

- (void) cacheData: (NSData*) data representingRangeInFile: (NSRange) range;
- (void) close;

@end

@interface EBAudioCache : NSObject
@property (nonatomic, strong) NSURL *cacheURL;

// The default cache lives at <sandbox>/Library/Caches/com.sudeium.EBAudioKit.EBAudioCache/
+ (instancetype) defaultCache;
+ (void) setDefaultCache: (EBAudioCache*) defaultCache;

- (NSURL*) cachePathForKey: (NSString*) key;

- (EBAudioCachedItem*) cachedItemForKey: (NSString*) key;
- (void) cacheItem: (EBAudioCachedItem*) item forKey: (NSString*) key;


- (void) synchronize;

@end
