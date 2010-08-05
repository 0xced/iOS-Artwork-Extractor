//
//  main.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

CGFloat UIScreen_scale(id self, SEL _cmd)
{
	return 1.0;
}

int main(int argc, char *argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	// -[UIView alpha] has the same method signature as -[UIScreen scale]
	Method alpha = class_getInstanceMethod([UIView class], @selector(alpha));
	if (![UIScreen instancesRespondToSelector:@selector(scale)])
		class_addMethod([UIScreen class], @selector(scale), (IMP)UIScreen_scale, method_getTypeEncoding(alpha));

	int retVal = UIApplicationMain(argc, argv, nil, nil);
	[pool release];
	return retVal;
}
