//
//  NSObject_AudioCreator.h
//  MirrorReality
//
//  Created by Anton Malyshev on 25/03/16.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAudioRecorder.h>

@interface AudioCreator : NSObject<AVAudioRecorderDelegate>
{
    NSString * audioFileSaved; //recorderFilePath
    
    NSMutableDictionary * recordSetting;
    AVAudioRecorder * recorder;
}

- (void) startRecording:(NSString *)audioFile;

- (void) stopRecordingProvidingCallback:(void (^)(NSError * error))onComplete;

@end
