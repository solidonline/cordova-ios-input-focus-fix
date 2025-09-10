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

        // iOS 13+ : _elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:
        SEL sel13 = NSSelectorFromString(@"_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:");
        Method m13 = class_getInstanceMethod(WKContentView, sel13);
        if (m13) {
            typedef void (*orig_t)(id, SEL, void*, BOOL, BOOL, BOOL, id);
            orig_t orig = (orig_t)method_getImplementation(m13);
            id blk = ^(id me, void *arg0, BOOL userIsInteracting, BOOL blurPrev, BOOL activityStateChanges, id userObject){
                orig(me, sel13, arg0, YES, blurPrev, activityStateChanges, userObject);
            };
            method_setImplementation(m13, imp_implementationWithBlock(blk));
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(sel13));
            hooked = YES;
        }

        // iOS 12.2–13.0 beta : _elementDidFocus:...changingActivityState:... (BOOL)
        SEL sel122 = NSSelectorFromString(@"_elementDidFocus:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method m122 = class_getInstanceMethod(WKContentView, sel122);
        if (m122) {
            typedef void (*orig_t)(id, SEL, void*, BOOL, BOOL, BOOL, id);
            orig_t orig = (orig_t)method_getImplementation(m122);
            id blk = ^(id me, void *arg0, BOOL userIsInteracting, BOOL blurPrev, BOOL changingActivityState, id userObject){
                orig(me, sel122, arg0, YES, blurPrev, changingActivityState, userObject);
            };
            method_setImplementation(m122, imp_implementationWithBlock(blk));
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(sel122));
            hooked = YES;
        }

        // iOS 11.3–12.1 : _startAssistingNode:...changingActivityState:... (BOOL)
        SEL sel113 = NSSelectorFromString(@"_startAssistingNode:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method m113 = class_getInstanceMethod(WKContentView, sel113);
        if (m113) {
            typedef void (*orig_t)(id, SEL, void*, BOOL, BOOL, BOOL, id);
            orig_t orig = (orig_t)method_getImplementation(m113);
            id blk = ^(id me, void *node, BOOL userIsInteracting, BOOL blurPrev, BOOL changingActivityState, id userObject){
                orig(me, sel113, node, YES, blurPrev, changingActivityState, userObject);
            };
            method_setImplementation(m113, imp_implementationWithBlock(blk));
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(sel113));
            hooked = YES;
        }

        // iOS 10–11.2 : _startAssistingNode:userIsInteracting:blurPreviousNode:userObject:
        SEL selOld = NSSelectorFromString(@"_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
        Method mOld = class_getInstanceMethod(WKContentView, selOld);
        if (mOld) {
            typedef void (*orig_t)(id, SEL, void*, BOOL, BOOL, id);
            orig_t orig = (orig_t)method_getImplementation(mOld);
            id blk = ^(id me, void *node, BOOL userIsInteracting, BOOL blurPrev, id userObject){
                orig(me, selOld, node, YES, blurPrev, userObject);
            };
            method_setImplementation(mOld, imp_implementationWithBlock(blk));
            NSLog(@"[wk-inputfocusfix] hooked %@", NSStringFromSelector(selOld));
            hooked = YES;
        }

        if (hooked) NSLog(@"[wk-inputfocusfix] Patch applied");
        else NSLog(@"[wk-inputfocusfix] No compatible selectors found — patch not applied");
    });
}

@end
