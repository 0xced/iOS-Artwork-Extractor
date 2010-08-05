//
//  ArtworkDetailViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 05.03.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkDetailViewController.h"


@interface ArtworkDetailViewController ()
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) NSString *name;
@end


@implementation ArtworkDetailViewController

@synthesize saveButton, imageView;
@synthesize image;
@synthesize name;

- (id) initWithImage:(UIImage *)anImage name:(NSString *)aName
{
	if (!(self = [super initWithNibName:@"ArtworkDetailViewController" bundle:nil]))
		return nil;
	
	self.image = anImage;
	self.name = aName;
	
	return self;
}

- (void) dealloc
{
	self.saveButton = nil;
	self.imageView = nil;
	self.image = nil;
	self.name = nil;
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated
{
	self.title = [self.name stringByDeletingPathExtension];

	self.imageView.image = self.image;
	[self.imageView sizeToFit];
	self.imageView.center = CGPointMake(roundf(self.view.center.x), roundf(self.view.center.y));
}

- (void) viewDidAppear:(BOOL)animated
{	
	self.navigationController.navigationBar.topItem.rightBarButtonItem = self.saveButton;
}

- (IBAction) save
{
	id artworkViewController = [self.navigationController.viewControllers objectAtIndex:0];
	NSDictionary *imageInfo = [NSDictionary dictionaryWithObjectsAndKeys:self.image, @"image", self.name, @"name", nil];
	[artworkViewController performSelector:@selector(saveImage:) withObject:imageInfo];
}

@end
