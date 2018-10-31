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

#import "OSInAppMessageView.h"
#import "OneSignalHelper.h"
#import <WebKit/WebKit.h>

@interface OSInAppMessageView ()
@property (strong, nonatomic, nonnull) OSInAppMessage *message;
@property (strong, nonatomic, nonnull) WKWebView *webView;
@property (nonatomic) BOOL loaded;
@end

@implementation OSInAppMessageView

- (instancetype _Nonnull)initWithMessage:(OSInAppMessage *)inAppMessage {
    if (self = [super init]) {
        self.message = inAppMessage;
        self.translatesAutoresizingMaskIntoConstraints = false;
        [self setupWebview];
        
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com"]]];
    }
    
    return self;
}

- (void)setupWebview {
    self.webView = [[WKWebView alloc] init];
    self.webView.translatesAutoresizingMaskIntoConstraints = false;
    self.webView.scrollView.scrollEnabled = false;
    self.webView.navigationDelegate = self;
    
    [self addSubview:self.webView];
    
    [self.webView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;
    [self.webView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = true;
    [self.webView.topAnchor constraintEqualToAnchor:self.topAnchor].active = true;
    [self.webView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = true;
    
    [self layoutIfNeeded];
}

#pragma mark WKWebViewNavigationDelegate Methods
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    //webview finished loading
    if (self.loaded)
        return;
    
    self.loaded = true;
    
    [self.delegate messageViewDidLoadMessageContent];
}

@end
