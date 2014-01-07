//
//  EBAudioPlayerItem.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBAudioPlayerItem.h"

@interface EBAudioPlayerItem ()
@property (nonatomic, readwrite, strong) NSURL *URL;
@property (nonatomic, readwrite, assign) CMTime duration;
@property (nonatomic, readwrite, assign) EBAudioPlayerItemStatus status;
@end

@implementation EBAudioPlayerItem

- (id) initWithURL:(NSURL *)aURL
{
    self = [super init];
    if (self) {
        self.URL = aURL;
    }
    return self;
}

+ (EBAudioPlayerItem*) playerItemWithURL:(NSURL *)aURL
{
    return [[self alloc] initWithURL: aURL];
}

@end
