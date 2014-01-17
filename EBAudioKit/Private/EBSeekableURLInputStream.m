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

@interface EBSeekableURLOperation () <NSURLConnectionDataDelegate> {
    BOOL _finished;
    NSInteger _byteOffset;
}
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation EBSeekableURLOperation

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
    self.cacheItem.byteSize = response.expectedContentLength;
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.cacheItem cacheData: data representingRangeInFile: NSMakeRange(self.downloadRange.location + _byteOffset, data.length)];
    _byteOffset += data.length;
}

@end

@interface EBSeekableURLInputStream ()
@property (assign) BOOL cancelRead;
@end

@implementation EBSeekableURLInputStream {
    NSUInteger _pos;
}


- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    // Like all other input streams, this one should block(!) the caller until
    // the data is actually available.
    
    // Block for a while
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    if (self.cancelRead) {
        return 0;
    }
    
    return 0;
}

- (void) seekToOffset:(NSUInteger)offset
{
    _pos = offset;
    self.cancelRead = YES;
}

@end
