//
//  FirstViewController.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "GlossyButtonViewController.h"
#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>
#import "FindSymbol.h"
#import <mach-o/dyld.h>
#import <dlfcn.h>

@implementation GlossyButtonViewController

static UIImage*(*GetTintedGlassButtonImage)(UIColor*, UIControlState) = NULL;

@synthesize titleTextField;
@synthesize fontSizeSlider, fontSizeLabel;
@synthesize widthSlider, widthLabel;
@synthesize heightSlider, heightLabel;
@synthesize redSlider, redLabel;
@synthesize greenSlider, greenLabel;
@synthesize blueSlider, blueLabel;
@synthesize alphaSlider, alphaLabel;
@synthesize glossyButton;

+ (void) initialize
{
	if (self != [GlossyButtonViewController class])
		return;
	
	for(uint32_t i = 0; i < _dyld_image_count(); i++)
	{
		if (strstr(_dyld_get_image_name(i), "UIKit.framework"))
		{
			struct mach_header* header = (struct mach_header*)_dyld_get_image_header(i);
			GetTintedGlassButtonImage = FindSymbol(header, "_GetTintedGlassButtonImage");
			
			NSMutableDictionary **__images = FindSymbol(header, "___images");
			if (__images && [[UIScreen mainScreen] scale] > 1)
			{
				for (NSString *glassButtonImageName in [NSArray arrayWithObjects:/*@"UITintedGlassButtonGradient.png",*/ @"UITintedGlassButtonHighlight.png", @"UITintedGlassButtonMask.png", @"UITintedGlassButtonShadow.png", nil])
					[*__images setObject:[UIImage imageNamed:glassButtonImageName] forKey:glassButtonImageName];
			}
			break;
		}
	}
}

- (void) sizeToFit
{
	CGSize fitSize = [self.glossyButton sizeThatFits:self.glossyButton.bounds.size];
	if ((int)fitSize.width % 2 == 1)
		fitSize.width++;
	self.widthSlider.value = fitSize.width;
	self.heightSlider.value = fitSize.height;
	[self.glossyButton sizeToFit];

	[self changeSize:nil];
}

- (void) viewDidLoad
{
	self.redSlider.value = 0.25f;
	self.greenSlider.value = 0.5f;
	self.blueSlider.value = 0.75f;
	self.alphaSlider.value = 1.0f;

	self.glossyButton = [[[NSClassFromString(@"UIGlassButton") alloc] initWithFrame:CGRectZero] autorelease];
	[self.glossyButton setTitle:self.titleTextField.text forState:UIControlStateNormal];
	[self.glossyButton addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];

	self.fontSizeSlider.value = self.glossyButton.titleLabel.font.pointSize;

	[self changeColor:nil];
	[self sizeToFit];
	[self changeFontSize:nil];

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

	NSString *colorFormat = @"%1$ld\n#%1$02lX";
	self.redLabel.text   = [NSString stringWithFormat:colorFormat, lroundf(red * 255)];
	self.greenLabel.text = [NSString stringWithFormat:colorFormat, lroundf(green * 255)];
	self.blueLabel.text  = [NSString stringWithFormat:colorFormat, lroundf(blue * 255)];
	self.alphaLabel.text = [NSString stringWithFormat:colorFormat, lroundf(alpha * 255)];
}

- (IBAction) changeSize:(UISlider *)slider
{
	CGFloat width = roundf(self.widthSlider.value);
	CGFloat height = roundf(self.heightSlider.value);

	self.glossyButton.frame = CGRectMake((320 - self.widthSlider.value) / 2.0f, 20, width, height);

	self.widthLabel.text  = [NSString stringWithFormat:@"%g", width];
	self.heightLabel.text = [NSString stringWithFormat:@"%g", height];
}

- (IBAction) changeFontSize:(UISlider *)slider
{
	CGFloat fontSize = roundf(self.fontSizeSlider.value);
	UIFont *font = self.glossyButton.titleLabel.font;
	self.glossyButton.titleLabel.font = [UIFont fontWithName:font.fontName size:fontSize];
	self.fontSizeLabel.text = [NSString stringWithFormat:@"%g", fontSize];
}

- (void) saveButtonInState:(UIControlState)state scale:(CGFloat)scale
{
	if (!GetTintedGlassButtonImage)
	{
		NSLog(@"GetTintedGlassButtonImage function not found");
		return;
	}
	
	NSString *buttonName = @"glossyButton";
	NSString *xSuffix = scale > 1 ? [NSString stringWithFormat:@"@%gx", scale] : @"";
	switch (state)
	{
		case UIControlStateNormal:
			buttonName = [NSString stringWithFormat:@"glossyButton-normal%@.png", xSuffix];
			break;
		case UIControlStateHighlighted:
			buttonName = [NSString stringWithFormat:@"glossyButton-highlighted%@.png", xSuffix];
			break;
		case UIControlStateDisabled:
			buttonName = [NSString stringWithFormat:@"glossyButton-disabled%@.png", xSuffix];
			break;
		default:
			break;
	}
	
	// Use dlsym so that it still compiles with the 3.1.3 SDK, could aslo use #if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
	void (*UIGraphicsBeginImageContextWithOptions)(CGSize, BOOL, CGFloat) = dlsym(RTLD_DEFAULT, "UIGraphicsBeginImageContextWithOptions");
	if (UIGraphicsBeginImageContextWithOptions)
		UIGraphicsBeginImageContextWithOptions(self.glossyButton.frame.size, NO, scale);
	else
		UIGraphicsBeginImageContext(self.glossyButton.frame.size);
	
	UIImage *stretchableImage = GetTintedGlassButtonImage([self.glossyButton valueForKey:@"tintColor"], state);
	CGFloat alpha = state == UIControlStateDisabled ? 0.5 : 1.0;
	[stretchableImage drawInRect:self.glossyButton.bounds blendMode:kCGBlendModeNormal alpha:alpha];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	NSData *data = UIImagePNGRepresentation(image);
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	[data writeToFile:[[appDelegate saveDirectory:@"UIGlassButton"] stringByAppendingPathComponent:buttonName] atomically:YES];
	
	UIGraphicsEndImageContext();
}

- (IBAction) save
{
	[self saveButtonInState:UIControlStateDisabled scale:1];
	[self saveButtonInState:UIControlStateHighlighted scale:1];
	[self saveButtonInState:UIControlStateNormal scale:1];
	
	CGFloat scale = [[UIScreen mainScreen] scale];
	if (scale > 1)
	{
		[self saveButtonInState:UIControlStateDisabled scale:scale];
		[self saveButtonInState:UIControlStateHighlighted scale:scale];
		[self saveButtonInState:UIControlStateNormal scale:scale];
	}
}

// MARK: Text Field Delegate

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	NSMutableString *fullString = [NSMutableString stringWithString:titleTextField.text];
	[fullString replaceCharactersInRange:range withString:string];

	[self.glossyButton setTitle:[[fullString copy] autorelease] forState:UIControlStateNormal];

	[self sizeToFit];

	return YES;
}

- (BOOL) textFieldShouldClear:(UITextField *)textField
{
	[self.glossyButton setTitle:nil forState:UIControlStateNormal];

	return YES;
}

- (void) textFieldDidEndEditing:(UITextField *)textField
{
	[self.glossyButton setTitle:[[textField.text copy] autorelease] forState:UIControlStateNormal];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
	return [self.view endEditing:YES];
}

@end
