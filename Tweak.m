#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "fishhook.h"
#include <time.h>
#include <sys/time.h>

static const NSTimeInterval kOffset = -(600.0 * 24.0 * 60.0 * 60.0);

/* NSDate +date */
static NSDate *(*orig_NSDate_date)(id, SEL);

static NSDate *hook_NSDate_date(id self, SEL cmd)
{
    NSDate *realDate = orig_NSDate_date(self, cmd);
    return [realDate dateByAddingTimeInterval:kOffset];
}

/* NSDate -timeIntervalSinceNow */
static NSTimeInterval (*orig_timeIntervalSinceNow)(id, SEL);

static NSTimeInterval hook_timeIntervalSinceNow(id self, SEL cmd)
{
    return orig_timeIntervalSinceNow(self, cmd) + kOffset;
}

/* C time() */
static time_t (*orig_time)(time_t *);

static time_t hook_time(time_t *t)
{
    time_t result = orig_time(t);
    result += (time_t)kOffset;

    if (t)
        *t = result;

    return result;
}

/* C gettimeofday() */
static int (*orig_gettimeofday)(struct timeval *, void *);

static int hook_gettimeofday(struct timeval *tv, void *tz)
{
    int result = orig_gettimeofday(tv, tz);

    if (result == 0 && tv)
        tv->tv_sec += (time_t)kOffset;

    return result;
}

__attribute__((constructor))
static void init(void)
{
    /*
     * Hook NSDate +date.
     */
    Class NSDateClass = objc_getClass("NSDate");

    if (NSDateClass) {
        Method dateMethod =
            class_getClassMethod(NSDateClass, @selector(date));

        if (dateMethod) {
            orig_NSDate_date =
                (NSDate *(*)(id, SEL))
                method_getImplementation(dateMethod);

            method_setImplementation(
                dateMethod,
                (IMP)hook_NSDate_date
            );
        }

        /*
         * Hook NSDate -timeIntervalSinceNow.
         */
        Method intervalMethod =
            class_getInstanceMethod(
                NSDateClass,
                @selector(timeIntervalSinceNow)
            );

        if (intervalMethod) {
            orig_timeIntervalSinceNow =
                (NSTimeInterval (*)(id, SEL))
                method_getImplementation(intervalMethod);

            method_setImplementation(
                intervalMethod,
                (IMP)hook_timeIntervalSinceNow
            );
        }
    }

    /*
     * Hook C time functions using fishhook.
     */
    struct rebinding rebindings[] = {
        {
            "time",
            (void *)hook_time,
            (void **)&orig_time
        },
        {
            "gettimeofday",
            (void *)hook_gettimeofday,
            (void **)&orig_gettimeofday
        }
    };

    rebind_symbols(
        rebindings,
        sizeof(rebindings) / sizeof(rebindings[0])
    );
}
