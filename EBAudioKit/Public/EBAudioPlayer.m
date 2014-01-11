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
#import "EBOpusDecoder.h"
#import "EBSeekableURLInputStream.h"
#import "opusfile.h"
#import "opus.h"

@interface EBAudioPlayer ()
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
    return [self.playbackQueue firstObject];
}

- (void) play
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL: self.currentItem.URL];
    EBOpusDecoder *decoder = [EBOpusDecoder decoderWithInputStream: inputStream];
    [self.audioController addChannels: @[decoder]];
    [decoder start];
    [self.audioController start: NULL];
}

- (void) pause
{
    
}

- (void) stop
{
    
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
