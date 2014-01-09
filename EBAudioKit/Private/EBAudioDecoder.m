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

- (BOOL) close
{
    return NO;
}

@end
