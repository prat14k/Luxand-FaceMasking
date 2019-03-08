//
//  partially based on ColorTrackingViewController.h
//  from ColorTracking application
//  The source code for this application is available under a BSD license.
//
//  Created by Brad Larson on 10/7/2010.
//  Modified by Anton Malyshev on 03/01/2016.
//

#import <UIKit/UIKit.h>
#import "TrackingCamera.h"
#import "TrackingGLView.h"
#import "VideoCreator.h"
#import "AudioCreator.h"
#include "LuxandFaceSDK.h"
#include "MirrorRealitySDK.h"

#define MAX_NAME_LEN 1024

typedef struct {
    CGImage * image;
    unsigned char * buffer;
    int width, height, scanline;
    float ratioX, ratioY;
} DetectFaceParams;

@interface TrackingViewController : UIViewController <TrackingCameraDelegate>
{
	TrackingCamera * camera;
	UIScreen * screenForDisplay;
    
    GLuint videoFrameTexture;
	GLubyte * rawPositionPixels;

    CATextLayer * drawFps;
    CATextLayer * drawTime;
    NSDate * timeStart;
    
    NSLock * faceDataLock;
    FSDK_Features features[MR_MAX_FACES];
    long long IDs[MR_MAX_FACES];
    
    volatile int rotating;
    char videoStarted;
    
    GLuint maskTexture1;
    GLuint maskTexture2;
    int isMaskTexture1Created;
    int isMaskTexture2Created;
    MR_MaskFeatures maskCoords;
    
    AudioCreator * audioCreator;
    VideoCreator * videoCreator;
    NSDate * videoRecordingStartTime;
    NSMutableArray * videoFrameTimes;
    NSMutableArray * videoFrames;
    
    NSLock * videoRecordingLock;
}

@property(readonly) TrackingGLView * glView;
@property(readonly) HTracker tracker;
@property(readwrite) char * templatePath;
@property(readwrite) volatile int closing;
@property(readonly) volatile int processingImage;

// Initialization and teardown
- (id)initWithScreen:(UIScreen *)newScreenForDisplay;

// Device rotating support
- (void)relocateSubviewsForOrientation:(UIInterfaceOrientation)orientation;

// Image processing in FaceSDK
- (void)processImageAsyncWith:(NSData *)args;

@end

