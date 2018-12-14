/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "OSInAppMessageViewController.h"
#import "OSInAppMessageView.h"
#import "OneSignalHelper.h"

#define HIGHEST_CONSTRAINT_PRIORITY 999.0f
#define HIGH_CONSTRAINT_PRIORITY 990.0f
#define MEDIUM_CONSTRAINT_PRIORITY 950.0f
#define LOW_CONSTRAINT_PRIORITY 900.0f

@interface OSInAppMessageViewController ()

// The message object
@property (strong, nonatomic, nonnull) OSInAppMessage *message;

// The actual message subview
@property (weak, nonatomic, nullable) OSInAppMessageView *messageView;

// Before the message display animation, this constrains the Y position
// of the message to be off-screen
@property (strong, nonatomic, nonnull) NSLayoutConstraint *initialYConstraint;

// This constrains the Y position once the initial animation is finished
@property (strong, nonatomic, nonnull) NSLayoutConstraint *finalYConstraint;

// This constraint enforces an aspect ratio for the given message type (ie. banner)
@property (strong, nonatomic, nonnull) NSLayoutConstraint *heightConstraint;

// This recognizer lets the user pan (swipe) the message up and down
@property (weak, nonatomic, nullable) UIPanGestureRecognizer *panGestureRecognizer;

// This tap recognizer lets us dismiss the message if the user taps the background
@property (weak, nonatomic, nullable) UITapGestureRecognizer *tapGestureRecognizer;

// This point represents the X/Y location of where the most recent
// pan gesture started. Used to determine the offset
@property (nonatomic) CGPoint initialGestureRecognizerLocation;

// This constraint determines the Y position when panning the message up or down
@property (strong, nonatomic, nullable) NSLayoutConstraint *panVerticalConstraint;

// This timer is used to dismiss in-app messages if the "max_display_time" is set
// We start the timer once the message is displayed (not during loading the content)
@property (weak, nonatomic, nullable) NSTimer *dismissalTimer;
@end

@implementation OSInAppMessageViewController

- (instancetype _Nonnull)initWithMessage:(OSInAppMessage *)inAppMessage {
    if (self = [super init]) {
        self.message = inAppMessage;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Sets up the message view in a hidden position while we wait
    // for the actual HTML content to load
    [self setupInitialMessageUI];
    
    // loads the HTML content
    [self loadMessageContent];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.dismissalTimer invalidate];
}

// sets up the message UI. It is still hidden. Wait until
// the actual HTML content is loaded before animating appearance
- (void)setupInitialMessageUI {
    self.view.alpha = 0.0;
    
    let messageSubview = [[OSInAppMessageView alloc] initWithMessage:self.message];
    self.messageView = messageSubview;
    self.messageView.delegate = self;
    
    self.messageView.translatesAutoresizingMaskIntoConstraints = false;
    self.messageView.backgroundColor = [UIColor blackColor];
    self.messageView.layer.cornerRadius = 10.0f;
    self.messageView.clipsToBounds = true;
    
    [self.view addSubview:self.messageView];
    
    [self addConstraintsForMessage];
    
    [self setupGestureRecognizers];
}

- (void)displayMessage {
    [UIView animateWithDuration:0.3 animations:^{
        self.view.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        self.view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        
        [self animateAppearance];
    }];
    
    
    // If the message has a max display time, set up the timer now
    if (self.message.maxDisplayTime > 0.0f)
        self.dismissalTimer = [NSTimer scheduledTimerWithTimeInterval:self.message.maxDisplayTime target:self selector:@selector(maxDisplayTimeTimerFinished) userInfo:nil repeats:false];
}

- (void)maxDisplayTimeTimerFinished {
    [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop withVelocity:0.0f];
}

- (void)loadMessageContent {
    //TODO: This code is to be used when the API supports real in-app messages
//    [self.message loadHTMLContentWithResult:^(NSString * _Nonnull html) {
//        [self displayMessageWithHTML:html];
//    } withFailure:^(NSError *error) {
//        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error while attempting to download HTML content for message: %@", error.description ?: @"Unknown Error"]];
//    }];
}

/**
    Sets up the message view in its initial (hidden) position
    Adds constraints so that the message view has the correct size.
 
    Once the HTML content is loaded, we call animateAppearance() to
    show the message view.
*/
- (void)addConstraintsForMessage {
    
    NSLayoutAnchor *top = self.view.topAnchor, *bottom = self.view.bottomAnchor, *leading = self.view.leadingAnchor, *trailing = self.view.trailingAnchor, *center = self.view.centerXAnchor;
    NSLayoutDimension *height = self.view.heightAnchor;
    
    // The safe area represents the anchors that are not obscurable by  UI such
    // as a notch or a rounded corner on newer iOS devices like iPhone X
    if (@available(iOS 11, *)) {
        let safeArea = self.view.safeAreaLayoutGuide;
        top = safeArea.topAnchor, bottom = safeArea.bottomAnchor, leading = safeArea.leadingAnchor, trailing = safeArea.trailingAnchor, center = safeArea.centerXAnchor;
        height = safeArea.heightAnchor;
    }
    
    // The spacing between the message view & edges
    let marginSpacing = MESSAGE_MARGIN * [UIScreen mainScreen].bounds.size.width;
    
    // Constrains the message view to a max width to look better on iPads & landscape
    var maxWidth = MIN(self.view.bounds.size.height, self.view.bounds.size.width);
    maxWidth -= 2 * marginSpacing;
    
    // Configures the aspect ratio depending on the message type
    var aspectRatio = BANNER_ASPECT_RATIO;
    
    if (self.message.type == OSInAppMessageDisplayTypeFullScreen)
        aspectRatio = UIScreen.mainScreen.bounds.size.width / UIScreen.mainScreen.bounds.size.height;
    else if (self.message.type == OSInAppMessageDisplayTypeCenteredModal)
        aspectRatio = CENTERED_MODAL_ASPECT_RATIO;
    
    // pins the message view to the left & right
    let leftConstraint = [self.messageView.leadingAnchor constraintEqualToAnchor:leading constant:marginSpacing];
    let rightConstraint = [self.messageView.trailingAnchor constraintEqualToAnchor:trailing constant:-marginSpacing];
    leftConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    rightConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    leftConstraint.active = true;
    rightConstraint.active = true;
    
    [self.messageView.centerXAnchor constraintEqualToAnchor:center].active = true;
    
    // The aspect ratio for each type (ie. Banner) determines the height normally
    // However the actual height of the HTML content takes priority.
    [self.messageView.heightAnchor constraintLessThanOrEqualToAnchor:height multiplier:1.0 constant:-(2.0f * marginSpacing)].active = true;
    
    
    self.heightConstraint = [self.messageView.heightAnchor constraintEqualToAnchor:self.messageView.widthAnchor multiplier:1.0f/aspectRatio constant:0.0f];
    self.heightConstraint.priority = HIGH_CONSTRAINT_PRIORITY;
    self.heightConstraint.active = true;
    
    // add Y constraints
    // Since we animate the appearance of the message (ie. slide in from top),
    // there are two constraints: initial and final. At initialization, the initial
    // constraint has a higher priority. The pan constraint is used only when panning
    switch (self.message.position) {
        case OSInAppMessageDisplayPositionTop:
            [self.messageView.widthAnchor constraintLessThanOrEqualToConstant:maxWidth].active = true;
            self.initialYConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:self.view.topAnchor constant:-8.0f];
            self.finalYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:top constant:marginSpacing];
            self.panVerticalConstraint = [self.messageView.topAnchor constraintEqualToAnchor:top constant:marginSpacing];
            break;
        case OSInAppMessageDisplayPositionCentered:
            self.initialYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f];
            self.finalYConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:0.0f];
            self.panVerticalConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:0.0f];
            break;
        case OSInAppMessageDisplayPositionBottom:
            [self.messageView.widthAnchor constraintLessThanOrEqualToConstant:maxWidth].active = true;
            self.initialYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f];
            self.finalYConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:bottom constant:-marginSpacing];
            self.panVerticalConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:bottom constant:-marginSpacing];
            break;
    }
    
    self.initialYConstraint.priority = HIGH_CONSTRAINT_PRIORITY;
    self.finalYConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    self.panVerticalConstraint.priority = HIGHEST_CONSTRAINT_PRIORITY;
    self.panVerticalConstraint.active = false;
    self.initialYConstraint.active = true;
    self.finalYConstraint.active = true;
    
    [self.view layoutIfNeeded];
}

// Dismisses the message view with a given direction (up or down) and velocity
// If velocity == 0.0, the default dismiss velocity will be used.
- (void)dismissMessageWithDirection:(BOOL)up withVelocity:(double)velocity {
    // inactivate the current Y constraints
    self.finalYConstraint.active = false;
    self.initialYConstraint.active = false;
    
    // The distance that the dismissal animation will travel
    var distance = 0.0f;
    
    // add new Y constraints
    if (up) {
        distance = self.messageView.frame.origin.y + self.messageView.frame.size.height + 8.0f;
        [self.messageView.bottomAnchor constraintEqualToAnchor:self.view.topAnchor constant:-8.0f].active = true;
    } else {
        distance = self.view.frame.size.height - self.messageView.frame.origin.y + 8.0f;
        [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f].active = true;
    }
    
    var dismissAnimationDuration = velocity != 0.0f ? distance / fabs(velocity) : 0.3f;
    
    var animationOption = UIViewAnimationOptionCurveLinear;
    
    // impose a minimum animation speed (max duration)
    if (dismissAnimationDuration > MAX_DISMISSAL_ANIMATION_DURATION) {
        animationOption = UIViewAnimationOptionCurveEaseIn;
        dismissAnimationDuration = MAX_DISMISSAL_ANIMATION_DURATION;
    }
    
    [UIView animateWithDuration:dismissAnimationDuration delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^{
        self.view.backgroundColor = [UIColor clearColor];
        self.view.alpha = 0.0f;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        
        [self dismissViewControllerAnimated:false completion:nil];
        
        [self.delegate messageViewControllerWasDismissed];
    }];
}

// Once HTML is loaded, the message should be presented. This method
// animates the actual appearance of the message view.
- (void)animateAppearance {
    self.initialYConstraint.priority = LOW_CONSTRAINT_PRIORITY;
    
    [UIView animateWithDuration:0.3f animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)beginPanAtLocation:(CGPoint)location {
    self.panVerticalConstraint.constant = self.finalYConstraint.constant;
    self.initialGestureRecognizerLocation = location;
    self.panVerticalConstraint.active = true;
}

// Adds the pan recognizer (for swiping up and down)
// and the tap recognizer (for dismissing)
- (void)setupGestureRecognizers {
    // Pan gesture recognizer for swiping
    let recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizerDidMove:)];
    
    [self.messageView addGestureRecognizer:recognizer];
    
    recognizer.maximumNumberOfTouches = 1;
    recognizer.minimumNumberOfTouches = 1;
    
    self.panGestureRecognizer = recognizer;
    
    // Tap gesture recognizer for tapping background (dismissing)
    let tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognizerDidTap:)];
    
    tapRecognizer.numberOfTapsRequired = 1;
    
    [self.view addGestureRecognizer:tapRecognizer];
    
    self.tapGestureRecognizer = tapRecognizer;
}

// Called when the user pans (swipes) the message view
- (void)panGestureRecognizerDidMove:(UIPanGestureRecognizer *)sender {
    
    // Tells us the location of the gesture inside the entire view
    let location = [sender locationInView:self.view];
    
    // Tells us the velocity of the dismissal gesture in points per second
    let velocity = [sender velocityInView:self.view].y;
    
    // Return early if we are just beginning the pan interaction
    // Set up the pan constraints to move the view
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self beginPanAtLocation:location];
        
        // since the user interacted with the content, cancel the
        // max display time timer if it is scheduled
        if (self.dismissalTimer)
            [self.dismissalTimer invalidate];
        
        return;
    }
    
    // tells us the offset from the message view's normal position
    let offset = self.initialGestureRecognizerLocation.y - location.y;
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        // Inactivate the pan constraint since we are no longer panning
        self.panVerticalConstraint.active = false;
        
        // Indicates if the in-app message was swiped away
        if ([self shouldDismissMessageWithPanGestureOffset:offset withVelocity:velocity]) {
            
            // Centered messages can be dismissed in either direction (up/down)
            if (self.message.position == OSInAppMessageDisplayPositionCentered) {
                [self dismissMessageWithDirection:offset > 0 withVelocity:velocity];
            } else {
                // Top messages can only be dismissed by swiping up
                // Bottom messages can only be dismissed swiping down
                [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop withVelocity:velocity];
            }
        } else {
            // The pan constraint is now inactive, calling layoutIfNeeded()
            // will cause the message to snap back to normal position
            [UIView animateWithDuration:0.3 animations:^{
                [self.view layoutIfNeeded];
            }];
        }
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        // The pan interaction is in progress, move the view to match the offset
        self.panVerticalConstraint.constant = self.finalYConstraint.constant - offset;
        
        [self.view layoutIfNeeded];
    }
}

// Called when the user taps on the background view
- (void)tapGestureRecognizerDidTap:(UITapGestureRecognizer *)sender {
    [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop withVelocity:0.0f];
}

// Returns a boolean indicating if the message view should be dismissed
// for the given pan offset (ie. if the user has panned far enough up or down)
- (BOOL)shouldDismissMessageWithPanGestureOffset:(double)offset withVelocity:(double)velocity {
    
    // For Centered notifications, only true if the user was swiping
    // in the same direction as the dismissal
    BOOL dismissDirection = (offset > 0 && velocity <= 0) || (offset < 0 && velocity >= 0);
    
    switch (self.message.position) {
        case OSInAppMessageDisplayPositionTop:
            return (offset > self.messageView.bounds.size.height / 2.0f);
        case OSInAppMessageDisplayPositionCentered:
            return dismissDirection && ((fabs(offset) > self.messageView.bounds.size.height / 2.0f) || (fabs(offset) > 100));
        case OSInAppMessageDisplayPositionBottom:
            return (fabs(offset) > self.messageView.bounds.size.height / 2.0f) && offset < 0;
    }
}

#pragma mark OSInAppMessageViewDelegate Methods
// The message view is not displayed until content is fully loaded
-(void)messageViewDidLoadMessageContent {
    [self displayMessage];
}

-(void)messageViewFailedToLoadMessageContent {
    [self.delegate messageViewControllerWasDismissed];
}

// This delegate function gets called when an action button is tapped on the IAM
- (void)messageViewActionOccurredWithBody:(NSData *)body {
    let action = [OSInAppMessageAction instanceWithData:body];
    
    if (action)
        [self.delegate messageViewDidSelectAction:action withMessageId:self.message.messageId];
    
    if (action.urlActionType == OSInAppMessageActionUrlTypeReplaceContent)
        [self.messageView loadReplacementURL:action.actionUrl];
    else if (action.close)
        [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop withVelocity:0.0f];
}

- (void)messageViewDidFailToProcessAction {
    [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop withVelocity:0.0f];
}

@end
