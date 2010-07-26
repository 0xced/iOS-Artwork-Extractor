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

@synthesize saveButton;
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
	self.image = nil;
	self.name = nil;
	[super dealloc];
}

- (void) viewWillAppear:(BOOL)animated
{
	((UIImageView*)self.view).image = self.image;
	self.title = [self.name stringByDeletingPathExtension];
}

- (void) viewDidAppear:(BOOL)animated
{
	self.navigationController.navigationBar.topItem.rightBarButtonItem = self.saveButton;
}

- (IBAction) save
{
	id artworkViewController = [self.navigationController.viewControllers objectAtIndex:0];
	[artworkViewController performSelector:@selector(saveImage:) withObject:self.name];
}

@end
