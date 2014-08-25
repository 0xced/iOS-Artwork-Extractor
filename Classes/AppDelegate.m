//
//  AppDelegate.m
//  iOS Artwork Extractor
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
	
	NSString *mobileApplicationsPath = NSProcessInfo.processInfo.environment[@"MOBILE_APPLICATIONS_DIRECTORY"];
	if (!mobileApplicationsPath)
	{
		NSString *homeDirectory = [self homeDirectory];
		for (NSString *path in @[ @"Music/iTunes/Mobile Applications", @"Music/iTunes/iTunes Media/Mobile Applications" ])
		{
			NSString *fullPath = [homeDirectory stringByAppendingPathComponent:path];
			if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath])
				mobileApplicationsPath = fullPath;
		}
	}
	if (!mobileApplicationsPath)
		NSLog(@"'Mobile Applications' directory not found.");
	
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
	
	if (!NSClassFromString(@"UIGlassButton"))
	{
		NSLog(@"The UIGlassButton class is not available, use the iOS 5.0 simulator to generate glossy buttons.");
		NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.tabBarController.viewControllers];
		[viewControllers removeLastObject];
		self.tabBarController.viewControllers = viewControllers;
	}
	
	if ([self.window respondsToSelector:@selector(setRootViewController:)])
		self.window.rootViewController = self.tabBarController;
	else
		[self.window addSubview:self.tabBarController.view];
}

- (NSString *) homeDirectory
{
	for (NSString *simulatorHostHomeVariable in @[ @"IPHONE_SIMULATOR_HOST_HOME", @"SIMULATOR_HOST_HOME" ])
	{
		char *simulatorHostHome = getenv([simulatorHostHomeVariable UTF8String]);
		if (simulatorHostHome)
			return @(simulatorHostHome);
	}
	
	char *lognameEnv = getenv("LOGNAME");
	if (lognameEnv)
	{
		struct passwd *pw = getpwnam(lognameEnv);
		return pw ? [NSString stringWithCString:pw->pw_dir encoding:NSUTF8StringEncoding] : [@"/Users" stringByAppendingPathComponent:@(lognameEnv)];
	}
	else
	{
		return @"/Users/Shared";
	}
}

- (NSString *) saveDirectory:(NSString *)subDirectory
{
	NSString *saveDirectory = NSProcessInfo.processInfo.environment[@"ARTWORK_DIRECTORY"];
	
	if (!saveDirectory)
	{
#if TARGET_IPHONE_SIMULATOR
		saveDirectory = [NSString stringWithFormat:@"%@/Desktop/%@ %@ artwork", [self homeDirectory], [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion];
#else
		saveDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#endif
	}
	if (subDirectory)
		saveDirectory = [saveDirectory stringByAppendingPathComponent:subDirectory];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:saveDirectory])
	{
		NSError *error = nil;
		BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:saveDirectory withIntermediateDirectories:YES attributes:nil error:&error];
		if (!created)
			NSLog(@"%@\n%@", error, error.userInfo);
	}
	
	return saveDirectory;
}

@end
