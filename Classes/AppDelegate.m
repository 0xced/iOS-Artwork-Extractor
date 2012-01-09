//
//  AppDelegate.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "AppDelegate.h"

#import <pwd.h>
#import "IPAViewController.h"

@implementation AppDelegate

@synthesize window;
@synthesize tabBarController;

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
	self.window.frame = [[UIScreen mainScreen] bounds];
	
	NSString *mobileApplicationsPath = [[self homeDirectory] stringByAppendingPathComponent:@"/Music/iTunes/Mobile Applications"];
	NSArray *mobileApplications = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mobileApplicationsPath error:NULL];
	NSMutableArray *archives = [NSMutableArray array];
	for (NSString *ipaFile in mobileApplications)
	{
		NSString *ipaPath = [mobileApplicationsPath stringByAppendingPathComponent:ipaFile];
		[archives addObject:ipaPath];
	}
	
	NSUInteger ipaViewControllerIndex = 2;
	if ([archives count] == 0)
	{
		NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.tabBarController.viewControllers];
		[viewControllers removeObjectAtIndex:ipaViewControllerIndex];
		self.tabBarController.viewControllers = viewControllers;
	}
	else
	{
		IPAViewController *ipaViewController = (IPAViewController *)[[self.tabBarController.viewControllers objectAtIndex:ipaViewControllerIndex] topViewController];
		ipaViewController.archives = archives;
	}
	
	if ([self.window respondsToSelector:@selector(setRootViewController:)])
		self.window.rootViewController = self.tabBarController;
	else
		[self.window addSubview:self.tabBarController.view];
}

- (NSString *) homeDirectory
{
	NSString *logname = [NSString stringWithCString:getenv("LOGNAME") encoding:NSUTF8StringEncoding];
	struct passwd *pw = getpwnam([logname UTF8String]);
	return pw ? [NSString stringWithCString:pw->pw_dir encoding:NSUTF8StringEncoding] : [@"/Users" stringByAppendingPathComponent:logname];
}

- (NSString *) saveDirectory:(NSString *)subDirectory
{
	NSString *saveDirectory = nil;
	
#if TARGET_IPHONE_SIMULATOR
	saveDirectory = [NSString stringWithFormat:@"%@/Desktop/%@ %@ artwork", [self homeDirectory], [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion];
#else
	saveDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#endif
	if (subDirectory)
		saveDirectory = [saveDirectory stringByAppendingPathComponent:subDirectory];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:saveDirectory])
		[[NSFileManager defaultManager] createDirectoryAtPath:saveDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
	
	return saveDirectory;
}

@end
