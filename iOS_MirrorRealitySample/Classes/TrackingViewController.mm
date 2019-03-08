//
//  partially based on ColorTrackingViewController.m
//  from ColorTracking application
//  The source code for this application is available under a BSD license.
//
//  Created by Brad Larson on 10/7/2010.
//  Modified by Anton Malyshev on 03/01/2016.
//

#include <string.h>
#import "TrackingViewController.h"
#import "DeviceDetection.h"

@implementation TrackingViewController

@synthesize glView = _glView;
@synthesize tracker = _tracker;
@synthesize templatePath = _templatePath;
@synthesize closing = _closing;
@synthesize processingImage = _processingImage;

static int glerr = GL_NO_ERROR;

UIButton * recordVideoButton;

int max_video_len = 20;

const int mask_count = 45;
NSString * masks[mask_count] = {
    @"/leopard.png",
    @"/corpse_bride.png",
    @"/mermaid.png",
    @"/piercing.png",
    @"/tattoo.png",
    @"/piercing2.png",
    @"/scheherazade.png",
    @"/crow.png",
    @"/popart.png",
    @"/snowqueen1.png",
    @"/snake.png",
    @"/hannibal.png",
    @"/carnival1.png",
    @"/young.png",
    @"/bat.png",
    @"/carnival3.png",
    @"/terminator.png",
    @"/wolf.png",
    @"/zombie.png",
    @"/old_man.png",
    @"/butterfly.png",
    @"/latino.png",
    @"/mime.png",
    @"/scaryface.png",
    @"/piercing1.png",
    @"/indian_piercing.png",
    @"/avatar.png",
    @"/cloud.png",
    @"/beard_man.png",
    @"/queen_card.png",
    @"/chewbacca.png",
    @"/cheshire_cat.png",
    @"/elf.png",
    @"/freddy_krueger.png",
    @"/frozen_elsa.png",
    @"/frozen_olaf.png",
    @"/gorgon.png",
    @"/matryoshka_doll.png",
    @"/pilot.png",
    @"/santa.png",
    @"/santa_white.png",
    @"/saw.png",
    @"/viking.png",
    @"/white_walker.png",
    @"/yoda.png",
};

int shifts[mask_count] = {
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_IN,  // young3
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_OUT, // zombie2
    MR_SHIFT_TYPE_OUT, // old_new
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
    MR_SHIFT_TYPE_NO,
};


int mask_number = 0;

long long face_count = 0;

volatile BOOL change_mask_on_touch = NO;
volatile BOOL show_fps = YES;

static volatile BOOL texturesGenerated = NO;

static volatile BOOL isRecordingVideo = NO;
static long long recordingVideoFrame = 0;
static BOOL askRecordAudioPermission = YES;


#pragma mark -
#pragma mark TrackingViewController initialization, initializing face tracker

- (int) detectFaceOnceEvery {
    if ([DeviceDetection iPhone6SOrGreater] || [DeviceDetection iPadProOrGreater]) {
        return 3;
    } else if ([DeviceDetection iPhone5SOrGreater] || [DeviceDetection iPadMini2OrAirOrGreater]) {
        return 5;
    } else {
        return 0;
    }
}

- (int) facialFeatureJitterSuppression {
    if ([DeviceDetection iPhone6SOrGreater] || [DeviceDetection iPadProOrGreater]) {
        return 7;
    } else if ([DeviceDetection iPhone5SOrGreater] || [DeviceDetection iPadMini2OrAirOrGreater]) {
        return 7;
    } else {
        return 3;
    }
}

- (id)initWithScreen:(UIScreen *)newScreenForDisplay
{
    long long memorySize = [NSProcessInfo processInfo].physicalMemory;
    if (memorySize < 900*1024*1024) {
        max_video_len = 12; // for 512Mb devices, like iPad mini, iPhone 4S
    }
    
    faceDataLock = [[NSLock alloc] init];
 
    if ((self = [super initWithNibName:nil bundle:nil])) {
        FSDK_CreateTracker(&_tracker);
        
        int facialFeatureJitterSuppressionValue = [self facialFeatureJitterSuppression];
        int detectFaceOnceEveryValue = [self detectFaceOnceEvery];
        
        char parameters[1024];
        sprintf(parameters, "DetectFaces=false;RecognizeFaces=false;DetectFacialFeatures=true;DetectEyes=false;ContinuousVideoFeed=true;ThresholdFeed=0.97;MemoryLimit=1000;HandleArbitraryRotations=false;DetermineFaceRotationAngle=false;InternalResizeWidth=70;FaceDetectionThreshold=3;FacialFeatureJitterSuppression=%d;DetectFaceOnceEvery=%d;",facialFeatureJitterSuppressionValue, detectFaceOnceEveryValue);
        
        int errpos = 0;
        FSDK_SetTrackerMultipleParameters(_tracker, parameters, &errpos);
        if (errpos) {
            NSLog(@"FSDK_SetTrackerMultipleParameters returned errpos = %d", errpos);
        }
        
        screenForDisplay = newScreenForDisplay;
		_processingImage = NO;
        rotating = NO;
        videoStarted = 0;
    }
    return self;
}

- (void)initGestureRecognizersFor:(UIView *)view
{
    UISwipeGestureRecognizer * leftSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeLeft:)];
    leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    UISwipeGestureRecognizer * rightSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeRight:)];
    rightSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [view addGestureRecognizer:leftSwipe];
    [view addGestureRecognizer:rightSwipe];
}

- (void)loadView
{
    videoRecordingLock = [[NSLock alloc] init];
    videoFrameTimes = [[NSMutableArray alloc] initWithCapacity:10];
    videoFrames = [[NSMutableArray alloc] initWithCapacity:10];
    videoCreator = [[VideoCreator alloc] init];
    audioCreator = [[AudioCreator alloc] init];
    
	CGRect mainScreenFrame = [[UIScreen mainScreen] applicationFrame];
	UIView * primaryView = [[UIView alloc] initWithFrame:mainScreenFrame];
	self.view = primaryView;
	[primaryView release];
    
    _glView = [[TrackingGLView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 256.0f, 256.0f)];
    
    [self initGestureRecognizersFor:_glView];
    
	[self.view addSubview:_glView];
	[_glView release];
    
    drawFps = [[CATextLayer alloc] init];
    [drawFps setFont:@"Helvetica-Bold"];
    [drawFps setFontSize:30];
    [drawFps setFrame:CGRectMake(10.0f, 10.0f, 200.0f, 40.0f)];
    [drawFps setString:@""];
    [drawFps setForegroundColor:[[UIColor greenColor] CGColor]];
    [drawFps setAnchorPoint:CGPointMake(0.0f, 0.0f)];
    [drawFps setAlignmentMode:kCAAlignmentLeft];
    
    drawTime = [[CATextLayer alloc] init];
    [drawTime setContentsScale:[[UIScreen mainScreen] scale]];
    [drawTime setFont:@"Helvetica-Bold"];
    [drawTime setFontSize:20];
    [drawTime setFrame:CGRectMake(10.0f, 40.0f, 200.0f, 40.0f)];
    [drawTime setString:@""];
    [drawTime setForegroundColor:[[UIColor greenColor] CGColor]];
    [drawTime setAnchorPoint:CGPointMake(0.5f, 0.0f)];
    [drawTime setAlignmentMode:kCAAlignmentCenter];
    
    NSMutableDictionary * newActions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"position", [NSNull null], @"bounds", nil];
    drawFps.actions = newActions;
    NSMutableDictionary * newTimeActions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"position", [NSNull null], @"bounds", nil];
    drawTime.actions = newTimeActions;
    
    
    [_glView.layer addSublayer:drawFps];
    [_glView.layer addSublayer:drawTime];
    
    UIButton * snapshotButton = [[UIButton alloc] initWithFrame:CGRectMake(80.0, 100.0, 160.0, 40.0)];
    [snapshotButton addTarget:self
               action:@selector(snapshotAction:)
     forControlEvents:UIControlEventTouchUpInside];
    [snapshotButton setTitle:@"Snapshot" forState:UIControlStateNormal];
    snapshotButton.backgroundColor = [UIColor grayColor];
    snapshotButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    snapshotButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [self.view addSubview:snapshotButton];
    
    recordVideoButton = [[UIButton alloc] initWithFrame:CGRectMake(80.0, 160.0, 160.0, 40.0)];
    [recordVideoButton addTarget:self
                       action:@selector(recordVideoAction:)
             forControlEvents:UIControlEventTouchUpInside];
    [recordVideoButton setTitle:@"Start recording" forState:UIControlStateNormal];
    recordVideoButton.backgroundColor = [UIColor grayColor];
    recordVideoButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    recordVideoButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [self.view addSubview:recordVideoButton];
    
	camera = [[TrackingCamera alloc] init];
	camera.delegate = self;
	[self onGLInit];
}

- (void)didReceiveMemoryWarning 
{
//    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
    [drawFps release];
    [drawTime release];
    [camera release];
    [videoFrameTimes release];
    [videoFrames release];
    [videoCreator release];
    [audioCreator release];
    [super dealloc];
}



#pragma mark -
#pragma mark OpenGL ES 1.1 rendering

- (void) onGLInit {
    texturesGenerated = NO;
    
    glEnable(GL_TEXTURE_2D);
    if ((glerr = glGetError())) NSLog(@"Error in glEnable TEXTURE_2D, %d", glerr);
    
    GLuint textures[3];
    glGenTextures(3, textures);
    if ((glerr = glGetError())) NSLog(@"Error in glGenTextures, %d", glerr);
    
    videoFrameTexture = textures[0];
    maskTexture1 = textures[1];
    maskTexture2 = textures[2];
    
    [self loadNextMask];
    
    texturesGenerated = YES;
}

- (NSString *) getFilePathFor:(NSString *)name {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:name];
}

- (NSString *) getAssetsPath {
    NSBundle *b = [NSBundle mainBundle];
    NSString *dir = [b resourcePath];
    NSArray *parts = [NSArray arrayWithObjects:
                      dir, (void *)nil];
    return [NSString pathWithComponents:parts];
}

- (void)loadMask
{
    NSString * assetsPath = [self getAssetsPath];
    const char * maskname = [[assetsPath stringByAppendingString:masks[mask_number]] fileSystemRepresentation];
    
    if (isMaskTexture1Created) {
        glDeleteTextures(1, &maskTexture1);
    }
    if (isMaskTexture2Created) {
        glDeleteTextures(1, &maskTexture2);
    }
    
    isMaskTexture1Created = 0;
    isMaskTexture2Created = 0;
    int result = FSDKE_OK;
    char grdname[1024];
    strcpy(grdname, maskname);
    strcpy(grdname + strlen(grdname) - 4, ".grd");
    char topname[1024];
    strcpy(topname, maskname);
    strcpy(topname + strlen(topname) - 4, "_normal.png");
    
    HImage img1, img2;
    result = MR_LoadMaskCoordsFromFile(grdname, maskCoords);
    if (result == FSDKE_OK) {
        result = FSDK_LoadImageFromFileWithAlpha(&img1, maskname);
        if (result != FSDKE_OK) {
            FSDK_CreateEmptyImage(&img1);
        }
        int resultTop = FSDK_LoadImageFromFileWithAlpha(&img2, topname);
        if (resultTop != FSDKE_OK) {
            FSDK_CreateEmptyImage(&img2);
        }
        MR_LoadMask(img1, img2, maskTexture1, maskTexture2, &isMaskTexture1Created, &isMaskTexture2Created);
        FSDK_FreeImage(img1);
        FSDK_FreeImage(img2);
    }
}

- (void)loadPrevMask
{
    if (change_mask_on_touch) {
        --mask_number;
        if (mask_number < 0) mask_number = mask_count-1;
        change_mask_on_touch = NO;
    }
    [self loadMask];
}

- (void)loadNextMask
{
    if (change_mask_on_touch) {
        mask_number = (mask_number+1) % mask_count;
        change_mask_on_touch = NO;
    }
    [self loadMask];
}


- (void)drawFrameWithWidth:(int)width Height:(int)height Buffer:(unsigned char *)buffer
{
    if (!texturesGenerated) {
        return;
    }
    
    glBindTexture(GL_TEXTURE_2D, videoFrameTexture);
    if ((glerr = glGetError())) NSLog(@"Error in glBindTexture, %d", glerr);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    if ((glerr = glGetError())) NSLog(@"Error in glTexParameteri GL_TEXTURE_MIN_FILTER, %d", glerr);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    if ((glerr = glGetError())) NSLog(@"Error in glTexParameteri GL_TEXTURE_MAG_FILTER, %d", glerr);
    
    // This is necessary for non-power-of-two textures, which are not supported in OpenGL ES 1.1?
    // But actually working!
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    if ((glerr = glGetError())) NSLog(@"Error in glTexParameteri GL_TEXTURE_WRAP_S, %d", glerr);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    if ((glerr = glGetError())) NSLog(@"Error in glTexParameteri GL_TEXTURE_WRAP_T, %d", glerr);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, buffer);
    if ((glerr = glGetError())) NSLog(@"Error in glTexImage2D, %d", glerr);

    glActiveTexture(GL_TEXTURE0);
    if ((glerr = glGetError())) NSLog(@"Error in glActiveTexture, %d", glerr);
    
    [self drawFrame];
    
    glDeleteTextures(1, &videoFrameTexture);
    if ((glerr = glGetError())) NSLog(@"Error in glDeleteTextures, %d", glerr);
}

- (void)drawFrame
{
    // Reinitialize GLView and Toolbar when orientation changed
    static UIInterfaceOrientation old_orientation = (UIInterfaceOrientation)0;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (orientation != old_orientation) {
        old_orientation = orientation;
        [self relocateSubviewsForOrientation:orientation];
        return;
    }
    
    // Start preparing scene
    [_glView setDisplayFramebuffer];
    
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    if ((glerr = glGetError())) NSLog(@"Error in glClear, %d", glerr);

    [faceDataLock lock];
    
    int rotationAngle90Multiplier = 0;
    if (orientation == 0 || orientation == UIInterfaceOrientationPortrait) {
        rotationAngle90Multiplier = -1;
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        rotationAngle90Multiplier = 1;
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
        rotationAngle90Multiplier = 0;
    } else if(orientation == UIInterfaceOrientationLandscapeLeft) {
        rotationAngle90Multiplier = 2;
    }
    float w = self.view.bounds.size.width;
    float h = self.view.bounds.size.height;
    
    MR_DrawGLScene(videoFrameTexture, (int)face_count, features, rotationAngle90Multiplier, shifts[mask_number], maskTexture1, maskTexture2, maskCoords, isMaskTexture1Created, isMaskTexture2Created, w, h);
    
    [faceDataLock unlock];
    
    if (isRecordingVideo) {
        int w = 0;
        int h = 0;
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &w);
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &h);
        NSInteger myDataLength = w * h * 4;
        GLubyte * buffer = (GLubyte *) malloc(myDataLength);
        glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
        
        GLubyte * buffer2 = (GLubyte *) malloc(myDataLength);
        GLubyte * pBuffer2 = buffer2 + (h - 1) * w * 4;
        GLubyte * pBuffer = buffer;
        for(int y = 0; y < h; ++y) {
            memcpy(pBuffer2, pBuffer, w*4);
            pBuffer2 -= (w*4);
            pBuffer += (w*4);
        }
        
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer2, myDataLength, NULL);
        int bitsPerComponent = 8;
        int bitsPerPixel = 32;
        int bytesPerRow = 4 * w;
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
        CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
        
        CGImageRef imageRef = CGImageCreate(w, h, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
        
        UIImage * snapshot_image = [UIImage imageWithCGImage:imageRef];
        [self saveVideoFrame:snapshot_image];
        
        CGImageRelease(imageRef);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpaceRef);
        free(buffer);
        free(buffer2);
    }
    
    // Display scene
    [_glView presentFramebuffer];
    
    // Counting fps
    if (!timeStart) timeStart = [[NSDate date] retain];
    static long long framesCount = 0;
    ++framesCount;
    NSDate *timeCurrent = [NSDate date];
    NSTimeInterval executionTime = [timeCurrent timeIntervalSinceDate:timeStart];
    if (executionTime > 3) {
        double fps = (executionTime<=0)? 0: (framesCount / (double)executionTime);
        if (show_fps) {
            [drawFps setString:[NSString stringWithFormat:@"FPS %.2f", fps]];
        } else {
            [drawFps setString:@""];
        }
        executionTime = 0;
        timeStart = nil;
        framesCount = 0;
    } else if (executionTime > 0.1) {
        if (askRecordAudioPermission) {
            askRecordAudioPermission = NO;
            
            // request record audio permission (to create good first video)
            if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
                NSLog(@"requesting record audio permission");
                [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL){
                    NSLog(@"record audio permission granted");
                }];
            }
        }
    }
    
    videoStarted = 1;
}


#pragma mark -
#pragma mark TrackingCameraDelegate methods: get image from camera and process it

- (CGImage *)fromCVImageBufferRef:(CVImageBufferRef)cameraFrame
{
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:cameraFrame];
    CIContext *temporaryContext = [CIContext contextWithEAGLContext:[_glView context]];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(cameraFrame),
                                                 CVPixelBufferGetHeight(cameraFrame))];
    return videoImage;
}

- (void)processNewCameraFrame:(CVImageBufferRef)cameraFrame
{
    if (rotating) {
        return;
    }

    if (_processingImage == NO) {
        if (_closing) return;
        _processingImage = YES;
        
        CVPixelBufferLockBaseAddress(cameraFrame, 0);
        int bufferHeight = (int)CVPixelBufferGetHeight(cameraFrame);
        int bufferWidth = (int)CVPixelBufferGetWidth(cameraFrame);
    
        
        // Copy camera frame to buffer
        int scanline = (int)CVPixelBufferGetBytesPerRow(cameraFrame);
        unsigned char * buffer = (unsigned char *)malloc(scanline * bufferHeight);
        if (buffer) { 
            memcpy(buffer, CVPixelBufferGetBaseAddress(cameraFrame), scanline * bufferHeight);
        } else {
            _processingImage = NO;
            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
            return;
        }

        // Execute face detection and recognition asynchronously
        DetectFaceParams args;
        args.width = bufferWidth;
        args.height = bufferHeight;
        args.scanline = scanline;
        args.buffer = buffer;
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (orientation == 0 || orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
            args.ratioY = (float)self.view.bounds.size.height/(float)bufferWidth;
            args.ratioX = (float)self.view.bounds.size.width/(float)bufferHeight;
        } else {
            args.ratioX = (float)self.view.bounds.size.width/(float)bufferWidth;
            args.ratioY = (float)self.view.bounds.size.height/(float)bufferHeight;
        }
        NSData * argsobj = [NSData dataWithBytes:&args length:sizeof(DetectFaceParams)];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self processImageAsyncWith:argsobj];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self drawFrameWithWidth:args.width Height:args.height Buffer:args.buffer];
                free(buffer);
            });
        });
        
        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    }
}

#pragma mark -
#pragma mark Recording video

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}

- (void)saveVideoFrame:(UIImage *)frame
{
    if (videoFrames.count <= 0) {
        [videoFrames addObject:UIImageJPEGRepresentation(frame, 0.75f)];
        [videoFrameTimes addObject:[NSNumber numberWithDouble:0.0]];
        ++recordingVideoFrame;
    }
    NSDate * timeCurrent = [NSDate date];
    double frameTime = [timeCurrent timeIntervalSinceDate:videoRecordingStartTime];
    [videoFrames addObject:UIImageJPEGRepresentation(frame, 0.75f)];
    [videoFrameTimes addObject:[NSNumber numberWithDouble:frameTime]];
    ++recordingVideoFrame;
    
    if (frameTime < max_video_len) {
        [drawTime setString:[NSString stringWithFormat:@"00:%02d", max_video_len - (int)frameTime]];
    } else {
        [drawTime setString:@""];
        NSLog(@"trying to stop video recording by timer");
        [self recordVideoAction:nil];
    }
}

- (void)startRecordingVideo
{
    // try to remove old files
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSError * error2;
    [fileManager removeItemAtPath:[self videoFilePath] error:&error2];
    [fileManager removeItemAtPath:[self audioFilePath] error:&error2];
    [fileManager removeItemAtPath:[self videoCompositionPath] error:&error2];
    
    NSLog(@"starting to record video");
    
    [audioCreator startRecording:[self audioFilePath]];
    
    recordingVideoFrame = 0;
    videoRecordingStartTime = [[NSDate date] retain];
    [videoFrameTimes removeAllObjects];
    [videoFrames removeAllObjects];
    
    isRecordingVideo = YES;
    
    [recordVideoButton setTitle:@"Stop recording" forState:UIControlStateNormal];
}

- (NSString *)audioFilePath
{
    return [[self applicationDocumentsDirectory].path
            stringByAppendingPathComponent:@"audio.caf"];
}

- (NSString *)videoFilePath
{
    return [[self applicationDocumentsDirectory].path
            stringByAppendingPathComponent:@"video.mov"];
}

// the same approach for file name used in VideoCreator.m
- (NSString *)videoCompositionPath
{
    return [[self videoFilePath] stringByReplacingOccurrencesOfString:@"video.mov" withString:@"videocomp.mov"];
}

- (void)stopRecordingVideo
{
    [recordVideoButton setEnabled:NO];
    
    isRecordingVideo = NO;
    NSLog(@"stopping video recording");
    
    [drawTime setString:@""];
    
    NSDate * timeCurrent = [NSDate date];
    double videoLength = (double)[timeCurrent timeIntervalSinceDate:videoRecordingStartTime];
    NSLog(@"video length: %f", videoLength);
    
    [audioCreator stopRecordingProvidingCallback:^(NSError * error) {
        NSString * audioPath = nil;
        if (!error) {
            NSLog(@"audio recording stopped");
            audioPath = [self audioFilePath];
        }
        
        NSString * videoPath = [self videoFilePath];
        
        [videoCreator createVideo:videoPath withFrames:videoFrames andTimes:videoFrameTimes addingAudio:audioPath providingCallback:^(NSError * error) {
            if (error == nil) {
                [self toastWithMessage:@"Saved to gallery" andDuration:1];
            } else {
                [self toastWithMessage:@"Error saving to gallery. Check permissions." andDuration:2];
            }
            [self showRecordVideoButton];
            [videoRecordingLock unlock];
        }];
    }];
}

- (void) showRecordVideoButton
{
    [recordVideoButton setTitle:@"Start recording" forState:UIControlStateNormal];
    [recordVideoButton setEnabled:YES];
}



#pragma mark -
#pragma mark Buttons

- (void)toastWithMessage:(const NSString *)message andDuration:(int)durationInSeconds
{
    UIAlertView * toast = [[UIAlertView alloc] initWithTitle:nil
                                                     message:(NSString *)message
                                                    delegate:nil
                                           cancelButtonTitle:nil
                                           otherButtonTitles:nil, nil];
    [toast show];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, durationInSeconds * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [toast dismissWithClickedButtonIndex:0 animated:YES];
    });
}

- (void)snapshot:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error == nil) {
        [self toastWithMessage:@"Saved to gallery" andDuration:1];
    } else {
        [self toastWithMessage:@"Error saving to gallery. Check permissions." andDuration:2];
    }
}

- (void)snapshotAction:(id)sender
{
    UIGraphicsBeginImageContext(_glView.frame.size);
    [_glView drawViewHierarchyInRect:_glView.frame afterScreenUpdates:YES];
    UIImage * snapshot_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImageWriteToSavedPhotosAlbum(snapshot_image, self, @selector(snapshot:didFinishSavingWithError:contextInfo:), nil);
}

- (void)recordVideoAction:(id)sender
{
    @synchronized(self) {
        [videoRecordingLock lock];
        if (isRecordingVideo) {
            [self stopRecordingVideo];
        } else if (sender != nil) { // can start only by button press
            [self startRecordingVideo];
            [videoRecordingLock unlock];
        }
    }
}


#pragma mark -
#pragma mark Device rotation support

-(BOOL) shouldAutorotate {
    if (isRecordingVideo) {
        return NO;
    } else {
        return YES;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    rotating = YES;
    [_glView setHidden:YES];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    rotating = NO;
}

- (CGSize)screenSizeOrientationIndependent {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    return CGSizeMake(MIN(screenSize.width, screenSize.height), MAX(screenSize.width, screenSize.height));
}

- (void)relocateSubviewsForOrientation:(UIInterfaceOrientation)orientation
{
    [_glView destroyFramebuffer];
    [_glView removeFromSuperview];
    
    CGSize applicationFrame = [self screenSizeOrientationIndependent];
    
    const int video_width = (int)camera.width;
    const int video_height = (int)camera.height;
    
    if (orientation == 0 || orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        _glView = [[TrackingGLView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, applicationFrame.width, applicationFrame.width * (video_width*1.0f/video_height))];
    } else {
        _glView = [[TrackingGLView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, applicationFrame.width * (video_width*1.0f/video_height), applicationFrame.width)];
    }
    [self initGestureRecognizersFor:_glView];
    [self.view addSubview:_glView];
    [_glView release];
    [_glView.layer addSublayer:drawFps];
    [_glView.layer addSublayer:drawTime];
    [self.view sendSubviewToBack:_glView];
    [self onGLInit];
}



#pragma mark -
#pragma mark Face detection and recognition

- (void)processImageAsyncWith:(NSData *)args
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    if (_closing) {
        [pool release];
        return;
    }
    
    // Reading buffer parameters
    DetectFaceParams a;
    [args getBytes:&a length:sizeof(DetectFaceParams)];
    unsigned char * buffer = a.buffer;
    int width = a.width;
    int height = a.height;
    int scanline = a.scanline;
    float ratioX = a.ratioX;
    float ratioY = a.ratioY;
    
    
    // Converting BGRA to RGBA
    unsigned char * bufferRGBA = (unsigned char *)malloc(height * scanline);
    unsigned char * p1line = bufferRGBA;
    unsigned char * p2line = buffer;
    for (int y=0; y<height; ++y) {
        unsigned char * p1 = p1line;
        unsigned char * p2 = p2line;
        p1line += scanline;
        p2line += scanline;
        for (int x=0; x<width; ++x) {
            *(p1+2) = *p2++;
            *(p1+1) = *p2++;
            *(p1) = *p2++;
            *(p1+3) = *p2++;
            p1 += 4;
        }
    
    }
    
    HImage image;
    int res = FSDK_LoadImageFromBuffer(&image, bufferRGBA, width, height, scanline, FSDK_IMAGE_COLOR_32BIT);
    free(bufferRGBA);
    if (res != FSDKE_OK) {
#if defined(DEBUG)
        NSLog(@"FSDK_LoadImageFromBuffer failed with %d", res);
#endif
        [pool release];
        _processingImage = NO;
        return;
    }
    
    // Rotating image basing on orientation
    HImage derotated_image;
    res = FSDK_CreateEmptyImage(&derotated_image);
    if (res != FSDKE_OK) {
#if defined(DEBUG)
        NSLog(@"FSDK_CreateEmptyImage failed with %d", res);
#endif
        FSDK_FreeImage(image);
        [pool release];
        _processingImage = NO;
        return;
    }
    UIInterfaceOrientation df_orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (df_orientation == 0 || df_orientation == UIInterfaceOrientationPortrait) {
        res = FSDK_RotateImage90(image, 1, derotated_image);
    } else if (df_orientation == UIInterfaceOrientationPortraitUpsideDown) {
        res = FSDK_RotateImage90(image, -1, derotated_image);
    } else if (df_orientation == UIInterfaceOrientationLandscapeLeft) {
        res = FSDK_RotateImage90(image, 0, derotated_image); //will simply copy image
    } else if (df_orientation == UIInterfaceOrientationLandscapeRight) {
        res = FSDK_RotateImage90(image, 2, derotated_image);
    }
    if (res != FSDKE_OK) {
#if defined(DEBUG)
        NSLog(@"FSDK_RotateImage90 failed with %d", res);
#endif
        FSDK_FreeImage(image);
        FSDK_FreeImage(derotated_image);
        [pool release];
        _processingImage = NO;
        return;
    }
    
    res = FSDK_MirrorImage(derotated_image, true);
    if (res != FSDKE_OK) {
#if defined(DEBUG)
        NSLog(@"FSDK_MirrorImage failed with %d", res);
#endif
        FSDK_FreeImage(image);
        FSDK_FreeImage(derotated_image);
        [pool release];
        _processingImage = NO;
        return;
    }
    
    FSDK_FeedFrame(_tracker, 0, derotated_image, &face_count, IDs, sizeof(IDs));
    
    [faceDataLock lock];
    
    memset(features, 0, sizeof(FSDK_Features)*MR_MAX_FACES);
    
    for (size_t i = 0; i < (size_t)face_count; ++i) {
        FSDK_GetTrackerFacialFeatures(_tracker, 0, IDs[i], &(features[i]));
        for (int j=0; j<FSDK_FACIAL_FEATURE_COUNT; ++j) {
            (features[i])[j].x *= ratioX;
            (features[i])[j].y *= ratioY;
        }
    }
    
    [faceDataLock unlock];
    
    FSDK_FreeImage(image);
    FSDK_FreeImage(derotated_image);
    
    [pool release];
    _processingImage = NO;
}

#pragma mark -
#pragma mark Touch handling

- (void)swipeLeft:(UISwipeGestureRecognizer *)recognizer
{
    NSLog(@"swipe left");
    [faceDataLock lock];
    change_mask_on_touch = YES;
    [self loadNextMask];
    [faceDataLock unlock];
}

- (void)swipeRight:(UISwipeGestureRecognizer *)recognizer
{
    NSLog(@"swipe right");
    [faceDataLock lock];
    change_mask_on_touch = YES;
    [self loadPrevMask];
    [faceDataLock unlock];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}


@end
