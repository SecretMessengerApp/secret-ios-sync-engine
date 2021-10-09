// 


#import "TestHostAppDelegate.h"

@implementation TestHostAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    (void) application;
    (void) launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor redColor];
    [self.window makeKeyAndVisible];
    UIViewController *vc = [[UIViewController alloc] init];
    
    UITextView *textView = [[UITextView alloc] init];
    textView.text = @"This is the test host application for WireSyncEngine tests.";
    [vc.view addSubview:textView];
    textView.backgroundColor = [UIColor greenColor];
    textView.textContainerInset = UIEdgeInsetsMake(22, 22, 22, 22);
    textView.editable = NO;
    textView.frame = CGRectInset(vc.view.frame, 22, 44);
    
    self.window.rootViewController = vc;
    return YES;
}

@end
