//
//  EBAudioPlayerItem.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBAudioPlayerItem.h"
#import "EBSeekableURLInputStream.h"
#import "EBAudioCache.h"
#import "EBOpusDecoder.h"

@interface EBAudioPlayerItem ()
@property (nonatomic, readwrite, strong) NSURL *URL;
@property (nonatomic, readwrite, assign) CMTime duration;
@property (nonatomic, readwrite, assign) EBAudioPlayerItemStatus status;
@property (nonatomic, strong) EBSeekableURLInputStream *inputStream;
// TODO: Other decoders... and some way to switch between them
// This is problematic right now because the decoder is the thing that asks
// for the initial bytes, but we can't create a decoder object until we know
// what data type it is.
@property (nonatomic, strong) EBOpusDecoder *audioDecoder;
@end

@implementation EBAudioPlayerItem

- (id) initWithURL:(NSURL *)aURL
{
    self = [super init];
    if (self) {
        self.URL = aURL;
    }
    return self;
}

+ (EBAudioPlayerItem*) playerItemWithURL:(NSURL *)aURL
{
    return [[self alloc] initWithURL: aURL];
}

- (EBSeekableURLInputStream*) inputStream
{
    if (_inputStream == nil) {
        _inputStream = [EBSeekableURLInputStream new];
        _inputStream.cacheItem = [[EBAudioCache defaultCache] cachedItemForKey: self.URL.absoluteString];
    }
    return _inputStream;
}

- (EBOpusDecoder*) audioDecoder
{
    if (_audioDecoder == nil) {
        _audioDecoder = [EBOpusDecoder decoderWithInputStream: self.inputStream];
    }
    return _audioDecoder;
}

- (CMTime) duration
{
    if (_audioDecoder == nil) {
        return kCMTimeInvalid;
    } else if (_audioDecoder.duration == UINT64_MAX) {
        return kCMTimeIndefinite;
    } else {
        AudioStreamBasicDescription desc = _audioDecoder.audioDescription;
        uint64_t lengthInFrames = _audioDecoder.duration;
        return CMTimeMake(lengthInFrames, desc.mSampleRate);
    }
}

- (CMTime) position
{
    if (_audioDecoder == nil) {
        return kCMTimeInvalid;
    } else if (CMTIME_IS_INDEFINITE(self.duration)) {
        return kCMTimeInvalid;
    } else {
        AudioStreamBasicDescription desc = _audioDecoder.audioDescription;
        int64_t positionInFrames = _audioDecoder.position;
        return CMTimeMake(positionInFrames, desc.mSampleRate);
    }
}

@end
