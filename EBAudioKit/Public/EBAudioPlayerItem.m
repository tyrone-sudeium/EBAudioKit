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

NSString * const EBAudioPlayerItemStatusChangedNotification = @"EBAudioPlayerItemStatusChangedNotification";

@interface EBAudioPlayerItem () <EBSeekableURLInputStreamDelegate, EBAudioDecoderDelegate>
@property (nonatomic, readwrite, strong) NSURL *URL;
@property (nonatomic, readwrite, assign) CMTime duration;
@property (nonatomic, readwrite, assign) CMTime position;
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
        _inputStream.delegate = self;
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

- (BOOL) playbackLikelyToKeepUp
{
    // This requires a relatively complex algorithm actually...
    // Shortcuts for now.
    if ([_inputStream atEOF] || [_inputStream hasEntireFileCached]) {
        return YES;
    }
    
    return YES;
}

- (NSIndexSet*) cachedRanges
{
    return self.inputStream.cacheItem.cachedIndexes;
}

- (void) _updateDuration
{
    if (_audioDecoder == nil) {
        self.duration = kCMTimeInvalid;
    } else if (_audioDecoder.duration == UINT64_MAX) {
        self.duration = kCMTimeIndefinite;
    } else {
        AudioStreamBasicDescription desc = _audioDecoder.audioDescription;
        uint64_t lengthInFrames = _audioDecoder.duration;
        self.duration = CMTimeMake(lengthInFrames, desc.mSampleRate);
    }
}

- (void) _updatePosition
{
    if (_audioDecoder == nil) {
        self.position = kCMTimeInvalid;
    } else if (CMTIME_IS_INDEFINITE(self.duration)) {
        self.position = kCMTimeInvalid;
    } else {
        AudioStreamBasicDescription desc = _audioDecoder.audioDescription;
        int64_t positionInFrames = _audioDecoder.position;
        self.position = CMTimeMake(positionInFrames, desc.mSampleRate);
    }
}

#pragma mark - Seekable Input Stream Delegate

- (void) inputStreamDidFinishDownload:(EBSeekableURLInputStream *)stream
{
    // Update playback likely to keep up
}

- (void) inputStreamDidChangeCacheStatus:(EBSeekableURLInputStream *)stream
{
    // Propagate the update
}

- (void) inputStream:(EBSeekableURLInputStream *)stream didFailWithError:(NSError *)error
{
    // Errors suck
    self.status = EBAudioPlayerItemStatusFailed;
}

#pragma mark - Audio Decoder Delegate

- (void) audioDecoderChangedDuration:(EBAudioDecoder *)decoder
{
    [[NSNotificationCenter defaultCenter] postNotificationName: EBAudioPlayerItemStatusChangedNotification object: self userInfo: nil];
    [self _updateDuration];
}

- (void) audioDecoderClosed:(EBAudioDecoder *)decoder
{
    
}

- (void) audioDecoderReachedEndOfStream:(EBAudioDecoder *)decoder
{
    self.status = EBAudioPlayerItemStatusReadyToPlay;
}

@end
