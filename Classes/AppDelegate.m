//
//  AppDelegate.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window;
@synthesize tabBarController;

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
    [self.window addSubview:self.tabBarController.view];
}

- (NSString *) saveDirectory
{
	NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(id)kCFBundleNameKey];
	NSString *saveDirectory = [NSString stringWithFormat:@"/Users/%s/Desktop/%@-%@", getenv("LOGNAME"), appName, [UIDevice currentDevice].systemVersion];
	if (![[NSFileManager defaultManager] fileExistsAtPath:saveDirectory])
		[[NSFileManager defaultManager] createDirectoryAtPath:saveDirectory withIntermediateDirectories:NO attributes:nil error:NULL];

	return saveDirectory;
}

@end
