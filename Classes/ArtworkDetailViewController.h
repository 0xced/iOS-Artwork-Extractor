//
//  ArtworkDetailViewController.h
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 05.03.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ArtworkDetailViewController : UIViewController
{
	IBOutlet UIBarButtonItem *saveButton;

	UIImage *image;
	NSString *name;
}

- (id) initWithImage:(UIImage *)anImage name:(NSString *)aName;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *saveButton;

- (IBAction) save;

@end
