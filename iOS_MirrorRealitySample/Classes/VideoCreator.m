
//
//  NSObject_VideoCreator.h
//  MirrorReality
//
//  Created by Anton Malyshev on 18/03/16.
//
//

#import "VideoCreator.h"
#import <AVFoundation/AVAssetWriter.h>
#import <AVFoundation/AVAssetWriterInput.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVVideoSettings.h>
#import <AVFoundation/AVComposition.h>
#import <AVFoundation/AVAssetExportSession.h>

@implementation VideoCreator

typedef void (^CompletionCallback)(NSError *);

CompletionCallback onCompleteCallback;

- (void) onCompletedWithError:(NSError *)error
{
    if (onCompleteCallback) {
        onCompleteCallback(error);
    }
}

- (void)createVideo:(NSString *)videoFile withFrames:(NSMutableArray *)frames andTimes:(NSMutableArray *)times addingAudio:(NSString*)audioFile providingCallback:(void (^)(NSError * error))onComplete
{
    NSLog(@"Creating video started");
    
    if (onComplete) {
        onCompleteCallback = [onComplete copy];
    }
    
    NSError * unknownError = [NSError errorWithDomain:@"com.luxand.MirrorReality" code:999 userInfo:[NSDictionary dictionaryWithObject:@"Unknown error" forKey:NSLocalizedDescriptionKey]];

    videoFileSaved = [[NSString alloc] initWithString:videoFile];
    audioFileSaved = [[NSString alloc] initWithString:audioFile];
    compositionFileSaved = nil;
    
    if (frames.count != times.count) {
        NSLog(@"Different frames and frameTimes array sizes!");
        [self onCompletedWithError:unknownError];
        return;
    }
    
    if (frames.count <= 0) {
        NSLog(@"No frames to create video!");
        [self onCompletedWithError:unknownError];
        return;
    }
    
    NSError * error = nil;
    
    AVAssetWriter * videoWriter = [[AVAssetWriter alloc] initWithURL:
                                  [NSURL fileURLWithPath:videoFile] fileType:AVFileTypeQuickTimeMovie
                                                              error:&error];
    if (!videoWriter) {
        NSLog(@"Error creating video");
        [self onCompletedWithError:unknownError];
        return;
    }
    
    UIImage * firstFrame = [UIImage imageWithData:[frames objectAtIndex:0]];
    if (!firstFrame) {
        NSLog(@"Error loading first saved frame");
        [self onCompletedWithError:unknownError];
        return;
    }
    
    int correctedWidth = 16*(((int)firstFrame.size.width)/16);
    
    NSDictionary * videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:correctedWidth], AVVideoWidthKey,
                                   [NSNumber numberWithInt:firstFrame.size.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput * videoWriterInput = [[AVAssetWriterInput
                                             assetWriterInputWithMediaType:AVMediaTypeVideo
                                             outputSettings:videoSettings] retain];
    
    AVAssetWriterInputPixelBufferAdaptor * adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                                     sourcePixelBufferAttributes:nil];
    
    if (!videoWriterInput || ![videoWriter canAddInput:videoWriterInput]) {
        NSLog(@"Error initializing video writer input");
        [self onCompletedWithError:unknownError];
        return;
    }
    
    [videoWriter addInput:videoWriterInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];

    for (int i=0; i<frames.count; ++i) {
        UIImage * frame = [UIImage imageWithData:[frames objectAtIndex:i]];
        if (frame) {
            NSNumber * time = [times objectAtIndex:i];
        
            CVPixelBufferRef buffer = nil;
            if (correctedWidth != frame.size.width) {
                int rowbytes = (int)CGImageGetBytesPerRow(frame.CGImage);
                int bits = (int)CGImageGetBitsPerPixel(frame.CGImage);
                int width = (int)CGImageGetWidth(frame.CGImage);
                int height = (int)CGImageGetHeight(frame.CGImage);
                NSLog(@"image for video frame params: %d %d %d %d, corrected width: %d", bits, rowbytes, width, height, correctedWidth);
                
                CGRect cropRect = CGRectMake(0, 0, correctedWidth, height);
                CGImageRef imageRef = CGImageCreateWithImageInRect(frame.CGImage, cropRect);
                
                CGSize s = frame.size;
                s.width = correctedWidth;
                buffer = [self pixelBufferFromCGImage:imageRef andSize:s];
                CGImageRelease(imageRef);
            } else {
                buffer = [self pixelBufferFromCGImage:frame.CGImage andSize:frame.size];
            }
            if (buffer) {
                while (!adaptor.assetWriterInput.readyForMoreMediaData) {
                    [NSThread sleepForTimeInterval:0.05];
                }
                
                CMTime frameTime = CMTimeMake((int)([time doubleValue]*10000), 10000);
                BOOL append_ok = [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
                if (!append_ok) {
                    NSLog(@"Error encoding frame!");
                }
            
                CVBufferRelease(buffer);
            }
        }
    }
    
    [videoWriterInput markAsFinished];
    
    [videoWriter finishWritingWithCompletionHandler:^{
        if (audioFile) {
            compositionFileSaved = [[NSString alloc] initWithString:[videoFile stringByReplacingOccurrencesOfString:@"video.mov" withString:@"videocomp.mov"]];
            
            [self addAudio:audioFile toVideo:videoFile resultingPath:compositionFileSaved];
        } else {
            NSLog(@"We haven't audio file, so creating video without audio");
            UISaveVideoAtPathToSavedPhotosAlbum(videoFile, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
        
        NSLog(@"Creating video file finished");
        
        
    }];
}


- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    NSLog(@"Saving to photo album finished with error: %@", error);
    [self onCompletedWithError:error];
    
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSError * error2;
    [fileManager removeItemAtPath:videoFileSaved error:&error2];
    [videoFileSaved release];
    if (audioFileSaved) {
        [fileManager removeItemAtPath:audioFileSaved error:&error2];
        [audioFileSaved release];
    }
    if (compositionFileSaved) {
        [fileManager removeItemAtPath:compositionFileSaved error:&error2];
        [compositionFileSaved release];
    }
}

- (void)addAudio:(NSString *)audioFilePath toVideo:(NSString *)videoFilePath resultingPath:(NSString *)outFilePath
{
    NSError * error = nil;
    AVMutableComposition * composition = [AVMutableComposition composition];
    
    
    AVURLAsset * videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoFilePath] options:nil];
    
    AVAssetTrack * videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    AVMutableCompositionTrack * compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                preferredTrackID: kCMPersistentTrackID_Invalid];
    
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoAsset.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:&error];
    if (error) {
        NSLog(@"Error inserting time range (video): %@", error.description);
        [self errorAddingAudioTo:videoFilePath];
        return;
    }
    
    AVURLAsset * urlAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:audioFilePath] options:nil];
    if (!urlAsset) {
        NSLog(@"Error creating urlAsset");
        [self errorAddingAudioTo:videoFilePath];
        return;
    }
    AVAssetTrack * audioAssetTrack = [[urlAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    if (!audioAssetTrack) {
        NSLog(@"Error creating audioAssetTrack");
        [self errorAddingAudioTo:videoFilePath];
        return;
    }
    AVMutableCompositionTrack * compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                preferredTrackID: kCMPersistentTrackID_Invalid];
    if (!compositionAudioTrack) {
        NSLog(@"Error creating compositionAudioTrack");
        [self errorAddingAudioTo:videoFilePath];
        return;
    }
    
    NSLog(@"Audio file duration: %f", CMTimeGetSeconds(urlAsset.duration) );
    
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, urlAsset.duration) ofTrack:audioAssetTrack atTime:kCMTimeZero error:&error];
    if (error) {
        NSLog(@"Error inserting time range (audio): %@", error.description);
        [self errorAddingAudioTo:videoFilePath];
        return;
    }
    
    AVAssetExportSession * assetExport = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetMediumQuality];
    if (!assetExport) {
        NSLog(@"Error creating assetExport");
        [self errorAddingAudioTo:videoFilePath];
        return;
    }
    
    assetExport.outputFileType =AVFileTypeQuickTimeMovie;
    assetExport.outputURL = [NSURL fileURLWithPath:outFilePath];
    
    [assetExport exportAsynchronouslyWithCompletionHandler:^(void ) {
         switch (assetExport.status) {
             case AVAssetExportSessionStatusCompleted:
                 NSLog(@"Export Complete");
                 UISaveVideoAtPathToSavedPhotosAlbum(outFilePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
                 break;
             case AVAssetExportSessionStatusFailed:
             case AVAssetExportSessionStatusCancelled:
             default:
                 NSLog(@"Bad export status: %d", (int)assetExport.status);
                 [self errorAddingAudioTo:videoFilePath];
                 break;
         }
     }];    
}

- (void) errorAddingAudioTo:(NSString *)videoFile {
    [compositionFileSaved release];
    compositionFileSaved = nil;
    
    NSLog(@"Error joining audio and video, so saving only video");
    UISaveVideoAtPathToSavedPhotosAlbum(videoFile, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
}


- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image andSize:(CGSize) size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width,
                                          size.height, kCVPixelFormatType_32ARGB, (CFDictionaryRef) options,
                                          &pxbuffer);
    if (status != kCVReturnSuccess || pxbuffer == NULL) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    if (pxdata == NULL) {
        return NULL;
    }
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
                                                 size.height, 8, 4*size.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    if (context == NULL) {
        CGColorSpaceRelease(rgbColorSpace);
        return NULL;
    }
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}


@end
