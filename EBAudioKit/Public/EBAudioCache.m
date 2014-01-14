//
//  EBAudioCache.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBAudioCache.h"
#import <CommonCrypto/CommonCrypto.h>

@interface EBAudioCachedItem ()
@property (nonatomic, strong) NSMutableIndexSet *indexSet;


@end

@implementation EBAudioCachedItem

- (id) init
{
    self = [super init];
    if (self) {
        self.indexSet = [NSMutableIndexSet new];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.indexSet = [aDecoder decodeObjectOfClass: [NSMutableIndexSet class] forKey: @"indexSet"];
        if (self.indexSet == nil) {
            self.indexSet = [NSMutableIndexSet new];
        }
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject: self.indexSet forKey: @"indexSet"];
}

- (NSIndexSet*) cachedIndexes
{
    return _indexSet;
}

@end

@interface EBAudioCache () <NSCacheDelegate>
@property (nonatomic, strong) NSCache *cacheItems;
@property (nonatomic, strong) NSMutableSet *cacheKeys; // NSCache doesn't have an accessor for this :|
@property (nonatomic, strong) dispatch_queue_t synchronizeQueue;
@end

@implementation EBAudioCache

#pragma mark - Utilities

static inline NSString* SHA256StringFromData(NSData* data)
{
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, data.length, digest);
    char output[CC_SHA256_DIGEST_LENGTH*2+1];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        snprintf(output+(i*2), 3, "%02x", digest[i]);
    }
    return [NSString stringWithUTF8String: output];
}

static inline NSString* MD5StringFromData(NSData* data)
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, data.length, digest);
    char output[CC_MD5_DIGEST_LENGTH*2+1];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        snprintf(output+(i*2), 3, "%02x", digest[i]);
    }
    return [NSString stringWithUTF8String: output];
}

#pragma mark - Class Methods

+ (NSURL*) sandboxedCachePath
{
    NSURL *cachePath = [NSURL fileURLWithPath: [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]];
    NSFileManager *fileManager = [NSFileManager new];
    [fileManager createDirectoryAtURL: cachePath withIntermediateDirectories: YES attributes: nil error: nil];
    return cachePath;
}

__strong static EBAudioCache *_defaultCache = nil;
+ (instancetype) defaultCache
{
    if (_defaultCache == nil) {
        _defaultCache = [[EBAudioCache alloc] init];
        _defaultCache.cacheURL = [[self sandboxedCachePath] URLByAppendingPathComponent: @"com.sudeium.EBAudioKit.EBAudioCache" isDirectory: YES];
    }
    return _defaultCache;
}

+ (void) setDefaultCache:(id)defaultCache
{
    _defaultCache = defaultCache;
}

- (id) init
{
    self = [super init];
    if (self) {
        self.cacheItems = [NSCache new];
        [self.cacheItems setDelegate: self];
        self.cacheKeys = [NSMutableSet new];
        self.synchronizeQueue = dispatch_queue_create("com.sudeium.EBAudioKit.EBAudioCache.synchronizeQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSURL*) cachePathForKey: (NSString*) key
{
    NSString *filename = MD5StringFromData([key dataUsingEncoding: NSUTF8StringEncoding]);
    return [[self cacheURL] URLByAppendingPathComponent: filename];
}

- (void) setCacheURL:(NSURL *)cacheURL
{
    [self willChangeValueForKey: @"cacheURL"];
    _cacheURL = cacheURL;
    NSFileManager *fm = [NSFileManager new];
    [fm createDirectoryAtURL: cacheURL withIntermediateDirectories: YES attributes: nil error: nil];
    [self didChangeValueForKey: @"cacheURL"];
}

- (EBAudioCachedItem*) cachedItemForKey:(NSString *)key
{
    EBAudioCachedItem *item = [self.cacheItems objectForKey: key];
    if (item) {
        return item;
    } else {
        // Try to load it from disk
        NSURL *path = [self cachePathForKey: key];
        item = [NSKeyedUnarchiver unarchiveObjectWithFile: path.absoluteString];
        if (item == nil) {
            // Just make a new one.
            item = [EBAudioCachedItem new];
            item.key = key;
        }
    }
    return item;
}

- (void) cacheItem: (EBAudioCachedItem*) item forKey: (NSString*) key
{
    [self.cacheItems setObject: item forKey: key];
    [self.cacheKeys addObject: key];
}

- (void) synchronize
{
    // Write out all the cache files to disk asynchronously on a dedicated queue
    dispatch_async(self.synchronizeQueue, ^{
        [self _synchronize];
    });
}

- (void) _synchronize
{
    for (NSString *key in self.cacheKeys) {
        [self _synchronizeCacheItem: [self.cacheItems objectForKey: key]];
    }
}

- (void) _synchronizeCacheItem: (EBAudioCachedItem*) item
{
    [NSKeyedArchiver archiveRootObject: item toFile: [self cachePathForKey: item.key].absoluteString];
}

#pragma mark - Cache Delegate

- (void) cache:(NSCache *)cache willEvictObject:(id)obj
{
    // Synchronize the item to disk before evicting it
    [self _synchronizeCacheItem: obj];
    [self.cacheKeys removeObject: [obj key]];
}

@end

