#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "CDV.h"

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
    // Читаем <preference name="KeyboardDisplayRequiresUserAction" value="false" />
    // В settings ключи нижним регистром.
    id pref = self.commandDelegate.settings[@"keyboarddisplayrequiresuseraction"];
    BOOL requiresUserAction = YES; // дефолт iOS
    if ([pref respondsToSelector:@selector(boolValue)]) {
        requiresUserAction = [pref boolValue];
    } else if ([pref isKindOfClass:[NSString class]]) {
        requiresUserAction = [((NSString *)pref) boolValue];
    }

    if (!requiresUserAction) {
        [self.class enablePatch];
    }
}

+ (void)enablePatch {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class WKContentView = NSClassFromString(@"WKContentView");
        if (!WKContentView) return;

        // iOS 13+ (и актуальные iOS 17/18):
        SEL selFocusActChanges = NSSelectorFromString(@"_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:");
        PatchMethod(WKContentView, selFocusActChanges, ^IMP(IMP original){
            if (!original) return (IMP)NULL;
            return imp_implementationWithBlock(^ (id _self, id arg0, BOOL userIsInteracting, BOOL blurPrev, id activityStateChanges, id userObject){
                // принудительно считаем, что пользователь взаимодействует
                ((void(*)(id, SEL, id, BOOL, BOOL, id, id))original)(_self, selFocusActChanges, arg0, YES, blurPrev, activityStateChanges, userObject);
            });
        });

        // iOS 12.2–13 beta (другое имя параметра):
        SEL selFocusChanging = NSSelectorFromString(@"_elementDidFocus:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        PatchMethod(WKContentView, selFocusChanging, ^IMP(IMP original){
            if (!original) return (IMP)NULL;
            return imp_implementationWithBlock(^ (id _self, id arg0, BOOL userIsInteracting, BOOL blurPrev, id changingActivityState, id userObject){
                ((void(*)(id, SEL, id, BOOL, BOOL, id, id))original)(_self, selFocusChanging, arg0, YES, blurPrev, changingActivityState, userObject);
            });
        });

        // Старые iOS (10–12): до iOS 12 — другой метод
        SEL selStartAssist = NSSelectorFromString(@"_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
        PatchMethod(WKContentView, selStartAssist, ^IMP(IMP original){
            if (!original) return (IMP)NULL;
            return imp_implementationWithBlock(^ (id _self, void* node, BOOL userIsInteracting, BOOL blurPrev, id userObject){
                ((void(*)(id, SEL, void*, BOOL, BOOL, id))original)(_self, selStartAssist, node, YES, blurPrev, userObject);
            });
        });

#ifdef DEBUG
        NSLog(@"[cordova-plugin-ios-inputfocusfix] Patch applied (WKWebView keyboard can show without user action).");
#endif
    });
}

@end
