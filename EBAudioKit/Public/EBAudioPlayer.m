//
//  EBAudioPlayer.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "TheAmazingAudioEngine.h"
#import "EBAudioPlayer.h"
#import "EBAudioPlayerItem.h"
#import "EBAudioCache.h"
#import "EBOpusDecoder.h"
#import "EBSeekableURLInputStream.h"
#import "EBAudioPlayerItem+Private.h"
#import "opusfile.h"
#import "opus.h"

@interface EBAudioPlayer () {
    BOOL _preparedToPlay;
    NSUInteger _positionInQueue;
    CMTime _previousPos;
}
@property (nonatomic, strong) AEAudioController *audioController;
@property (nonatomic, strong) NSTimer *positionTimer;
@end

@implementation EBAudioPlayer

- (id) init
{
    self = [super init];
    if (self) {
        AudioStreamBasicDescription audioDescription;// = [AEAudioController interleaved16BitStereoAudioDescription];
        memset(&audioDescription, 0, sizeof(audioDescription));
        
        // TODO: Not every decoder will have this audio description...
        // I need to work out the specifics of setting up an AE channel with a totally different audio desc.
        audioDescription.mFormatID          = kAudioFormatLinearPCM;
        audioDescription.mFormatFlags       = kLinearPCMFormatFlagIsSignedInteger;
        audioDescription.mChannelsPerFrame  = 2;
        audioDescription.mBytesPerPacket    = 4;
        audioDescription.mFramesPerPacket   = 1;
        audioDescription.mBytesPerFrame     = 4;
        audioDescription.mBitsPerChannel    = 16;
        audioDescription.mSampleRate        = 48000.0;
        self.audioController = [[AEAudioController alloc] initWithAudioDescription: audioDescription];
        
        self.positionUpdateInterval = 1.0/30.0;
    }
    return self;
}

- (EBAudioPlayerItem*) currentItem
{
    return self.playbackQueue[_positionInQueue];
}

- (NSUInteger) positionInQueue
{
    return _positionInQueue;
}

- (void) setPositionUpdateInterval:(NSTimeInterval)positionUpdateInterval
{
    [self willChangeValueForKey: @"positionUpdateInterval"];
    _positionUpdateInterval = positionUpdateInterval;
    [self didChangeValueForKey: @"positionUpdateInterval"];
    if (self.positionTimer) {
        [self.positionTimer invalidate];
    }
    self.positionTimer = [NSTimer scheduledTimerWithTimeInterval: _positionUpdateInterval target: self selector: @selector(_positionTimerTick) userInfo:nil repeats: YES];
}

- (void) setPlaybackQueue:(NSArray *)playbackQueue
{
    [self stop];
    _positionInQueue = 0;
    for (EBAudioPlayerItem *oldItem in _playbackQueue) {
        [[NSNotificationCenter defaultCenter] removeObserver: self name: EBAudioPlayerItemStatusChangedNotification object: oldItem];
    }
    [self willChangeValueForKey: @"playbackQueue"];
    _playbackQueue = playbackQueue.copy;
    [self didChangeValueForKey: @"playbackQueue"];
    for (EBAudioPlayerItem *newItem in _playbackQueue) {
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(_itemChanged:) name: EBAudioPlayerItemStatusChangedNotification object: newItem];
    }
}

- (void) prepareToPlay
{
    if (!_preparedToPlay) {
        _preparedToPlay = YES;
        [self skipTo: 0];
    }
}

- (BOOL) isPlaying
{
    return [self.audioController running];
}

- (void) play
{
    [self prepareToPlay];
    [self.audioController start: NULL];
    [self informDelegateStatusChanged];
}

- (void) pause
{
    [self informDelegateStatusChanged];
}

- (void) stop
{
    [self.audioController stop];
    if (_preparedToPlay) {
        [self.audioController removeChannels: @[ self.currentItem.audioDecoder ]];
        [self.currentItem.audioDecoder close];
        // These objects are not reusable
        self.currentItem.audioDecoder = nil;
        self.currentItem.inputStream = nil;
        _preparedToPlay = NO;
        [self informDelegateStatusChanged];
    }
}

- (void) skipNext
{
    if (_positionInQueue == self.playbackQueue.count) {
        [self stop];
    } else {
        // TODO: Gapless?
        [self skipTo: _positionInQueue + 1];
    }
}

- (void) skipPrevious
{
    if (_positionInQueue == 0 && self.currentItem != nil && self.playbackQueue.count > 0) {
        [self seekTo: kCMTimeZero];
    } else {
        [self skipTo: _positionInQueue - 1];
    }
}

- (void) seekTo: (CMTime) seekTime
{
    [self.currentItem.inputStream seekToOffset: 0];
}

- (void) skipTo:(NSUInteger)index
{
    EBAudioPlayerItem *previousItem = self.currentItem;
    _positionInQueue = index;
    
    if (_preparedToPlay) {
        // Add the new item and start it
        // We do this before removing the old one so iOS has no chance to suspend us
        // if we're in the background
        [self.audioController addChannels: @[ self.currentItem.audioDecoder ]];
        [self.currentItem.audioDecoder start];
        
        if (previousItem != nil && previousItem != self.currentItem) {
            [previousItem.audioDecoder close];
            [self.audioController removeChannels: @[ previousItem.audioDecoder ]];
            previousItem.audioDecoder = nil;
            previousItem.inputStream = nil;
        }
        [self informDelegateStatusChanged];
    }
}

- (void) _positionTimerTick
{
    CMTime newPos = self.currentItem.position;
    if (newPos.value != _previousPos.value && self.playing && self.delegate) {
        [self.delegate audioPlayerPositionChanged: self];
    }
    _previousPos = newPos;
    
}

- (void) _itemChanged: (NSNotification*) notification
{
    EBAudioPlayerItem *item = notification.object;
    if (item.status == EBAudioPlayerItemStatusReadyToPlay && CMTIME_COMPARE_INLINE(item.position, ==, item.duration)) {
        // Reached the end of the track
        [self skipNext];
    }
    [self.delegate audioPlayerStatusChanged: self];
}

- (void) informDelegateStatusChanged
{
    if (self.delegate) {
        [self.delegate audioPlayerStatusChanged: self];
    }
}

@end
