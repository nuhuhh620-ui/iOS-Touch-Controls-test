#import <UIKit/UIKit.h>
#import <math.h>

// ==========================================
// 1. Define the Virtual Controller UI
// ==========================================
@interface VirtualControllerView : UIView
@property (nonatomic, strong) UIView *joystickBase;
@property (nonatomic, strong) UIView *joystickKnob;
@property (nonatomic, assign) CGPoint joystickCenter;
@end

@implementation VirtualControllerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        [self setupControls];
    }
    return self;
}

// CRITICAL: Allows touches on empty space to pass through to the game
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil;
    }
    return hitView;
}

- (void)setupControls {
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH =[UIScreen mainScreen].bounds.size.height;

    // --- ESC Button (Top Left) ---
    UIButton *escBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    escBtn.frame = CGRectMake(20, 40, 60, 40);[escBtn setTitle:@"ESC" forState:UIControlStateNormal];
    escBtn.backgroundColor =[UIColor colorWithWhite:0.2 alpha:0.5];
    [escBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    escBtn.layer.cornerRadius = 8.0;[escBtn addTarget:self action:@selector(escPressed) forControlEvents:UIControlEventTouchDown];
    [self addSubview:escBtn];

    // --- A Button (Bottom Right) ---
    UIButton *aBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    aBtn.frame = CGRectMake(screenW - 140, screenH - 80, 50, 50);
    [aBtn setTitle:@"A" forState:UIControlStateNormal];
    aBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    [aBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    aBtn.layer.cornerRadius = 25.0;
    [aBtn addTarget:self action:@selector(aPressed) forControlEvents:UIControlEventTouchDown];[aBtn addTarget:self action:@selector(aReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self addSubview:aBtn];

    // --- S Button (Bottom Right) ---
    UIButton *sBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sBtn.frame = CGRectMake(screenW - 80, screenH - 140, 50, 50);
    [sBtn setTitle:@"S" forState:UIControlStateNormal];
    sBtn.backgroundColor =[UIColor colorWithWhite:0.2 alpha:0.5];
    [sBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sBtn.layer.cornerRadius = 25.0;[sBtn addTarget:self action:@selector(sPressed) forControlEvents:UIControlEventTouchDown];[sBtn addTarget:self action:@selector(sReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self addSubview:sBtn];

    // --- Joystick (Bottom Left) ---
    self.joystickBase = [[UIView alloc] initWithFrame:CGRectMake(40, screenH - 160, 120, 120)];
    self.joystickBase.backgroundColor =[UIColor colorWithWhite:0.2 alpha:0.4];
    self.joystickBase.layer.cornerRadius = 60.0;
    self.joystickBase.userInteractionEnabled = YES;[self addSubview:self.joystickBase];

    self.joystickKnob = [[UIView alloc] initWithFrame:CGRectMake(35, 35, 50, 50)];
    self.joystickKnob.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.6];
    self.joystickKnob.layer.cornerRadius = 25.0;
    self.joystickKnob.userInteractionEnabled = NO;
    [self.joystickBase addSubview:self.joystickKnob];

    self.joystickCenter = CGPointMake(60, 60);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];[self.joystickBase addGestureRecognizer:pan];
}

// --- Joystick Logic ---
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation =[pan translationInView:self.joystickBase];
    
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = translation.x;
        CGFloat dy = translation.y;
        CGFloat distance = sqrt(dx*dx + dy*dy);
        CGFloat maxRadius = 35.0; 
        
        if (distance > maxRadius) {
            dx = dx * (maxRadius / distance);
            dy = dy * (maxRadius / distance);
        }
        
        self.joystickKnob.center = CGPointMake(self.joystickCenter.x + dx, self.joystickCenter.y + dy);
        
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {[UIView animateWithDuration:0.2 animations:^{
            self.joystickKnob.center = self.joystickCenter;
        }];
    }
}

// --- Button Actions ---
- (void)escPressed { NSLog(@"[Controls] ESC Pressed"); }
- (void)aPressed { NSLog(@"[Controls] A Pressed"); }
- (void)aReleased { NSLog(@"[Controls] A Released"); }
- (void)sPressed { NSLog(@"[Controls] S Pressed"); }
- (void)sReleased { NSLog(@"[Controls] S Released"); }
@end

// ==========================================
// 2. BULLETPROOF INJECTION LOGIC
// ==========================================

// This function checks over and over until the game's window is 100% loaded
static void inject_overlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UIWindow *targetWindow = [UIApplication sharedApplication].keyWindow;
        
        // Fallback for newer iOS games using SceneDelegate
        if (!targetWindow) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            targetWindow = window;
                            break;
                        }
                    }
                }
            }
        }

        // If the window exists and the game has actually given it a size...
        if (targetWindow && targetWindow.bounds.size.width > 0) {
            
            // Check if we already injected it so we don't accidentally do it twice
            for (UIView *subview in targetWindow.subviews) {
                if ([subview isKindOfClass:[VirtualControllerView class]]) {
                    return; 
                }
            }
            
            // Create the overlay
            VirtualControllerView *overlay = [[VirtualControllerView alloc] initWithFrame:targetWindow.bounds];
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            // CRITICAL: This forces the controls to hover ABOVE the game's OpenGL/Metal graphics layer
            overlay.layer.zPosition = 99999; 
            
            // Add it to the screen
            [targetWindow addSubview:overlay];
            [targetWindow bringSubviewToFront:overlay];
            
            NSLog(@"[+] Touch Controls Injected Successfully on top of Game!");
            
        } else {
            // The game hasn't loaded its graphics yet. Wait 1 second and try again!
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                inject_overlay();
            });
        }
    });
}

// The starting point when the dylib is loaded
static void __attribute__((constructor)) initialize_controls(void) {
    NSLog(@"[+] Touch Controls Dylib Loaded into memory! Waiting for game to load...");
    
    // Wait 3 seconds before starting our checks to give the heavy game engine time to breathe
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        inject_overlay();
    });
}
