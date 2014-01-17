//
//  EBAudioCache.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBAudioCache.h"
#import <CommonCrypto/CommonCrypto.h>
#import <sys/mman.h>

typedef NS_ENUM(NSInteger, EBMemoryType) {
    EBMemoryTypeInvalid,
    EBMemoryTypeMapped,
    EBMemoryTypeMalloc
};

@interface EBAudioCachedItem () {
    EBMemoryType _memoryType;
    uint8_t *_bytes;
}
@property (nonatomic, strong) NSMutableIndexSet *indexSet;
@property (nonatomic, strong) NSURL *fileURL;

@end

@implementation EBAudioCachedItem

// The shared write queue for all cached items.
// We do this so that we don't thrash the disk with multiple writes all at once.
// Is this premature optimisation though? Pretty sure mmap already writes pages to the disk
// lazily, which means this just adds unnecessary overhead...
// At the very least, I'd like to do it this way on the off-chance the memcpy I do in
// cacheData:representingRangeInFile: is blocking - you never know what the timing concerns
// are on the caller and I'd really rather that method return very quickly, but still
// guarantees writes in a specific order.
static dispatch_queue_t GetSharedWriteQueue() {
    static dispatch_queue_t sharedWriteQueue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedWriteQueue = dispatch_queue_create("com.sudeium.EBAudioKit.EBAudioCachedItemWriteQueue", DISPATCH_QUEUE_SERIAL);
    });
    return sharedWriteQueue;
}

- (id) init
{
    self = [super init];
    if (self) {
        self.indexSet = [NSMutableIndexSet new];
        _memoryType = EBMemoryTypeInvalid;
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
        self.fileURL = [aDecoder decodeObjectOfClass: [NSURL class] forKey: @"fileURL"];
        _memoryType = EBMemoryTypeInvalid;
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject: self.indexSet forKey: @"indexSet"];
    [aCoder encodeObject: self.fileURL forKey: @"fileURL"];
}

- (NSIndexSet*) cachedIndexes
{
    return _indexSet;
}

- (void) setupMemoryBlock
{
    if (_bytes == NULL && _memoryType == EBMemoryTypeInvalid) {
        uint64_t fileLen = 0;
        // If the file doesn't exist, create it...
        NSFileManager *fm = [NSFileManager new];
        BOOL fileExists = [fm fileExistsAtPath: self.fileURL.absoluteString];
        if (fileExists) {
            NSDictionary *d = [fm attributesOfItemAtPath: self.fileURL.absoluteString error: nil];
            fileLen = [d fileSize];
        }
        int fd = open(self.fileURL.absoluteString.UTF8String, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
        if (!fileExists || fileLen != self.byteSize) {
            if (fileLen != self.byteSize) {
                // If the sizes differ, blow away the old file
                [self.indexSet removeAllIndexes];
            }
            
            // Make the file big enough
            lseek(fd, self.byteSize, SEEK_SET);
            write(fd, "", 1); // A "" string is just a null terminator, write this at the end of file
            lseek(fd, 0, SEEK_SET);
        }
        // Annoyingly, mmap is limited to 4gb on 32-bit boxes - hope we never download bigger files than that!
        _bytes = mmap(NULL, (size_t) self.byteSize, PROT_READ | PROT_WRITE, 0, fd, 0);
        if (_bytes == MAP_FAILED) {
            // Fall back to an in-memory store.
            close(fd);
            _bytes = malloc((size_t)self.byteSize);
            _memoryType = EBMemoryTypeMalloc;
            return;
        } else {
            _memoryType = EBMemoryTypeMapped;
        }
        close(fd);
    }
}

- (void) cacheData:(NSData *)data representingRangeInFile:(NSRange)range
{
    dispatch_async(GetSharedWriteQueue(), ^{
        [self setupMemoryBlock];
        if (_bytes) {
            memcpy(_bytes + range.location, data.bytes, data.length);
        }
    });
}

- (void) close
{
    if (_memoryType == EBMemoryTypeMalloc) {
        free(_bytes); // TODO: Write to disk
    } else {
        munmap(_bytes, (size_t)self.byteSize);
    }
    _memoryType = EBMemoryTypeInvalid;
    _bytes = NULL;
}

- (void) dealloc
{
    [self close];
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

- (NSURL*) cacheItemFilePathForKey: (NSString*) key
{
    return [[self cachePathForKey: key] URLByAppendingPathExtension: @"plist"];
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
        NSURL *path = [self cacheItemFilePathForKey: key];
        item = [NSKeyedUnarchiver unarchiveObjectWithFile: path.absoluteString];
        if (item == nil) {
            // Just make a new one.
            item = [EBAudioCachedItem new];
            item.key = key;
            item.fileURL = [self cachePathForKey: key];
            [self cacheItem: item forKey: key];
        }
    }
    return item;
}

- (void) cacheItem: (EBAudioCachedItem*) item forKey: (NSString*) key
{
    [self.cacheItems setObject: item forKey: key];
    [self.cacheKeys addObject: key];
}

- (BOOL) hasItemForKey:(NSString *)key
{
    return [self.cacheKeys containsObject: key];
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
    [NSKeyedArchiver archiveRootObject: item toFile: [self cacheItemFilePathForKey: item.key].absoluteString];
}

- (void) cleanup
{
    // Janitorial stuff. iOS can randomly delete stuff out of caches, so we occasionally
    // need to kick out stuff that isn't around any more.
}

#pragma mark - Cache Delegate

- (void) cache:(NSCache *)cache willEvictObject:(id)obj
{
    // Synchronize the item to disk before evicting it
    [self _synchronizeCacheItem: obj];
    [self.cacheKeys removeObject: [obj key]];
}

@end

