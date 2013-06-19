//
//  ArtworkDetailViewController.h
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 05.03.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ArtworkDetailViewController : UIViewController
{
	IBOutlet UIBarButtonItem *saveButton;
	IBOutlet UIImageView *imageView;

	NSDictionary *imageInfo;
}

- (id) initWithImageInfo:(NSDictionary *)anImageInfo;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *saveButton;
@property (nonatomic, retain) IBOutlet UIImageView *imageView;

- (IBAction) save;

@end
