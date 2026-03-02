#import <UIKit/UIKit.h>
#import <math.h>
#import <dlfcn.h> // Required for hacking into the PC Game's engine

// ==========================================
// 1. PC GAME KEYBOARD SIMULATION (SDL2)
// ==========================================
typedef struct {
    uint32_t scancode;
    int32_t sym;
    uint16_t mod;
    uint32_t unused;
} SDL_Keysym;

typedef struct {
    uint32_t type;
    uint32_t timestamp;
    uint32_t windowID;
    uint8_t state;
    uint8_t repeat;
    uint8_t padding2;
    uint8_t padding3;
    SDL_Keysym keysym;
} SDL_KeyboardEvent;

typedef union {
    uint32_t type;
    SDL_KeyboardEvent key;
    uint8_t padding[56];
} SDL_Event;


// ==========================================
// 2. Define the Virtual Controller UI
// ==========================================
@interface VirtualControllerView : UIView
@property (nonatomic, strong) UIView *joystickBase;
@property (nonatomic, strong) UIView *joystickKnob;
@property (nonatomic, assign) CGPoint joystickCenter;

// Tracking keyboard hold states for Arrow Keys
@property (nonatomic, assign) BOOL isUpDown;
@property (nonatomic, assign) BOOL isDownDown;
@property (nonatomic, assign) BOOL isLeftDown;
@property (nonatomic, assign) BOOL isRightDown;
@end

@implementation VirtualControllerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor =[UIColor clearColor];
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

// --- MAGIC INJECTION METHOD ---
// Takes both 'sym' and 'scancode' to guarantee the game detects Arrow Keys
- (void)simulateKey:(int)keyCode scancode:(int)scanCode isDown:(BOOL)isDown {
    static int (*SDL_PushEvent_Func)(SDL_Event*) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen(NULL, RTLD_NOW);
        SDL_PushEvent_Func = (int (*)(SDL_Event*))dlsym(handle, "SDL_PushEvent");
    });

    if (SDL_PushEvent_Func) {
        SDL_Event event;
        memset(&event, 0, sizeof(event));
        event.type = isDown ? 0x300 /* SDL_KEYDOWN */ : 0x301 /* SDL_KEYUP */;
        event.key.state = isDown ? 1 : 0;
        event.key.keysym.sym = keyCode;
        event.key.keysym.scancode = scanCode;
        SDL_PushEvent_Func(&event);
    }
}

- (void)setupControls {
    CGFloat screenW =[UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;

    // --- ESC Button (Top Left) ---
    UIButton *escBtn =[UIButton buttonWithType:UIButtonTypeSystem];
    escBtn.frame = CGRectMake(20, 40, 60, 40);
    [escBtn setTitle:@"ESC" forState:UIControlStateNormal];
    escBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];[escBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    escBtn.layer.cornerRadius = 8.0;[escBtn addTarget:self action:@selector(escPressed) forControlEvents:UIControlEventTouchDown];[escBtn addTarget:self action:@selector(escReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self addSubview:escBtn];

    // --- A Button (Bottom Right) ---
    UIButton *aBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    aBtn.frame = CGRectMake(screenW - 120, screenH - 120, 90, 90);
    [aBtn setTitle:@"A" forState:UIControlStateNormal];
    aBtn.titleLabel.font = [UIFont boldSystemFontOfSize:35];
    aBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    [aBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    aBtn.layer.cornerRadius = 45.0;
    [aBtn addTarget:self action:@selector(aBtnPressed) forControlEvents:UIControlEventTouchDown];[aBtn addTarget:self action:@selector(aBtnReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self addSubview:aBtn];

    // --- S Button (To the left of A) ---
    UIButton *sBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sBtn.frame = CGRectMake(screenW - 230, screenH - 120, 90, 90);
    [sBtn setTitle:@"S" forState:UIControlStateNormal];
    sBtn.titleLabel.font = [UIFont boldSystemFontOfSize:35];
    sBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];[sBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sBtn.layer.cornerRadius = 45.0;[sBtn addTarget:self action:@selector(sBtnPressed) forControlEvents:UIControlEventTouchDown];[sBtn addTarget:self action:@selector(sBtnReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self addSubview:sBtn];

    // --- Joystick (Bottom Left) ---
    self.joystickBase = [[UIView alloc] initWithFrame:CGRectMake(40, screenH - 220, 180, 180)];
    self.joystickBase.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.4];
    self.joystickBase.layer.cornerRadius = 90.0;
    self.joystickBase.userInteractionEnabled = YES;
    [self addSubview:self.joystickBase];

    self.joystickKnob = [[UIView alloc] initWithFrame:CGRectMake(50, 50, 80, 80)];
    self.joystickKnob.backgroundColor =[UIColor colorWithWhite:0.8 alpha:0.6];
    self.joystickKnob.layer.cornerRadius = 40.0;
    self.joystickKnob.userInteractionEnabled = NO;[self.joystickBase addSubview:self.joystickKnob];

    self.joystickCenter = CGPointMake(90, 90);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.joystickBase addGestureRecognizer:pan];
}

// --- Joystick -> ARROW KEYS Keyboard Logic ---
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.joystickBase];
    
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = translation.x;
        CGFloat dy = translation.y;
        CGFloat distance = sqrt(dx*dx + dy*dy);
        CGFloat maxRadius = 50.0; 
        
        if (distance > maxRadius) {
            dx = dx * (maxRadius / distance);
            dy = dy * (maxRadius / distance);
        }
        
        self.joystickKnob.center = CGPointMake(self.joystickCenter.x + dx, self.joystickCenter.y + dy);
        
        // Translate physical joystick movement into UP, DOWN, LEFT, RIGHT
        BOOL upNow = dy < -25;
        BOOL downNow = dy > 25;
        BOOL leftNow = dx < -25;
        BOOL rightNow = dx > 25;
        
        if (upNow != self.isUpDown) {[self simulateKey:1073741906 scancode:82 isDown:upNow]; 
            self.isUpDown = upNow; 
        }
        if (downNow != self.isDownDown) {[self simulateKey:1073741905 scancode:81 isDown:downNow]; 
            self.isDownDown = downNow; 
        }
        if (leftNow != self.isLeftDown) {[self simulateKey:1073741904 scancode:80 isDown:leftNow]; 
            self.isLeftDown = leftNow; 
        }
        if (rightNow != self.isRightDown) {[self simulateKey:1073741903 scancode:79 isDown:rightNow]; 
            self.isRightDown = rightNow; 
        }
        
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        
        // Let go of all arrow keys
        if (self.isUpDown) {[self simulateKey:1073741906 scancode:82 isDown:NO]; 
            self.isUpDown = NO; 
        }
        if (self.isDownDown) {[self simulateKey:1073741905 scancode:81 isDown:NO]; 
            self.isDownDown = NO; 
        }
        if (self.isLeftDown) {[self simulateKey:1073741904 scancode:80 isDown:NO]; 
            self.isLeftDown = NO; 
        }
        if (self.isRightDown) {[self simulateKey:1073741903 scancode:79 isDown:NO]; 
            self.isRightDown = NO; 
        }
        
        // Snap back to center[UIView animateWithDuration:0.2 animations:^{
            self.joystickKnob.center = self.joystickCenter;
        }];
    }
}

// --- Button Actions -> 'A', 'S', and 'ESC' Keyboard Presses ---
- (void)escPressed   {[self simulateKey:27 scancode:41 isDown:YES]; }
- (void)escReleased  { [self simulateKey:27 scancode:41 isDown:NO]; }
- (void)aBtnPressed  { [self simulateKey:97 scancode:4 isDown:YES]; }
- (void)aBtnReleased {[self simulateKey:97 scancode:4 isDown:NO]; }
- (void)sBtnPressed  {[self simulateKey:115 scancode:22 isDown:YES]; }
- (void)sBtnReleased {[self simulateKey:115 scancode:22 isDown:NO]; }
@end


// ==========================================
// 3. BULLETPROOF INJECTION LOGIC
// ==========================================
static void inject_overlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UIWindow *targetWindow = [UIApplication sharedApplication].keyWindow;
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

        if (targetWindow && targetWindow.bounds.size.width > 0) {
            for (UIView *subview in targetWindow.subviews) {
                if ([subview isKindOfClass:[VirtualControllerView class]]) { 
                    return; 
                }
            }
            
            VirtualControllerView *overlay = [[VirtualControllerView alloc] initWithFrame:targetWindow.bounds];
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            overlay.layer.zPosition = 99999;
            
            [targetWindow addSubview:overlay];
            [targetWindow bringSubviewToFront:overlay];
            
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                inject_overlay();
            });
        }
    });
}

static void __attribute__((constructor)) initialize_controls(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        inject_overlay();
    });
}
