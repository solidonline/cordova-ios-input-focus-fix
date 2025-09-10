#if __has_include(<Cordova/CDVPlugin.h>)
#import <Cordova/CDVPlugin.h>
#else
#import "CDVPlugin.h"   // fallback для старых проектов/сборок
#endif

#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static void PatchMethod(Class cls, SEL sel, IMP (^makeImp)(IMP original)) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    IMP rep  = makeImp(orig);
    method_setImplementation(m, rep);
}

@interface WKInputFocusFix : CDVPlugin
@end

@implementation WKInputFocusFix

- (void)pluginInitialize {
    id pref = self.commandDelegate.settings[@"keyboarddisplayrequiresuseraction"];
    BOOL requiresUserAction = YES;
    if ([pref respondsToSelector:@selector(boolValue)]) requiresUserAction = [pref boolValue];
    else if ([pref isKindOfClass:[NSString class]]) requiresUserAction = [((NSString*)pref) boolValue];

    if (!requiresUserAction) {
        NSLog(@"[wk-inputfocusfix] enabling patch (KeyboardDisplayRequiresUserAction=false)");
        [self.class enablePatch];
    } else {
        NSLog(@"[wk-inputfocusfix] pref=true; patch disabled");
    }
}

+ (void)enablePatch {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class WKContentView = NSClassFromString(@"WKContentView");
        if (!WKContentView) {
            NSLog(@"[wk-inputfocusfix] WKContentView not found — nothing to patch");
            return;
        }

        BOOL hooked = NO;

        SEL sel1 = NSSelectorFromString(@"_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:");
        Method m1 = class_getInstanceMethod(WKContentView, sel1);
        if (m1) {
            IMP orig = method_getImplementation(m1);
            IMP rep  = imp_implementationWithBlock(^ (id _self, id a0, BOOL userIsInteracting, BOOL blurPrev, id activityStateChanges, id userObject){
                ((void(*)(id, SEL, id, BOOL, BOOL, id, id))orig)(_self, sel1, a0, YES, blurPrev, activityStateChanges, userObject);
            });
            method_setImplementation(m1, rep);
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(sel1));
            hooked = YES;
        }

        SEL sel2 = NSSelectorFromString(@"_elementDidFocus:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method m2 = class_getInstanceMethod(WKContentView, sel2);
        if (m2) {
            IMP orig = method_getImplementation(m2);
            IMP rep  = imp_implementationWithBlock(^ (id _self, id a0, BOOL userIsInteracting, BOOL blurPrev, id changingActivityState, id userObject){
                ((void(*)(id, SEL, id, BOOL, BOOL, id, id))orig)(_self, sel2, a0, YES, blurPrev, changingActivityState, userObject);
            });
            method_setImplementation(m2, rep);
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(sel2));
            hooked = YES;
        }

        SEL sel3 = NSSelectorFromString(@"_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
        Method m3 = class_getInstanceMethod(WKContentView, sel3);
        if (m3) {
            IMP orig = method_getImplementation(m3);
            IMP rep  = imp_implementationWithBlock(^ (id _self, void* node, BOOL userIsInteracting, BOOL blurPrev, id userObject){
                ((void(*)(id, SEL, void*, BOOL, BOOL, id))orig)(_self, sel3, node, YES, blurPrev, userObject);
            });
            method_setImplementation(m3, rep);
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(sel3));
            hooked = YES;
        }

        if (hooked) {
            NSLog(@"[wk-inputfocusfix] Patch applied");
        } else {
            NSLog(@"[wk-inputfocusfix] No compatible selectors found — patch not applied");
        }
    });
}

@end
