//
//  based on ColorTrackingCamera.m
//  from ColorTracking application
//  The source code for this application is available under a BSD license.
//
//  Created by Brad Larson on 10/7/2010.
//  Modified by Anton Malyshev on 6/21/2013.
//

#import "TrackingCamera.h"

@implementation TrackingCamera

#pragma mark -
#pragma mark Initialization and teardown

- (id)init; 
{
	if (!(self = [super init]))
		return nil;
	
	// Grab the front-facing camera
	AVCaptureDevice * camera = nil;
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices) {
		if ([device position] == AVCaptureDevicePositionFront) {
			camera = device;
		}
	}
	
	// Create the capture session
	captureSession = [[AVCaptureSession alloc] init];
	
	// Add the video input	
	NSError *error = nil;
	videoInput = [[[AVCaptureDeviceInput alloc] initWithDevice:camera error:&error] autorelease];
	if ([captureSession canAddInput:videoInput]) {
		[captureSession addInput:videoInput];
	}
	[self videoPreviewLayer];
	// Add the video frame output	
	videoOutput = [[AVCaptureVideoDataOutput alloc] init];
	[videoOutput setAlwaysDiscardsLateVideoFrames:YES];
	// Use RGB frames instead of YUV to ease color processing
    [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

	if ([captureSession canAddOutput:videoOutput]) {
		[captureSession addOutput:videoOutput];
	} else {
#if defined(DEBUG)
		NSLog(@"Couldn't add video output");
#endif
	}

	// Start capturing
    NSString *deviceType = [UIDevice currentDevice].model;
    if ([deviceType isEqualToString:@"iPhone"]
        && [camera supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
        
        [captureSession setSessionPreset:AVCaptureSessionPresetiFrame960x540];
        _width = 960;
        _height = 540;
    } else {
        _width = 640;
        _height = 480;
        [captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    }
	
    if (![captureSession isRunning]) {
		[captureSession startRunning];
	};
	
	return self;
}

- (void)dealloc 
{
	[captureSession stopRunning];
	[captureSession release];
	[videoPreviewLayer release];
	[videoOutput release];
	[videoInput release];
	[super dealloc];
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	[self.delegate processNewCameraFrame:pixelBuffer];
}

#pragma mark -
#pragma mark Accessors

@synthesize delegate;
@synthesize videoPreviewLayer;

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer;
{
	if (videoPreviewLayer == nil) {
		videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
	}
	return videoPreviewLayer;
}

@end
