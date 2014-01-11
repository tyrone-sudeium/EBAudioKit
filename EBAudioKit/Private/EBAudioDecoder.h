//
//  EBAudioDecoder.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface EBAudioDecoder : NSObject
@property (nonatomic, readonly, strong) NSInputStream *inputStream;
@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;


// The minimum number of bytes to read before decoder and decode.
+ (uint64_t) initialBytes;

- (id) initWithInputStream: (NSInputStream*) inputStream;
+ (instancetype) decoderWithInputStream: (NSInputStream*) inputStream;

- (void) start;
- (BOOL) close;

- (BOOL) writeIntoAudioBuffers: (AudioBufferList*) bufferList numberOfFrames: (NSUInteger) frames audioTimeStamp: (const AudioTimeStamp*) timeStamp;

@end
