//
//  windowManager.m
//  windowManager
//
//  Created by NetEase on 16/3/9.
//  Copyright © 2016年 NetEase. All rights reserved.
//

#import "windowManager.h"

@import ObjectiveC;

@interface CPTemplateWindow:UIWindow
@end
@implementation CPTemplateWindow
@end

@interface UIWindow (WindowPresentationPrivate)

-(void)setPresentingWindow:(UIWindow *)presentingWindow;

@end

@implementation UIWindow (WindowPresentation)

- (void)presentWindow:(UIWindow *)window animated:(BOOL)animated completion:(void (^)(void))completion
{
    [[windowManager sharedInstance] presentWindow:window fromWindow:self animated:animated completion:completion];
}

- (void)dismissWindow:(UIWindow *)window animated:(BOOL)animated completion:(void (^)(void))completion
{
    [[windowManager sharedInstance] dismissWindow:window fromWindow:self animated:animated completion:completion];
}

- (NSArray *)presentedWindows
{
    return [[windowManager sharedInstance] presentedWindowsFromWindow:self];
}

- (UIWindow *)presentingWindow
{
    return objc_getAssociatedObject(self, "prop__presentingWindow");
}

- (void)setPresentingWindow:(UIWindow *)presentingWindow
{
    objc_setAssociatedObject(self, "prop__presentingWindow", presentingWindow, OBJC_ASSOCIATION_ASSIGN);
}

@end


static __strong windowManager *sharedWindowManagerInstance;

@interface windowManager(){
    NSMutableDictionary *_windowPresentationMapping;
    UIWindow *_topWindow;
}
@end

@implementation windowManager
+ (windowManager *)sharedInstance
{
    static windowManager *windowTempManager = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        windowTempManager = [[windowManager alloc] init];
        sharedWindowManagerInstance->_windowPresentationMapping = [[NSMutableDictionary alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedWindowManagerInstance selector:@selector(windowDidBecomeKeyNotification:) name:UIWindowDidBecomeKeyNotification object:nil];
    });
    return windowTempManager;
}

+ (UIWindow*)templateWindowForName:(NSString*)name
{
    Class class = [CPTemplateWindow class];
    
    if(name != nil)
    {
        NSString *className = [NSString stringWithFormat:@"CPTemplateWindow_%@", name];
        
        //See if our new class already exists.
        class = objc_getClass(className.UTF8String);
        
        if(class == nil)
        {
            //Create a new class, which is subclass of the view's class.
            class = objc_allocateClassPair([CPTemplateWindow class], className.UTF8String, 0);
            
            //Register the new class in the objective C runtime.
            objc_registerClassPair(class);
        }
    }
    
    UIWindow *templateWindow = [[class alloc] initWithFrame:[UIScreen mainScreen].bounds];
    templateWindow.windowLevel = UIWindowLevelNormal;
    templateWindow.hidden = YES;
    [templateWindow setTintColor:[UIColor clearColor]];
    
    return templateWindow;
}

- (void)dismissKeyboard
{
    //Use responder chain to resign first responder and dismiss the keyboard.
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

- (void)windowDidBecomeKeyNotification:(NSNotification*)notification
{
    if(_topWindow == nil)
    {
        UIWindow* topWindow = notification.object;
        
        if(NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1 && [topWindow.class.description rangeOfString:@"UIAlert"].location != NSNotFound)
        {
            return;
        }
        
        //Take first key window as top.
        _topWindow = topWindow;
    }
}
////

-(void)presentWindowFromKeyWindow:(UIWindow*)presentedWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
    [self presentWindow:presentedWindow fromWindow:[UIApplication sharedApplication].keyWindow animated:animated completion:completion];
}

-(void)presentWindow:(UIWindow *)presentedWindow fromWindow:(UIWindow*)presentingWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
    if(presentingWindow.isKeyWindow)
    {
        [self dismissKeyboard];
    }
    
    NSAssert(presentedWindow != presentingWindow, @"Presenting window cannot be equal to presented window: <%@, %p>", presentedWindow.class, presentedWindow);
    NSAssert(presentedWindow.presentingWindow == nil, @"Window <%@, %p> is already presented by window <%@, %p>.", presentedWindow.class, presentedWindow, presentedWindow.presentingWindow.class, presentedWindow.presentingWindow);
    
    NSValue* key = [NSValue valueWithNonretainedObject:presentingWindow];
    
    NSMutableArray* presentedWindows = _windowPresentationMapping[key];
    if(presentedWindows == nil)
    {
        presentedWindows = [NSMutableArray new];
    }
    
    [presentedWindows addObject:presentedWindow];
    
    CGRect frame = presentedWindow.frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    [presentedWindow setFrame:frame];
    
    
    if(presentingWindow.isKeyWindow)
    {
        [presentedWindow makeKeyWindow];
    }
    
    presentedWindow.alpha = 1.0f;
    presentedWindow.hidden = NO;
    
    _topWindow = presentedWindow;
    [presentedWindow setPresentingWindow:presentingWindow];
    
    presentingWindow.windowLevel = UIWindowLevelNormal;
    presentedWindow.windowLevel = UIWindowLevelNormal + 1;
    
    NSLog(@"Presenting window <%@, %p> from window <%@, %p>", presentedWindow.class, presentedWindow, presentingWindow.class, presentingWindow);
    
    if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1)
    {
       [presentingWindow setHidden:YES];
    }
     
    if(completion != nil)
    {
        completion();
    }
    
    _windowPresentationMapping[key] = presentedWindows;
}

- (void)dismissWindowFromKeyWindow:(UIWindow *)presentedWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
    [self dismissWindow:presentedWindow fromWindow:[UIApplication sharedApplication].keyWindow animated:animated completion:completion];
}

- (void)dismissWindow:(UIWindow *)presentedWindow fromWindow:(UIWindow *)presentingWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
    NSAssert(presentedWindow != presentingWindow, @"Dissmising window cannot be equal to presented window: <%@, %p>", presentedWindow.class, presentedWindow);
    NSAssert(presentedWindow.presentingWindow == presentingWindow, @"Window <%@, %p> has not been presented by window <%@, %p>", presentedWindow.class, presentedWindow, presentingWindow.class, presentingWindow);
    
    BOOL shouldMakeKey = NO;
    
    if(presentedWindow.isKeyWindow)
    {
        [self dismissKeyboard];
        
        shouldMakeKey = YES;
    }
    
    NSValue* key = [NSValue valueWithNonretainedObject:presentingWindow];
    
    NSMutableArray* presentedWindows = _windowPresentationMapping[key];
    if(presentedWindows == nil)
    {
        presentedWindows = [NSMutableArray new];
    }
    
    NSMutableArray* cleanup = [NSMutableArray new];
    
    _windowPresentationMapping[key] = presentedWindows;
    
    _topWindow = presentingWindow;
    
    // Dismiss child windows recuresively
    for (UIWindow* window in presentedWindow.presentedWindows) {
        [presentedWindow dismissWindow:window animated:NO completion:nil];
    }
    
    [presentingWindow.rootViewController viewWillAppear:animated];
    
#ifdef LN_WINDOW_MANAGER_DEBUG
    NSLog(@"Dismissing window <%@, %p> from window <%@, %p>", presentedWindow.class, presentedWindow, presentingWindow.class, presentingWindow);
#endif
    
    if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 && presentedWindow.rootViewController.presentedViewController.modalPresentationStyle == UIModalPresentationFullScreen)
    {
        [presentingWindow setHidden:NO];
    }
    
    [presentedWindow.rootViewController dismissViewControllerAnimated:animated completion: ^{
         [presentingWindow.rootViewController viewDidAppear:animated];
         
         presentingWindow.windowLevel = UIWindowLevelNormal + 1;
         
         
         [presentedWindow setPresentingWindow:nil];
         
         if(completion != nil)
         {
             completion();
         }
         
         [presentedWindow setRootViewController:nil];
         
         if(shouldMakeKey)
         {
             [presentingWindow makeKeyWindow];
         }
         
         [presentedWindow setHidden:YES];
         
         [cleanup addObject:presentedWindow];
         [presentedWindows removeObject:presentedWindow];
         
         //Perform cleanup late in the game to allow iOS7 UIWindow logic to complete gracefully.
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             [cleanup removeAllObjects];
         });
     }];
}

-(NSArray*)presentedWindowsFromKeyWindow
{
    return [self presentedWindowsFromWindow:[UIApplication sharedApplication].keyWindow];
}

-(NSArray*)presentedWindowsFromWindow:(UIWindow*)presentingWindow
{
    NSValue* key = [NSValue valueWithNonretainedObject:presentingWindow];
    
    NSMutableArray* presentedWindows = _windowPresentationMapping[key];
    
    return presentedWindows == nil ? @[] : presentedWindows;
}

- (UIWindow*)topWindow
{
    return _topWindow;
}

@end
