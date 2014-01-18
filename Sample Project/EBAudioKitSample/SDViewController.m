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

@interface SDViewController () <UITextFieldDelegate>
@property (strong, nonatomic) IBOutlet UITextField *textField;
@property (nonatomic, strong) EBAudioPlayer *player;
@end

@implementation SDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.player = [[EBAudioPlayer alloc] init];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.textField.text = @"https://eqbeats.org/track/5699/opus";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonAction:(id)sender
{
    NSURL *url = [[NSBundle mainBundle] URLForResource: @"EBAudioKitSample" withExtension:@"opus"];
    self.player.playbackQueue = @[ [EBAudioPlayerItem playerItemWithURL: url] ];
    [self.player play];
}

- (IBAction)remotePlayAction:(id)sender
{
    self.player.playbackQueue = @[ [EBAudioPlayerItem playerItemWithURL: [NSURL URLWithString:self.textField.text]] ];
    [self.player play];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    return [textField resignFirstResponder];
}

@end
