//
//  EBOpusDecoder.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBOpusDecoder.h"
#import "opusfile.h"
#import "opus.h"

@interface EBOpusDecoder () {
    int64_t _pos;
}
@property (nonatomic, assign) OggOpusFile *opusFile;
@end

@implementation EBOpusDecoder

static int decoder_read(void *stream, unsigned char *ptr, int nbytes)
{
    EBOpusDecoder *decoder = (__bridge EBOpusDecoder*) stream;
    return [decoder read: ptr maxLength: nbytes];
}

static int decoder_seek(void *stream, opus_int64 offset, int whence)
{
    EBOpusDecoder *decoder = (__bridge EBOpusDecoder*) stream;
    return [decoder seekTo: offset relativeTo: whence];
}

static opus_int64 decoder_tell(void *stream)
{
    EBOpusDecoder *decoder = (__bridge EBOpusDecoder*) stream;
    return [decoder currentPosition];
}

static int decoder_close(void *stream)
{
    EBOpusDecoder *decoder = (__bridge EBOpusDecoder*) stream;
    if (![decoder close]) {
        return EOF; // Tell Opus it failed.
    } else {
        return 0; // Success.
    }
}

- (void) load
{
    static const OpusFileCallbacks callbacks = { decoder_read, decoder_seek, decoder_tell, decoder_close };
    int error = 0;
    self.opusFile = op_open_callbacks((__bridge void *)(self), &callbacks, NULL /*TODO*/, 0, &error);
    
}

- (int) read: (unsigned char*) ptr maxLength:(NSUInteger)len
{
    return (int) [self.inputStream read: ptr maxLength: len];
}

- (int) seekTo: (int64_t) offset relativeTo: (int) position
{
    
}

- (int64_t) currentPosition
{
    
}

- (BOOL) close
{
    
}

@end
