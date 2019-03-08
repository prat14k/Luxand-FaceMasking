//
//  DeviceDetection.m
//  MirrorReality
//
//  Created by Anton on 28/06/16.
//
//

#import "DeviceDetection.h"

#include <sys/types.h>
#include <sys/sysctl.h>

@implementation DeviceDetection


+ (NSString *) platform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char * machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString * platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

+ (int) numberInString:(NSString *)string between:(NSString *)key1 and:(NSString *)key2 {
    NSRange r1 = [string rangeOfString:key1];
    NSRange r2 = [string rangeOfString:key2];
    NSRange rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
    return [[string substringWithRange:rSub] intValue];
}

+ (BOOL) iPhone5SOrGreater {
    // iPhone6,* and greater
    NSString * platform = [self platform];
    if ([platform containsString:@"iPhone"] && [DeviceDetection numberInString:platform between:@"iPhone" and:@","] >= 6) {
        return YES;
    }
    return NO;
}

+ (BOOL) iPhone6SOrGreater { // 6S, 6S+, SE
    // iPhone8,* and greater
    NSString * platform = [self platform];
    if ([platform containsString:@"iPhone"] && [DeviceDetection numberInString:platform between:@"iPhone" and:@","] >= 8) {
        return YES;
    }
    return NO;
}

+ (BOOL) iPadMini2OrAirOrGreater {
    // iPad4,* and greater
    NSString * platform = [self platform];
    if ([platform containsString:@"iPad"] && [DeviceDetection numberInString:platform between:@"iPad" and:@","] >= 4) {
        return YES;
    }
    return NO;
}

+ (BOOL) iPadProOrGreater {
    // iPad6,* and greater
    NSString * platform = [self platform];
    if ([platform containsString:@"iPad"] && [DeviceDetection numberInString:platform between:@"iPad" and:@","] >= 6) {
        return YES;
    }
    return NO;
}






@end
