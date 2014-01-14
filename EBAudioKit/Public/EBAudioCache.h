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
@property (nonatomic, readonly) NSIndexSet *cachedIndexes;
@end

@interface EBAudioCache : NSObject
@property (nonatomic, strong) NSURL *cacheURL;

// The default cache lives at <sandbox>/Library/Caches/com.sudeium.EBAudioKit.EBAudioCache/
+ (instancetype) defaultCache;
+ (void) setDefaultCache: (EBAudioCache*) defaultCache;

- (EBAudioCachedItem*) cachedItemForKey: (NSString*) key;

- (void) synchronize;

@end
