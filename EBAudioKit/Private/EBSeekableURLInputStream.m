//
//  EBSeekableURLInputStream.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 8/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

// This file is EBAudioKit's special sauce.

// Our strategy here is to write every HTTP chunk immediately
// to disk, and when the consumer asks to read from this stream, it
// will read it off the disk. If the consumer tries to read from a
// chunk that isn't ready yet (which we'll track with an index set),
// then we need to first fetch a range from HTTP corresponding from where
// the consumer is asking up to the start of the next available chunk.
// Once that block finishes, initiate another HTTP from after that chunk
// to the start of the next available chunk, until the entire file is
// downloaded. This way, you can seek around an unfinished file, and the
// parts that you do download will end up cached on disk, and the next time
// you play the track it will still have cached the bits that you played
// and will only download to complete the bits that have not.

#import "EBSeekableURLInputStream.h"
#import "EBAudioCache.h"

@protocol EBURLOperationDelegate <NSObject>
- (void) URLOperationDidFinish: (EBURLOperation*) operation;
- (void) URLOperationDidUpdateCache: (EBURLOperation*) operation;
- (void) URLOperation: (EBURLOperation*) operation failedWithError: (NSError*) error;
@end

@interface EBURLOperation () <NSURLConnectionDataDelegate> {
    BOOL _finished;
    NSInteger _byteOffset;
}
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation EBURLOperation

- (void) start
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString: self.URLString] cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 10];
    if (self.downloadRange.length > 0) {
        NSString *httpRange = [NSString stringWithFormat: @"%i-%i", self.downloadRange.location, self.downloadRange.location + self.downloadRange.length];
        [request setValue: httpRange forHTTPHeaderField: @"Range"];
    }
    self.connection = [[NSURLConnection alloc] initWithRequest: request delegate: self];
    [self.connection start];
}

- (void) cancel
{
    [self.connection cancel];
    [self finish];
}

- (void) finish
{
    [self willChangeValueForKey: @"isFinished"];
    _finished = YES;
    [self didChangeValueForKey: @"isFinished"];
    
}

- (BOOL) isFinished
{
    return _finished;
}

- (BOOL) isConcurrent
{
    return YES;
}

- (BOOL) isExecuting
{
    return !_finished;
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self finish];
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (self.downloadRange.length == 0) {
        // Only set the byte size if we're asking for the entire file
        self.cacheItem.byteSize = response.expectedContentLength;
    }
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.cacheItem cacheData: data representingRangeInFile: NSMakeRange(self.downloadRange.location + _byteOffset, data.length)];
    _byteOffset += data.length;
}

@end

@interface EBSeekableURLInputStream () <EBURLOperationDelegate>
@property (assign) BOOL cancelRead;
@property (nonatomic, strong) EBURLOperation *currentOperation;
@property (nonatomic, strong) NSThread *blockingThread;
@end

@implementation EBSeekableURLInputStream {
    NSUInteger _pos;
}

// Returns a zero range {0,0} if need entire file
// Returns a zero-length range at the end of file if at end of file
- (NSRange) nextDownloadRange
{
    if (self.cacheItem.byteSize == 0) {
        return NSMakeRange(0, 0);
    }
    
    NSIndexSet *indices = self.cacheItem.cachedIndexes;
    NSUInteger nextIndex = [indices indexGreaterThanIndex: _pos];
    if (nextIndex == NSNotFound) {
        // We need to get rest of the file, nothing else is cached
        return NSMakeRange(_pos, (NSInteger) self.cacheItem.byteSize - _pos);
    } else {
        return NSMakeRange(_pos, nextIndex - _pos);
    }
}

- (void) startDownloadWorker
{
    // If we don't know how big the file is (we've never done a single GET) or we haven't finished caching the
    // entire file yet...
    if (self.cacheItem.byteSize == 0 || ![self.cacheItem.cachedIndexes containsIndexesInRange: NSMakeRange(0, (NSUInteger) self.cacheItem.byteSize)]) {
        // Then we need to start a download worker
        self.currentOperation = [EBURLOperation new];
        self.currentOperation.cacheItem = self.cacheItem;
        self.currentOperation.URLString = self.cacheItem.remoteURL;
        if (self.cacheItem.byteSize == 0) {
            self.currentOperation.downloadRange = NSMakeRange(0, 0); // get entire file
        } else {
            self.currentOperation.downloadRange = [self nextDownloadRange];
        }
    }
}

- (BOOL) canFulfilReadRequest: (NSUInteger*) len
{
    // We can fulfil the read request if we have the range specified from _pos -> _pos+len, OR
    // if _pos + len goes to the end of file and we have from _pos to end of file cached
    NSUInteger safeLen = *len;
    if (self.cacheItem.byteSize > 0 && _pos + *len > self.cacheItem.byteSize) {
        safeLen = (NSUInteger) self.cacheItem.byteSize - _pos;
    }
    *len = safeLen;
    if ([self.cacheItem.cachedIndexes containsIndexesInRange: NSMakeRange(_pos, safeLen)]) {
        return YES;
    } else {
        return NO;
    }
}

- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    // Like all other input streams, this one should block(!) the caller until
    // the data is actually available.
    
    [self startDownloadWorker];
    NSUInteger safeLen = len; // safeLen should never overflow
    self.blockingThread = [NSThread currentThread];
    while (![self canFulfilReadRequest: &safeLen]) {
        // Block for a while
        [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
        if (self.cancelRead) {
            return 0;
        }
    }
    
    const uint8_t* read = [self.cacheItem getBytesLength: safeLen fromOffset: _pos];
    if (read != NULL) {
        memcpy(buffer, read, safeLen);
    }
    return safeLen;
}

- (void) seekToOffset:(NSUInteger)offset
{
    _pos = offset;
    self.cancelRead = YES;
    [self.currentOperation cancel];
    [self startDownloadWorker];
}

#pragma mark - EBURLOperationDelegate
// NOTE: These methods execute on the URL operation's thread! Thread safety goggles, everyone!

- (void) URLOperationDidFinish: (EBURLOperation*) operation
{
    
}

- (void) URLOperationDidUpdateCache: (EBURLOperation*) operation
{
    
}

- (void) URLOperation: (EBURLOperation*) operation failedWithError: (NSError*) error
{
    
}

@end
