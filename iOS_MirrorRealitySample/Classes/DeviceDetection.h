//
//  DeviceDetection.h
//  MirrorReality
//
//  Created by Anton on 28/06/16.
//
//

#import <Foundation/Foundation.h>

@interface DeviceDetection : NSObject


+ (NSString *) platform;

+ (BOOL) iPhone5SOrGreater;
+ (BOOL) iPhone6SOrGreater;
+ (BOOL) iPadMini2OrAirOrGreater;
+ (BOOL) iPadProOrGreater;


@end
