//
//  VideoCreator.h
//  MirrorReality
//
//  Created by Anton Malyshev on 18/03/16.
//
//

#import <Foundation/Foundation.h>

@interface VideoCreator : NSObject
{
    NSString * videoFileSaved;
    NSString * audioFileSaved;
    NSString * compositionFileSaved;
}

- (void)createVideo:(NSString *)videoFile withFrames:(NSMutableArray *)frames andTimes:(NSMutableArray *)times addingAudio:(NSString*)audioFile providingCallback:(void (^)(NSError * error))onComplete;

@end
