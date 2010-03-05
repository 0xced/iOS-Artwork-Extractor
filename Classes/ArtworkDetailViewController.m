//
//  ArtworkDetailViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 05.03.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkDetailViewController.h"

@implementation ArtworkDetailViewController

@synthesize saveButton;
@synthesize imageName;

- (void) viewWillAppear:(BOOL)animated
{
	self.title = [self.imageName stringByDeletingPathExtension];
	((UIImageView*)self.view).image = _UIImageWithName(self.imageName);
}

- (void) viewDidAppear:(BOOL)animated
{
	self.navigationController.navigationBar.topItem.rightBarButtonItem = self.saveButton;
}

- (IBAction) save
{
	id artworkViewController = [self.navigationController.viewControllers objectAtIndex:0];
	[artworkViewController performSelector:@selector(saveImage:) withObject:self.imageName];
}

@end
