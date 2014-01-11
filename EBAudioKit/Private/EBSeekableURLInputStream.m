//
//  EBSeekableURLInputStream.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 8/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

// This file is EBAudioKit's special sauce.

// Our strategy here is to write every HTTP chunk immediately
// to disk, and when the consumer asks to read from this stream, it
// will read it off the disk. If the consumer tries to read from a
// chunk that isn't ready yet (which we'll track with an index set),
// then we need to first fetch a range from HTTP corresponding from where
// the consumer is asking up to the start of the next available chunk.
// Once that block finishes, initiate another HTTP from after that chunk
// to the start of the next available chunk, until the entire file is
// downloaded. This way, you can seek around an unfinished file, and the
// parts that you do download will end up cached on disk, and the next time
// you play the track it will still have cached the bits that you played
// and will only download to complete the bits that have not.

#import "EBSeekableURLInputStream.h"
#import "EBAudioCache.h"

@implementation EBSeekableURLInputStream

@end
