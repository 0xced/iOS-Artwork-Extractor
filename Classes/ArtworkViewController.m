//
//  ArtworkViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkViewController.h"
#import "AppDelegate.h"

#import <mach-o/dyld.h>
#import <mach-o/nlist.h>

extern UIImage *_UIImageWithName(NSString *);

@implementation ArtworkViewController

@synthesize imageView;
@synthesize pickerView;
@synthesize progressView;
@synthesize saveButton;
@synthesize saveAllButton;
@synthesize images;
@synthesize imageNames;
@synthesize saveCounter;

- (NSDictionary*) UIKitImages
{
	NSMutableDictionary *mappedImages = nil;

	for(uint32_t i = 0; i < _dyld_image_count(); i++)
	{
		if (strstr(_dyld_get_image_name(i), "UIKit.framework"))
		{
			struct nlist symlist[] = {{"___mappedImages", 0, 0, 0, 0}, NULL};
			if (nlist(_dyld_get_image_name(i), symlist) == 0 && symlist[0].n_value != 0)
				mappedImages = (NSMutableDictionary*)*(int*)symlist[0].n_value;
			break;
		}
	}

	return mappedImages;
}

- (void) viewDidLoad
{
	self.images = [self UIKitImages];
	self.imageNames = [[self.images allKeys] sortedArrayUsingSelector:@selector(compare:)];
	if ([self.images count] > 0)
	{
		NSString *defaultImageName = @"UITabBarFavoritesSelected.png";
		NSInteger row = [self.imageNames indexOfObject:defaultImageName];
		if (row >= 0)
		{
			[self.pickerView selectRow:row inComponent:0 animated:NO];
			self.imageView.image = _UIImageWithName(defaultImageName);
		}
	}
	else
	{
		saveButton.enabled = NO;
		saveAllButton.enabled = NO;
	}
}

- (void) viewDidUnload
{
	self.imageView = nil;
	self.pickerView = nil;
	self.progressView = nil;
	self.saveButton = nil;
	self.saveAllButton = nil;
	self.images = nil;
	self.imageNames = nil;
}

- (void) saveImage:(NSString *)imageName
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	NSString *imagePath = [[appDelegate saveDirectory] stringByAppendingPathComponent:imageName];
	[UIImagePNGRepresentation(_UIImageWithName(imageName)) writeToFile:imagePath atomically:YES];
	[self performSelectorOnMainThread:@selector(incrementSaveCounter) withObject:nil waitUntilDone:YES];
    [pool drain];
}

- (IBAction) save
{
	NSInteger row = [self.pickerView selectedRowInComponent:0];
	if (row >= 0)
		[self saveImage:[self.imageNames objectAtIndex:row]];
}

- (IBAction) saveAll
{
	self.saveCounter = 0;
	self.progressView.hidden = NO;
	for (NSString *imageName in self.imageNames)
		[self performSelectorInBackground:@selector(saveImage:) withObject:imageName];
}

- (void) incrementSaveCounter
{
	self.saveCounter++;
	NSUInteger count = [self.imageNames count];
	if (self.saveCounter == count)
		self.progressView.hidden = YES;
	self.progressView.progress = ((CGFloat)self.saveCounter / (CGFloat)count);
}

// MARK: Picker View Data Source and Delegate

- (NSInteger) numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 1;
}

- (NSInteger) pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return MAX([self.images count], 1);
}

- (NSString *) pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	if ([self.images count] > 0)
		return [self.imageNames objectAtIndex:row];
	else
		return [NSString stringWithFormat:@"SDK %@ not yet supported", [UIDevice currentDevice].systemVersion];
}

- (void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	if ([self.images count] > 0)
		imageView.image = _UIImageWithName([self.imageNames objectAtIndex:row]);
	else
		imageView.image = nil;
}

@end
