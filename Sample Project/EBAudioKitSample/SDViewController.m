//
//  SDViewController.m
//  EBAudioKitSample
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "SDViewController.h"
#import "EBAudioPlayerItem.h"
#import "EBAudioPlayer.h"

@interface SDViewController ()
@property (nonatomic, strong) EBAudioPlayer *player;
@end

@implementation SDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.player = [[EBAudioPlayer alloc] init];
    NSURL *url = [[NSBundle mainBundle] URLForResource: @"EBAudioKitSample" withExtension:@"opus"];
    self.player.playbackQueue = @[ [EBAudioPlayerItem playerItemWithURL: url] ];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonAction:(id)sender
{
    [self.player play];
}

@end
