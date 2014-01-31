//
//  EBOpusDecoder.m
//  EBAudioKit
//
//  Created by Tyrone Trevorrow on 7/01/14.
//  Copyright (c) 2014 Sudeium. All rights reserved.
//

#import "EBOpusDecoder.h"
#import "EBSeekableURLInputStream.h"
#import "TPCircularBuffer+AudioBufferList.h"
#import "opusfile.h"
#import "opus.h"

static const int kAudioBufferLength = 230400;

@interface EBOpusDecoder () {
    @protected
    int64_t _pos;
    int64_t _readpos;
    TPCircularBuffer _circularBuffer;
    dispatch_source_t _timer;
    dispatch_queue_t _decodeQueue;
    AudioStreamBasicDescription _audioDescription;
    BOOL _waitingForConsumer;
    BOOL _stop;
    BOOL _channelIsPlaying;
    BOOL _streamOpen;
    
    BOOL _atEndOfStream;
    BOOL _atEndOfAudioBuffer;
    
    SInt64 _lengthInFrames;
    SInt64 _playhead;
    
    int _currentOpusLink;
}
@property (nonatomic, assign) OggOpusFile *opusFile;
@property (nonatomic, strong) NSArray *leftOvers;
@property (nonatomic, strong) NSMutableData *decoded;
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

- (AudioStreamBasicDescription) audioDescription
{
    AudioStreamBasicDescription audioDescription;
    memset(&audioDescription, 0, sizeof(audioDescription));
    audioDescription.mFormatID          = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags       = kLinearPCMFormatFlagIsSignedInteger;
    audioDescription.mChannelsPerFrame  = 2;
    audioDescription.mBytesPerPacket    = 4;
    audioDescription.mFramesPerPacket   = 1;
    audioDescription.mBytesPerFrame     = 4;
    audioDescription.mBitsPerChannel    = 16;
    audioDescription.mSampleRate        = 48000.0;
    return audioDescription;
}

+ (uint64_t) initialBytes
{
    return 60000; // 60k.
}

- (id) initWithInputStream: (NSInputStream*) inputStream
{
    self = [super initWithInputStream: inputStream];
    if (self) {
        TPCircularBufferInit(&_circularBuffer, kAudioBufferLength);
        _decodeQueue = dispatch_queue_create("com.sudeium.EBAudioKit.decode_queue", DISPATCH_QUEUE_SERIAL);
        _audioDescription = [self audioDescription];
    }
    return self;
}

- (void) dealloc
{
    TPCircularBufferCleanup(&_circularBuffer);
}

- (void) start
{
    if (!_streamOpen) {
        [self.inputStream open];
        _streamOpen = YES;
        _playhead = 0;
        _currentOpusLink = -1;
        dispatch_async(_decodeQueue, ^{
            NSMutableData *initialBytes = [NSMutableData dataWithCapacity: (NSUInteger)[[self class] initialBytes]];
            NSInteger read = [self.inputStream read: initialBytes.mutableBytes maxLength: (NSUInteger)[[self class] initialBytes]];
            _pos = read;
            static const OpusFileCallbacks callbacks = { decoder_read, decoder_seek, decoder_tell, decoder_close };
            int error = 0;
            self.opusFile = op_open_callbacks((__bridge void *)(self), &callbacks, initialBytes.bytes, read, &error);
            if (self.opusFile && error == 0) {
                dispatch_async_f(_decodeQueue, (__bridge void*) self, decode_cycle);
                _channelIsPlaying = YES;
            } else {
                // Can't play this
            }
        });
    } else {
        _channelIsPlaying = YES;
    }
}

static NSCountedSet* retainedDecoders = NULL;
__attribute__((constructor)) static void setupRetainedDecoders()
{
    // Alas, ARC doesn't allow us to retain self. This is a ghetto workaround to
    // ensure decoders are properly retained while messages are queued.
    retainedDecoders = [NSCountedSet new];
}

static void decode_cycle(void *context)
{
    EBOpusDecoder *self = (__bridge EBOpusDecoder*) context;
    [retainedDecoders removeObject: self];
    
    if (self.opusFile == NULL || self->_stop) {
        return;
    }
    
    // Opus likes 120ms increments, so we'll try to create buffers that big each cycle
    // 1 buffer, since Opus always outputs interleaved stereo PCM
    // Timestamp is nil, because we have no idea when this shit will be consumed.
    // TODO: Work out how to create these timestamps based on Opus' metadata.
    // Bytes per buffer = 23040: 48000 (samples per sec) * 0.12 (120ms) * 2 (channels per buffer) * 2 (bytes per sample)
    
    int32_t availableBytes = 0;
    TPCircularBufferHead(&(self->_circularBuffer), &availableBytes);
    AudioBufferList *bufList = nil;
    int previousOpusLink = self->_currentOpusLink;
    if (availableBytes >= 23040) { // Do a quick sanity check before trying to allocate memory
        bufList = TPCircularBufferPrepareEmptyAudioBufferList(&(self->_circularBuffer), 1, 23040, NULL);
    }
    if (bufList) {
        ogg_int64_t offset = op_pcm_tell(self.opusFile);
        int samplesRead = op_read_stereo(self.opusFile, bufList->mBuffers[0].mData, bufList->mBuffers[0].mDataByteSize / sizeof(opus_int16));
        if (samplesRead > 0) {
            self->_currentOpusLink = op_current_link(self.opusFile);
            if (self->_currentOpusLink != previousOpusLink || self->_lengthInFrames <= 0) {
                // Get the duration, notify it has changed
                self->_lengthInFrames = op_pcm_total(self.opusFile, -1);
                if (self->_lengthInFrames > 0 && self.delegate) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate audioDecoderChangedDuration: self];
                    });
                }
            }
            AudioTimeStamp ts;
            ts.mSampleTime = offset;
            TPCircularBufferCopyAudioBufferList(&(self->_circularBuffer), bufList, &ts, samplesRead, &self->_audioDescription);
        } else if (samplesRead == 0) {
            [self close];
            return;
        } else {
            // Opus error
            if (samplesRead != OP_HOLE) {
                [self close];
                return;
            }
        }
        if (!self->_stop) {
            [retainedDecoders addObject: self];
            dispatch_async_f(self->_decodeQueue, context, decode_cycle);
        }
    } else {
        // Give the audio player some time to consume the buffers, yielding the CPU.
        
        // We delay using GCD instead of sleep so that it's possible to inject some other
        // work into this GCD queue while it's waiting. This is a means of thread-safety,
        // i.e If we wanted to add a "stop" flag which will prevent further decoding, we
        // could queue up the setting of this flag in a block on this queue, which would
        // ensure that there's no way this flag is getting written to at the same time
        // decode_cycle is running.
        if (!self->_stop) {
            [retainedDecoders addObject: self];
            dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC), self->_decodeQueue, context, decode_cycle);
        }
    }
}

- (int) read: (unsigned char*) ptr maxLength:(NSUInteger)len
{
    printf("read request from: %lli len: %i\n", _pos, len);
    NSInteger read = [self.inputStream read: ptr maxLength: len];
    _pos += read;
    return (int) read;
}

- (int) seekTo: (int64_t) offset relativeTo: (int) position
{
    printf("seek request to: %lli whence: %i\n", offset, position);
    if ([self.inputStream conformsToProtocol: @protocol(EBSeekableStream)]) {
        NSInputStream<EBSeekableStream> *stream = (id) self.inputStream;
        if (position == SEEK_SET) {
            [stream seekToOffset: offset];
            _pos = offset;
        } else if (position == SEEK_CUR) {
            [stream seekToOffset: _pos + offset];
            _pos += offset;
        } else if (position == SEEK_END) {
            _pos = [stream length];
            [stream seekToOffset: _pos];
        }

        return 0;
    } else {
        return -1;
    }

    return 0;
}

- (int64_t) currentPosition
{
    return _pos;
}

- (int64_t) position
{
    return _playhead;
}

- (uint64_t) duration
{
    return (_lengthInFrames > 0 ? _lengthInFrames : 0);
}

- (BOOL) close
{
    _atEndOfStream = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkIfAtEndOfFile];
    });
    [(EBSeekableURLInputStream*) self.inputStream prepareToClose];
    dispatch_sync(_decodeQueue, ^{
        self.opusFile = NULL;
        [self.inputStream close];
        self->_stop = YES;
    });
    if (_timer) {
        dispatch_source_cancel(_timer);
    }
    return YES;
}

- (void) checkIfAtEndOfFile
{
    if (self.delegate && _atEndOfStream && _atEndOfAudioBuffer) {
        [self.delegate audioDecoderClosed: self];
    }
}

static void notifyPlaybackStopped(AEAudioController *audioController, void *userInfo, int length)
{
    // TODO: Memory management
    // I have no idea what the ARC semantics of the below will do :(
//    EBOpusDecoder * __strong *ptrToSelf = (EBOpusDecoder *__strong*)userInfo;
//    EBOpusDecoder *self = *ptrToSelf;
    
    EBOpusDecoder* self = (__bridge id)*((void**)userInfo);
    self->_atEndOfAudioBuffer = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkIfAtEndOfFile];
    });
}

static OSStatus renderCallback(id                        channel,
                               AEAudioController        *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    // This is on the realtime Core Audio thread. Don't do any Objective-C, mallocs
    // or locks here.
    EBOpusDecoder *self = (EBOpusDecoder*)channel;
    
    SInt64 playhead = self->_playhead;
    SInt64 originalPlayhead = playhead;
    
    if (!self->_channelIsPlaying) return noErr;
    
    if (self->_lengthInFrames > 0 && playhead >= self->_lengthInFrames) {
        // Notify main thread that playback has finished
        AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyPlaybackStopped, &self, sizeof(EBOpusDecoder*));
        self->_channelIsPlaying = NO;
        return noErr;
    }
    
    TPCircularBufferDequeueBufferListFrames(&self->_circularBuffer,
                                            &frames,
                                            audio,
                                            NULL,
                                            &self->_audioDescription);
    
    playhead += frames;
    if (self->_lengthInFrames > 0 && playhead >= self->_lengthInFrames) {
        // Notify main thread that playback has finished
        AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyPlaybackStopped, &self, sizeof(EBOpusDecoder*));
        self->_channelIsPlaying = NO;
    }
    
    OSAtomicCompareAndSwap64(originalPlayhead, playhead, &self->_playhead);
    return noErr;
}

-(AEAudioControllerRenderCallback)renderCallback {
    return renderCallback;
}

@end
