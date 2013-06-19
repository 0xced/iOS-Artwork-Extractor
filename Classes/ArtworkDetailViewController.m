//
//  ArtworkDetailViewController.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 05.03.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkDetailViewController.h"


@interface ArtworkDetailViewController ()
@property (nonatomic, retain) NSDictionary *imageInfo;
@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) NSString *name;
@end


@implementation ArtworkDetailViewController

@synthesize saveButton, imageView;
@synthesize imageInfo;

- (id) initWithImageInfo:(NSDictionary *)anImageInfo
{
	if (!(self = [super initWithNibName:@"ArtworkDetailViewController" bundle:nil]))
		return nil;
	
	self.imageInfo = anImageInfo;
	
	return self;
}

- (void) dealloc
{
	self.saveButton = nil;
	self.imageView = nil;
	self.imageInfo = nil;
	[super dealloc];
}

- (UIImage *) image
{
	return [self.imageInfo objectForKey:@"image"];
}

- (NSString *) name
{
	return [self.imageInfo objectForKey:@"name"];
}

- (void) viewWillAppear:(BOOL)animated
{
	self.title = [self.name stringByDeletingPathExtension];

	self.imageView.image = self.image;
	[self.imageView sizeToFit];
	CGFloat posX = roundf((CGRectGetWidth(self.view.frame) - CGRectGetWidth(self.imageView.frame)) / 2.0f);
	CGFloat posY = roundf((CGRectGetHeight(self.view.frame) - CGRectGetHeight(self.imageView.frame)) / 2.0f);
	self.imageView.frame = CGRectMake(posX, posY, CGRectGetWidth(self.imageView.frame), CGRectGetHeight(self.imageView.frame));

	[self.navigationItem setRightBarButtonItem:self.saveButton animated:animated];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	static UIColor *originalColor = nil;
	if (originalColor == nil)
		originalColor = [self.view.backgroundColor retain];
	
	if ([self.view.backgroundColor isEqual:originalColor])
		self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Checkerboard.png"]];
	else
		self.view.backgroundColor = originalColor;
}

- (IBAction) save
{
	NSUInteger artworkViewControllerIndex = [self.navigationController.viewControllers count] - 2;
	id artworkViewController = [self.navigationController.viewControllers objectAtIndex:artworkViewControllerIndex];
	[artworkViewController performSelector:@selector(saveImage:) withObject:imageInfo];
}

@end
