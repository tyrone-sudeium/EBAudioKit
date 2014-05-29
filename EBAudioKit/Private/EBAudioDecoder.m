//
//  EBAudioDecoder.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBAudioDecoder.h"

@interface EBAudioDecoder ()
@property (nonatomic, readwrite, strong) NSInputStream *inputStream;
@end

@implementation EBAudioDecoder

+ (uint64_t) initialBytes
{
    return 0;
}

- (id) initWithInputStream: (NSInputStream*) inputStream
{
    self = [super init];
    if (self) {
        self.inputStream = inputStream;
    }
    return self;
}

+ (EBAudioDecoder*) decoderWithInputStream: (NSInputStream*) inputStream
{
    return [[self alloc] initWithInputStream: inputStream];
}

- (void) start
{
    // Override in subclasses
}

- (void) pause
{
    // Override in subclasses
}

- (BOOL) close
{
    // Override in subclasses
    return NO;
}

- (AEAudioControllerRenderCallback) renderCallback
{
    return NULL;
}

- (int64_t) position
{
    return 0;
}

- (uint64_t) duration
{
    return 0;
}

- (void) forceSeekTo:(CMTime)seekTime
{
    return 0;
}

@end
