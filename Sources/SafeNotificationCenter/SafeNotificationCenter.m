#import "SafeNotificationCenter.h"

UNUserNotificationCenter* _Nullable SafeGetNotificationCenter(void) {
    @try {
        return [UNUserNotificationCenter currentNotificationCenter];
    } @catch (NSException *exception) {
        NSLog(@"Failed to get UNUserNotificationCenter: %@", exception);
        return nil;
    }
}
