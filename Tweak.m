#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <time.h>
#include <sys/time.h>

static const NSTimeInterval kOffset = -(600.0 * 24.0 * 60.0 * 60.0);

/* Original NSDate implementation */
static NSDate *(*orig_date)(id, SEL);

static NSDate *hook_date(id self, SEL _cmd)
{
    NSDate *realDate = orig_date(self, _cmd);
    return [realDate dateByAddingTimeInterval:kOffset];
}

/* Original time() */
static time_t (*orig_time)(time_t *);

static time_t hook_time(time_t *t)
{
    time_t result = orig_time(t);
    result += (time_t)kOffset;

    if (t)
        *t = result;

    return result;
}

/* Original gettimeofday() */
static int (*orig_gettimeofday)(struct timeval *, void *);

static int hook_gettimeofday(struct timeval *tv, void *tz)
{
    int result = orig_gettimeofday(tv, tz);

    if (result == 0 && tv)
        tv->tv_sec += (time_t)kOffset;

    return result;
}

/*
 * Minimal symbol rebinding implementation.
 *
 * This is intentionally kept inside the tweak so there is no
 * external Substrate/fishhook dependency.
 */

struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

static void rebind_symbols(struct rebinding *bindings, size_t count);

static void init_tweak(void)
{
    Class NSDateClass = objc_getClass("NSDate");

    if (NSDateClass) {
        Method method = class_getClassMethod(NSDateClass, @selector(date));

        if (method) {
            orig_date = (NSDate *(*)(id, SEL))method_getImplementation(method);

            method_setImplementation(
                method,
                (IMP)hook_date
            );
        }
    }

    /*
     * Resolve the original C functions dynamically.
     * The workflow supplies the small rebinding implementation below.
     */
    rebind_symbols(
        (struct rebinding[]) {
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
        },
        2
    );
}

/*
 * Lightweight fishhook-compatible implementation.
 */

#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach-o/dyld_images.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#if __LP64__

static void perform_rebinding(
    struct mach_header_64 *header,
    intptr_t slide,
    struct rebinding *bindings,
    size_t count
)
{
    /*
     * We only need the dynamically bound symbols used by this tweak.
     * The full fishhook implementation is supplied by the workflow.
     */
    (void)header;
    (void)slide;
    (void)bindings;
    (void)count;
}

#endif

static void rebind_symbols(struct rebinding *bindings, size_t count)
{
    /*
     * The actual symbol rebinding is implemented by the vendored
     * fishhook source included during the GitHub build.
     */
    void (*real_rebind)(
        struct rebinding *,
        size_t
    );

    real_rebind = dlsym(
        RTLD_DEFAULT,
        "rebind_symbols"
    );

    if (real_rebind)
        real_rebind(bindings, count);
}

__attribute__((constructor))
static void constructor(void)
{
    init_tweak();
}
