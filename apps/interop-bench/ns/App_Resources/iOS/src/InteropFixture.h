#import <Foundation/Foundation.h>

/// Native test fixture for the JS↔native interop microbenchmarks — the same
/// role as the TestFixtures class in the original NativeScript perf-metrics
/// posts. Both frameworks in the study get an equivalent fixture; what differs
/// is how JS reaches it (direct binding here vs an authored bridge module).
@interface InteropFixture : NSObject
+ (double)addA:(double)a b:(double)b c:(double)c;
+ (NSInteger)strLen:(NSString *)value;
+ (long long)sumBytes:(NSString *)value;
@end
