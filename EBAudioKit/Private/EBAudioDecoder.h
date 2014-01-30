//
//  EBAudioDecoder.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TheAmazingAudioEngine.h"

@class EBAudioDecoder;
@protocol EBAudioDecoderDelegate <NSObject>
- (void) audioDecoderClosed: (EBAudioDecoder*) decoder;
- (void) audioDecoderChangedDuration: (EBAudioDecoder*) decoder;
@end

@interface EBAudioDecoder : NSObject <AEAudioPlayable>
@property (nonatomic, readonly, strong) NSInputStream *inputStream;
@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;
@property (nonatomic, weak) id<EBAudioDecoderDelegate> delegate;
@property (nonatomic, readonly) int64_t position;
@property (nonatomic, readonly) uint64_t duration; // In frames. Calculate the duration in seconds by dividing by the sample rate in audioDescription

// The minimum number of bytes to read before decoder and decode.
+ (uint64_t) initialBytes;

- (id) initWithInputStream: (NSInputStream*) inputStream;
+ (instancetype) decoderWithInputStream: (NSInputStream*) inputStream;

- (void) start;
- (void) pause; // Stop filling the realtime audio buffer, but don't close or tear down anything
- (BOOL) close;

@end
