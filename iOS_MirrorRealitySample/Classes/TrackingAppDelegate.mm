//
//  based on ColorTrackingAppDelegate.m
//  from ColorTracking application
//  The source code for this application is available under a BSD license.
//
//  Created by Brad Larson on 10/7/2010.
//  Modified by Anton Malyshev on 6/21/2013.
//

#import "TrackingAppDelegate.h"
#import "TrackingViewController.h"
#include "LuxandFaceSDK.h"

@implementation TrackingAppDelegate

@synthesize window = _window;

- (void)dealloc {
    [trackingViewController release];
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{
    int res = FSDKE_OK; 
    res = MR_ActivateLibrary((char *)"FooVYW+Sj7F1PBVepbcDO2j7NH6jWE4GhTXuV21QVzEZf8XsmhSkuhf6/8rUy4BM22x/cGXUEQJksg0G7UaV3muEevZRxW8+PP8wJi1VSGwTeeZyPLadtejP81VvHpLIuHRvHkOy2SnBCjhXvL/HI04OkgUE8ik5zlGdhNAiwIC=");
    NSLog(@"activation result %d\n", res);
    if (res) exit(res);
    
    char licenseInfo[1024];
    FSDK_GetLicenseInfo(licenseInfo);
    NSLog(@"license: %s\n", licenseInfo);
    
    res = FSDK_Initialize((char *)"");
    NSLog(@"init result %d\n", res);
    if (res) exit(res);
    
    int threadcount = 0;
    res = FSDK_GetNumThreads(&threadcount);
    NSLog(@"thread count %d\n", threadcount);
    if (res) exit(res);
    
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	if (!_window) {
		[self release];
		return NO;
	}
	_window.backgroundColor = [UIColor blackColor];
	_window.autoresizesSubviews = YES;
	_window.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
    trackingViewController = [[TrackingViewController alloc] initWithScreen:[UIScreen mainScreen]];
    [self.window setRootViewController:trackingViewController];
    [_window makeKeyAndVisible];
	[_window layoutSubviews];
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */

    trackingViewController.closing = YES;
    
    int i = 1;
    while (trackingViewController.processingImage) {
        //wait while processing Image in FaceSDK, but not more than 2 seconds
        if (i++ > 20) break; 
        [NSThread sleepForTimeInterval:0.1];
    }
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

@end
