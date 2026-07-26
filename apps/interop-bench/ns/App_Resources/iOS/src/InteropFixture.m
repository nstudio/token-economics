#import "InteropFixture.h"

@implementation InteropFixture

+ (double)addA:(double)a b:(double)b c:(double)c {
  return a + b + c;
}

+ (NSInteger)strLen:(NSString *)value {
  return (NSInteger)value.length;
}

+ (long long)sumBytes:(NSString *)value {
  const char *bytes = value.UTF8String;
  long long sum = 0;
  for (const char *p = bytes; *p != '\0'; p++) {
    sum += (unsigned char)*p;
  }
  return sum;
}

@end
