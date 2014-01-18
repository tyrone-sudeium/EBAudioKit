//
//  EBAudioPlayerItem+Private.h
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 18/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>

@class EBSeekableURLInputStream;

@interface EBAudioPlayerItem ()
@property (nonatomic, strong) EBSeekableURLInputStream *inputStream;
@property (nonatomic, strong) EBAudioDecoder *audioDecoder;
@end