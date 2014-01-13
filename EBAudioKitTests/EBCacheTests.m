//
//  EBCacheTests.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 13/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "NSTask.h"
#import "EBSeekableURLInputStream.h"
#import "EBAudioCache.h"

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

/* testdata.dat:
 * The numbers 0123456789 repeated 400 times to make 4kb of data.
 *
 * testdata2.dat:
 * <line number padded to 3 digits>345678<newline>
 * This can be used to read "lines" aligned to 10-byte increments and validate
 * that the right data is coming down and is aligned correctly.
 */

@interface EBCacheTests : XCTestCase
@property (nonatomic, strong) NSTask *serverTask; // Private API is private
@end

@implementation EBCacheTests

- (void) setUp
{
//    if (self.serverTask) {
//        [self killServer];
//    }
//    self.serverTask = [[NSTask alloc] init];
//    [self.serverTask setCurrentDirectoryPath: @TOSTRING(TEST_WEB_DIR)];
//    [self.serverTask setLaunchPath: @"/usr/bin/twistd"];
//    NSArray *args = @[@"--nodaemon", @"web", @"-p", @"21337", @"--path=."];
//    [self.serverTask setArguments: args];
//    [self.serverTask launch];
}

- (void) killServer
{
//    [self.serverTask interrupt]; // Send a SIGINT
//    [self.serverTask waitUntilExit];
//    self.serverTask = nil;
}

- (void) testTestServerIsRunning
{
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString: @"http://localhost:21337/testdata.dat"]];
    [req setValue: @"bytes=12-20" forHTTPHeaderField: @"Range"];
    NSURLResponse *resp = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest: req returningResponse: &resp error: &error];
    if (resp == nil || error != nil) {
        XCTFail(@"%@", error.localizedDescription);
    }
    NSString *str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    XCTAssertEqualObjects(@"234567890", str, @"downloaded data did not match");
}

- (void) tearDown
{
    [self killServer];
}

@end
