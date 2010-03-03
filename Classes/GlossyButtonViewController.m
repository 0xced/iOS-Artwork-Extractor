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

@synthesize titleTextField;
@synthesize widthSlider, widthLabel;
@synthesize heightSlider, heightLabel;
@synthesize redSlider, redLabel;
@synthesize greenSlider, greenLabel;
@synthesize blueSlider, blueLabel;
@synthesize alphaSlider, alphaLabel;
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
	[self.glossyButton setTitle:self.titleTextField.text forState:UIControlStateNormal];
	[self.glossyButton addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
	[self changeColor:nil];
	[self changeSize:nil];

	[self.view addSubview:self.glossyButton];
}

- (void) viewDidUnload
{
	self.titleTextField = nil;
	self.widthSlider = nil;
	self.widthLabel = nil;
	self.heightSlider = nil;
	self.heightLabel = nil;
	self.redSlider = nil;
	self.redLabel = nil;
	self.greenSlider = nil;
	self.greenLabel = nil;
	self.blueSlider = nil;
	self.blueLabel = nil;
	self.alphaSlider = nil;
	self.alphaLabel = nil;
	self.glossyButton = nil;
}

- (IBAction) changeColor:(UISlider *)slider
{
	CGFloat red = self.redSlider.value;
	CGFloat green = self.greenSlider.value;
	CGFloat blue = self.blueSlider.value;
	CGFloat alpha = self.alphaSlider.value;

	[self.glossyButton setValue:[UIColor colorWithRed:red green:green blue:blue alpha:alpha] forKey:@"tintColor"];

	self.redLabel.text   = [NSString stringWithFormat:@"%1$ld / #%1$02lX", lroundf(red * 255)];
	self.greenLabel.text = [NSString stringWithFormat:@"%1$ld / #%1$02lX", lroundf(green * 255)];
	self.blueLabel.text  = [NSString stringWithFormat:@"%1$ld / #%1$02lX", lroundf(blue * 255)];
	self.alphaLabel.text = [NSString stringWithFormat:@"%1$ld / #%1$02lX", lroundf(alpha * 255)];
}

- (IBAction) changeSize:(UISlider *)slider
{
	CGFloat width = roundf(self.widthSlider.value);
	CGFloat height = roundf(self.heightSlider.value);

	self.glossyButton.frame = CGRectMake((320 - self.widthSlider.value) / 2.0f, 30, width, height);

	self.widthLabel.text  = [NSString stringWithFormat:@"%g", width];
	self.heightLabel.text = [NSString stringWithFormat:@"%g", height];
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

// MARK: Text Field Delegate

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	NSMutableString *fullString = [NSMutableString stringWithString:titleTextField.text];
	[fullString replaceCharactersInRange:range withString:string];

	[self.glossyButton setTitle:[fullString copy] forState:UIControlStateNormal];

	return YES;
}

- (BOOL) textFieldShouldClear:(UITextField *)textField
{
	[self.glossyButton setTitle:nil forState:UIControlStateNormal];

	return YES;
}

- (void) textFieldDidEndEditing:(UITextField *)textField
{
	[self.glossyButton setTitle:textField.text forState:UIControlStateNormal];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
	return [self.view endEditing:YES];
}

@end
