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
}
@property (nonatomic, strong) AEAudioController *audioController;
@property (nonatomic, strong) EBOpusDecoder *decoder;
@end

@implementation EBAudioPlayer

- (id) init
{
    self = [super init];
    if (self) {
        AudioStreamBasicDescription audioDescription;// = [AEAudioController interleaved16BitStereoAudioDescription];
        memset(&audioDescription, 0, sizeof(audioDescription));
        audioDescription.mFormatID          = kAudioFormatLinearPCM;
        audioDescription.mFormatFlags       = kLinearPCMFormatFlagIsSignedInteger;
        audioDescription.mChannelsPerFrame  = 2;
        audioDescription.mBytesPerPacket    = 4;
        audioDescription.mFramesPerPacket   = 1;
        audioDescription.mBytesPerFrame     = 4;
        audioDescription.mBitsPerChannel    = 16;
        audioDescription.mSampleRate        = 48000.0;
        self.audioController = [[AEAudioController alloc] initWithAudioDescription: audioDescription];
    }
    return self;
}

- (EBAudioPlayerItem*) currentItem
{
    return self.playbackQueue[_positionInQueue];
}

- (void) setPlaybackQueue:(NSArray *)playbackQueue
{
    [self stop];
    _positionInQueue = 0;
    [self willChangeValueForKey: @"playbackQueue"];
    _playbackQueue = playbackQueue.copy;
    [self didChangeValueForKey: @"playbackQueue"];
}

- (void) prepareToPlay
{
    if (!_preparedToPlay) {
        [self.audioController addChannels: @[ self.currentItem.audioDecoder ]];
        [self.currentItem.audioDecoder start];
        _preparedToPlay = YES;
    }
}

- (void) play
{
    [self prepareToPlay];
    [self.audioController start: NULL];
}

- (void) pause
{
    [self.audioController stop];
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
    }
}

- (void) skipNext
{
    
}

- (void) skipPrevious
{
    
}

- (void) seekTo: (CMTime) seekTime
{
    
}

@end
