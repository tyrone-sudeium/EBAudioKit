//
//  EBAudioDecoder.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EBAudioDecoder : NSObject
@property (nonatomic, readonly, strong) NSInputStream *inputStream;
@property (nonatomic, readonly) NSOutputStream *outputStream;

+ (instancetype) decoderWithInputStream: (NSInputStream*) inputStream;

- (BOOL) close;

@end
