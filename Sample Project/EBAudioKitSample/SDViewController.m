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

@interface TrackCell : UITableViewCell
@property (nonatomic, strong) IBOutlet UITextField *textField;
@end

@implementation TrackCell

@end

@interface SDViewController () <UITextFieldDelegate, EBAudioPlayerDelegate>
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) IBOutlet UILabel *positionLabel;
@property (strong, nonatomic) IBOutlet UILabel *durationLabel;
@property (strong, nonatomic) IBOutlet UIButton *playPauseButton;
@property (nonatomic, strong) EBAudioPlayer *player;
@property (nonatomic, strong) NSMutableArray *tracks;
@end

@implementation SDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.player = [[EBAudioPlayer alloc] init];
	// Do any additional setup after loading the view, typically from a nib.
    NSURL *url = [[NSBundle mainBundle] URLForResource: @"EBAudioKitSample" withExtension:@"opus"];
    self.tracks = @[ url.absoluteString, @"https://eqbeats.org/track/5699/opus" ].mutableCopy;
    
    self.player.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateLabels];
    [self updateProgress];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    
    if (self.player.playing) {
        self.title = [NSString stringWithFormat: @"Playing %lu/%lu", (unsigned long)self.player.positionInQueue+1, (unsigned long)self.player.playbackQueue.count];
    } else {
        self.title = @"Not playing";
    }
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

- (IBAction)playPauseButtonAction:(id)sender
{
    NSMutableArray *tracks = [NSMutableArray arrayWithCapacity: self.tracks.count];
    for (NSString *trackURL in self.tracks) {
        [tracks addObject: [EBAudioPlayerItem playerItemWithURL: [NSURL URLWithString: trackURL]]];
    }
    self.player.playbackQueue = tracks;
    [self.player play];
}

- (IBAction)stopButtonAction:(id)sender
{
    
}

- (IBAction)addButtonAction:(id)sender
{
    [self.tracks addObject: @""];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow: self.tracks.count-1 inSection: 0];
    [self.tableView insertRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationAutomatic];
    TrackCell *cell = (id)[self.tableView cellForRowAtIndexPath: indexPath];
    [cell.textField becomeFirstResponder];
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

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tracks.count;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TrackCell *trackCell = [tableView dequeueReusableCellWithIdentifier: @"TrackCell" forIndexPath: indexPath];
    trackCell.textField.text = self.tracks[indexPath.row];
    trackCell.textField.tag = indexPath.row;
    trackCell.textField.delegate = self;
    return trackCell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.tracks removeObjectAtIndex: indexPath.row];
        [tableView deleteRowsAtIndexPaths: @[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [self.tracks replaceObjectAtIndex: textField.tag withObject: textField.text];
    return [textField resignFirstResponder];
}

@end
