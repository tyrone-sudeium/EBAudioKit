//
//  EBSeekableInputStream.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 8/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol EBSeekableStream <NSObject>
@property (nonatomic, readonly) NSUInteger position;

- (void) seekTo: (uint64_t) offset;

@end

@interface EBSeekableInputStream : NSInputStream <EBSeekableStream>

@end
