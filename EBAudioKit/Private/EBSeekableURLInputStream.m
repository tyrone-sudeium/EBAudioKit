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
@property (nonatomic, weak) id<EBURLOperationDelegate> delegate;
@end

@implementation EBURLOperation

- (void) start
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString: self.URLString] cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 10];
    if (self.downloadRange.length > 0) {
        NSString *httpRange = [NSString stringWithFormat: @"bytes=%lu-%lu", (unsigned long)self.downloadRange.location, (unsigned long)self.downloadRange.location + self.downloadRange.length];
        [request setValue: httpRange forHTTPHeaderField: @"Range"];
    }
    self.connection = [[NSURLConnection alloc] initWithRequest: request delegate: self];
    [self.connection start];
}

- (void) cancel
{
    [self.connection cancel];
    self.connection = nil;
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
    [self.delegate URLOperationDidFinish: self];
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
    NSRange range = NSMakeRange(self.downloadRange.location + _byteOffset, data.length);
    [self.cacheItem cacheData: data representingRangeInFile: range];
    _byteOffset += data.length;
    [self.delegate URLOperationDidUpdateCache: self];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.delegate URLOperation: self failedWithError: error];
    [self finish];
}

@end

@interface EBSeekableURLInputStream () <EBURLOperationDelegate> {
    BOOL _reading;
}
@property (assign) BOOL cancelRead;
@property (nonatomic, strong) EBURLOperation *currentOperation;
@property (nonatomic, strong) dispatch_queue_t blockingQueue;
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
    __block NSInteger firstGap = NSNotFound;
    [indices enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        if ((range.location + range.length) > _pos) {
            firstGap = range.location + range.length;
            *stop = YES;
        }
    }];
    if (firstGap == NSNotFound) {
        // Nothing is cached from _pos onward, get everything from _pos onward
        return NSMakeRange(_pos, (NSInteger) self.cacheItem.byteSize - _pos);
    } else if (firstGap >= self.cacheItem.byteSize) {
        firstGap = NSNotFound;
        // Everything from _pos onward is cached; find the first actual gap.
        [indices enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
            firstGap = range.location + range.length;
            *stop = YES;
        }];
        if (firstGap == NSNotFound) {
            // Nothing at all is cached, get entire file
            return NSMakeRange(0, 0);
        }
    }
    
    // Fetch all bytes to the end of the gap
    NSUInteger nextIndex = [indices indexGreaterThanOrEqualToIndex: firstGap];
    if (nextIndex == NSNotFound) {
        // We need to get rest of the file, nothing else is cached
        return NSMakeRange(firstGap, (NSInteger) self.cacheItem.byteSize - firstGap);
    } else {
        return NSMakeRange(firstGap, nextIndex - firstGap);
    }
}

- (void) startDownloadWorker
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.currentOperation != nil) {
            // Don't interrupt an in-progress worker.
            return;
        }
        
        // If we don't know how big the file is (we've never done a single GET) or we haven't finished caching the
        // entire file yet...
        if (self.cacheItem.byteSize == 0 || ![self hasEntireFileCached]) {
            // Then we need to start a download worker
            if ([self atEOF]) {
                // At EOF: Nothing to be done
                return;
            }
            self.currentOperation = [EBURLOperation new];
            self.currentOperation.cacheItem = self.cacheItem;
            self.currentOperation.URLString = self.cacheItem.remoteURL;
            if (self.cacheItem.byteSize == 0) {
                self.currentOperation.downloadRange = NSMakeRange(0, 0); // get entire file
            } else {
                self.currentOperation.downloadRange = [self nextDownloadRange];
            }
            __weak EBSeekableURLInputStream *wSelf = self;
            self.currentOperation.completionBlock = ^{
                if (![wSelf.currentOperation isCancelled]) {
                    wSelf.currentOperation = nil;
                    [wSelf startDownloadWorker];
                }
            };
            [self.currentOperation start];
        }
    });
}

- (uint64_t) length
{
    return self.cacheItem.byteSize;
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

- (BOOL) atEOF
{
    if (self.cacheItem.byteSize > 0 && self.cacheItem.byteSize - _pos <= 0) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) hasEntireFileCached
{
    return [self.cacheItem.cachedIndexes containsIndexesInRange: NSMakeRange(0, (NSUInteger) self.cacheItem.byteSize)];
}

- (void) open
{
    // In the absence of something more constructive to do here, we'll just start
    // a worker if we need one.
    self.blockingQueue = dispatch_queue_create("com.sudeium.EBAudioKit.EBSeekableURLInputStreamBlockingThread", DISPATCH_QUEUE_SERIAL);
    [self startDownloadWorker];
}

- (void) prepareToClose
{
    self.cancelRead = YES;
}

- (void) close
{
    // Close the cache item and kill any pending workers
    [self.currentOperation cancel];
    self.currentOperation = nil;
    [self.cacheItem close];
}

- (BOOL) getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
    // TODO
    return NO;
}

- (BOOL) hasBytesAvailable
{
    if (self.cacheItem.byteSize == 0) {
        return YES; // Probably...
    }
    NSUInteger len = 1;
    return [self canFulfilReadRequest: &len];
}

- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    // Like all other input streams, this one should block(!) the caller until
    // the data is actually available.
    
    [self startDownloadWorker];
    __block NSUInteger safeLen = len; // safeLen should never overflow
    __block BOOL readCancelled = NO;
    _reading = YES;
    dispatch_sync(self.blockingQueue, ^{
        while (![self canFulfilReadRequest: &safeLen]) {
            @autoreleasepool {
                // Block for a while
                usleep(100);
                if (self.cancelRead) {
                    readCancelled = YES;
                    self.cancelRead = NO;
                    break;
                }
            }
        }
    });
    _reading = NO;
    if (readCancelled) {
        return 0;
    }
    
    const uint8_t* read = [self.cacheItem getBytesLength: safeLen fromOffset: _pos];
    if (read != NULL) {
        memcpy(buffer, read, safeLen);
    }
    _pos += safeLen;
    return safeLen;
}

- (void) seekToOffset:(NSUInteger)offset
{
    if (_pos != offset) {
        _pos = offset;
        if (_reading) {
            self.cancelRead = YES;
        }
        [self.currentOperation cancel];
        self.currentOperation = nil;
        [self startDownloadWorker];
    }
}

#pragma mark - EBURLOperationDelegate
// NOTE: These methods execute on the URL operation's thread! Thread safety goggles, everyone!

- (void) URLOperationDidFinish: (EBURLOperation*) operation
{
    // Start another worker if there are still unfinished chunks left in the file
    self.currentOperation = nil;
    [self startDownloadWorker];
    if ([self hasEntireFileCached]) {
        // Inform delegate we've finished
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate inputStreamDidFinishDownload: self];
        });
    }
}

- (void) URLOperationDidUpdateCache: (EBURLOperation*) operation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate inputStreamDidChangeCacheStatus: self];
    });
}

- (void) URLOperation: (EBURLOperation*) operation failedWithError: (NSError*) error
{
    self.cancelRead = YES;
    NSLog(@"%@", error.localizedDescription);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate inputStream: self didFailWithError: error];
    });
}

@end
