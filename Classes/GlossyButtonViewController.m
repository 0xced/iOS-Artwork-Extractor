//
//  FirstViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "GlossyButtonViewController.h"
#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>

@implementation GlossyButtonViewController

@synthesize redSlider;
@synthesize greenSlider;
@synthesize blueSlider;
@synthesize alphaSlider;
@synthesize widthSlider;
@synthesize heightSlider;
@synthesize glossyButton;

- (void) viewDidLoad
{
	self.redSlider.value = 0.25f;
	self.greenSlider.value = 0.5f;
	self.blueSlider.value = 0.75f;
	self.alphaSlider.value = 1.0f;

	self.widthSlider.value = 120;
	self.heightSlider.value = 44;

	self.glossyButton = [[[NSClassFromString(@"UIGlassButton") alloc] initWithFrame:CGRectZero] autorelease];
	[self.glossyButton setTitle:@"Save" forState:UIControlStateNormal];
	[self.glossyButton addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
	[self changeColor:nil];
	[self changeSize:nil];

	[self.view addSubview:self.glossyButton];
}

- (void) viewDidUnload
{
	self.redSlider = nil;
	self.greenSlider = nil;
	self.blueSlider = nil;
	self.alphaSlider = nil;
	self.widthSlider = nil;
	self.heightSlider = nil;
	self.glossyButton = nil;
}

- (IBAction) changeColor:(UISlider *)slider
{
	[self.glossyButton setValue:[UIColor colorWithRed:self.redSlider.value green:self.greenSlider.value blue:self.blueSlider.value alpha:self.alphaSlider.value] forKey:@"tintColor"];
}

- (IBAction) changeSize:(UISlider *)slider
{
	self.glossyButton.frame = CGRectMake((320 - self.widthSlider.value) / 2.0f, CGRectGetMaxY(self.heightSlider.frame) + 50, self.widthSlider.value, self.heightSlider.value);
}

- (void) saveButtonInState:(UIControlState)state
{
	NSString *buttonTitle = [self.glossyButton titleForState:UIControlStateNormal];
	[self.glossyButton setTitle:nil forState:UIControlStateNormal];

	UIGraphicsBeginImageContext(self.glossyButton.frame.size);

	NSString *buttonName = nil;

	switch (state)
	{
		case UIControlStateNormal:
			self.glossyButton.highlighted = NO;
			self.glossyButton.enabled = YES;
			buttonName = @"glossyButton-normal.png";
			break;
		case UIControlStateHighlighted:
			self.glossyButton.highlighted = YES;
			self.glossyButton.enabled = YES;
			buttonName = @"glossyButton-highlighted.png";
			break;
		case UIControlStateDisabled:
			self.glossyButton.highlighted = NO;
			self.glossyButton.enabled = NO;
			buttonName = @"glossyButton-disabled.png";
			break;
	}

	CGContextRef theContext = UIGraphicsGetCurrentContext();
	[self.glossyButton.layer renderInContext:theContext];

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	NSData *data = UIImagePNGRepresentation(image);
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	[data writeToFile:[[appDelegate saveDirectory] stringByAppendingPathComponent:buttonName] atomically:YES];

	UIGraphicsEndImageContext();

	[self.glossyButton setTitle:buttonTitle forState:UIControlStateNormal];
}

- (IBAction) save
{
	[self saveButtonInState:UIControlStateDisabled];
	[self saveButtonInState:UIControlStateHighlighted];
	[self saveButtonInState:UIControlStateNormal];
}

@end
