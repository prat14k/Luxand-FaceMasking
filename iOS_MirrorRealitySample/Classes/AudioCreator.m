//
//  AudioCreator.m
//  MirrorReality
//
//  Created by Anton Malyshev on 25/03/16.
//
//

#import "AudioCreator.h"
#import <AVFoundation/AVAudioSession.h>
#import <AVFoundation/AVAudioSettings.h>
#import <AVFoundation/AVAudioRecorder.h>


@implementation AudioCreator

typedef void (^CompletionCallback)(NSError *);

CompletionCallback onCompleteCallback;

- (void) onCompletedWithError:(NSError *)error
{
    if (onCompleteCallback) {
        onCompleteCallback(error);
    }
}


- (void) startRecording:(NSString *)audioFile {
    audioFileSaved = [[NSString alloc] initWithString:audioFile];
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    NSError * err = nil;
    [audioSession setCategory :AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err) {
        NSLog(@"Error in audioSession: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        return;
    }
    [audioSession setActive:YES error:&err];
    if (err) {
        NSLog(@"Error in audioSession: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        return;
    }
    
    recordSetting = [[NSMutableDictionary alloc] init];
    [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    [recordSetting setValue :[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
    [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    
    
    NSURL * url = [NSURL fileURLWithPath:audioFileSaved];
    recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSetting error:&err];
    if (!recorder) {
        NSLog(@"Error creating recorder: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        return;
    }
    
    [recorder setDelegate:self];
    [recorder prepareToRecord];
    recorder.meteringEnabled = YES;
    
    BOOL audioHWAvailable = audioSession.inputAvailable;
    if (!audioHWAvailable) {
        NSLog(@"Error: audio input is not available");
        return;
    }
    
    [recorder record];
}

- (void) stopRecordingProvidingCallback:(void (^)(NSError * error))onComplete; {
    if (onComplete) {
        onCompleteCallback = [onComplete copy];
    }
    
    if (recorder) {
        [recorder stop];
    } else {
        NSError * unknownError = [NSError errorWithDomain:@"com.luxand.MirrorReality" code:999 userInfo:[NSDictionary dictionaryWithObject:@"Unknown error" forKey:NSLocalizedDescriptionKey]];
        [self onCompletedWithError:unknownError];
        if (recordSetting) {
            [recordSetting release];
        }
        if (recorder) {
            [recorder release];
        }
        if (audioFileSaved) {
            [audioFileSaved release];
        }
    }
}

- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag
{
    NSLog(@"audioRecorderDidFinishRecording:successfully:%d", (int)flag);
    if (!flag) {
        NSError * unknownError = [NSError errorWithDomain:@"com.luxand.MirrorReality" code:999 userInfo:[NSDictionary dictionaryWithObject:@"Unknown error" forKey:NSLocalizedDescriptionKey]];
        [self onCompletedWithError:unknownError];
    } else {
        [self onCompletedWithError:nil];
    }
    if (recordSetting) {
        [recordSetting release];
    }
    if (recorder) {
        [recorder release];
    }
    if (audioFileSaved) {
        [audioFileSaved release];
    }
}

@end