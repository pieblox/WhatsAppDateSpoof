#import <Foundation/Foundation.h>
#import <substrate.h>
#include <time.h>
#include <sys/time.h>

static const NSTimeInterval kOffset = -(600.0 * 24.0 * 60.0 * 60.0);

static NSDate *(*orig_NSDate_date)(id, SEL);
static NSDate *hook_NSDate_date(id self, SEL sel) {
    NSDate *date = orig_NSDate_date(self, sel);
    return [date dateByAddingTimeInterval:kOffset];
}

static NSTimeInterval (*orig_NSDate_timeIntervalSinceNow)(id, SEL);
static NSTimeInterval hook_NSDate_timeIntervalSinceNow(id self, SEL sel) {
    return orig_NSDate_timeIntervalSinceNow(self, sel) + kOffset;
}

static time_t (*orig_time)(time_t *);
static time_t hook_time(time_t *t) {
    time_t result = orig_time(t);
    result += (time_t)kOffset;
    if (t) *t = result;
    return result;
}

static int (*orig_gettimeofday)(struct timeval *, void *);
static int hook_gettimeofday(struct timeval *tv, void *tz) {
    int result = orig_gettimeofday(tv, tz);
    if (result == 0 && tv)
        tv->tv_sec += (time_t)kOffset;
    return result;
}

__attribute__((constructor))
static void init(void) {
    Class NSDateClass = objc_getClass("NSDate");

    MSHookMessageEx(
        object_getClass(NSDateClass),
        @selector(date),
        (IMP)hook_NSDate_date,
        (IMP *)&orig_NSDate_date
    );

    MSHookMessageEx(
        NSDateClass,
        @selector(timeIntervalSinceNow),
        (IMP)hook_NSDate_timeIntervalSinceNow,
        (IMP *)&orig_NSDate_timeIntervalSinceNow
    );

    MSHookFunction(
        (void *)time,
        (void *)hook_time,
        (void **)&orig_time
    );

    MSHookFunction(
        (void *)gettimeofday,
        (void *)hook_gettimeofday,
        (void **)&orig_gettimeofday
    );
}
