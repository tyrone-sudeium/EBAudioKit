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

@interface SDViewController () <UITextFieldDelegate, EBAudioPlayerDelegate>
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) IBOutlet UILabel *positionLabel;
@property (strong, nonatomic) IBOutlet UILabel *durationLabel;
@property (nonatomic, strong) EBAudioPlayer *player;
@end

@implementation SDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.player = [[EBAudioPlayer alloc] init];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.textField.text = @"https://eqbeats.org/track/5699/opus";
    self.player.delegate = self;
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

- (void) updateLabels
{
    CMTime durationTime = self.player.currentItem.duration;
    CMTime elapsedTime = self.player.currentItem.position;
    NSString *durationText = @"--:--";
    NSString *elapsedText = @"--:--";
    if (CMTIME_IS_VALID(durationTime) && !CMTIME_IS_INDEFINITE(durationTime)) {
        NSTimeInterval duration = CMTimeGetSeconds(durationTime);
        NSInteger durationMinutes = floorf(duration / 60.0);
        NSInteger durationSeconds = duration - (durationMinutes * 60);
        durationText = [NSString stringWithFormat: @"%i:%02i", durationMinutes, durationSeconds];
    }
    
    if (CMTIME_IS_VALID(elapsedTime) && !CMTIME_IS_INDEFINITE(elapsedTime)) {
        NSTimeInterval elapsed = CMTimeGetSeconds(self.player.currentItem.position);
        NSInteger elapsedMinutes = floor(elapsed / 60.0);
        NSInteger elapsedSeconds = elapsed - (elapsedMinutes * 60);
        elapsedText = [NSString stringWithFormat: @"%i:%02i", elapsedMinutes, elapsedSeconds];
    }
    self.durationLabel.text = durationText;
    self.positionLabel.text = elapsedText;
}

- (void) updateProgress
{
    CMTime durationTime = self.player.currentItem.duration;
    CMTime elapsedTime = self.player.currentItem.position;
    if (CMTIME_IS_VALID(durationTime) && !CMTIME_IS_INDEFINITE(durationTime) && CMTIME_IS_VALID(elapsedTime) && !CMTIME_IS_INDEFINITE(elapsedTime)) {
        self.progressView.progress = (Float64)elapsedTime.value / (Float64)durationTime.value;
    } else {
        self.progressView.progress = 0;
    }
}

- (void) audioPlayerPositionChanged:(EBAudioPlayer *)player
{
    [self updateLabels];
    [self updateProgress];
}

- (void) audioPlayerStatusChanged:(EBAudioPlayer *)player
{
    [self updateLabels];
    [self updateProgress];
}

@end
