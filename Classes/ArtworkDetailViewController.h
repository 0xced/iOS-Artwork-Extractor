//
//  ArtworkDetailViewController.h
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 05.03.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ArtworkDetailViewController : UITableViewController
{
	IBOutlet UIBarButtonItem *saveButton;

	NSString *imageName;
}

@property (nonatomic, retain) IBOutlet UIBarButtonItem *saveButton;
@property (nonatomic, retain) NSString *imageName;

- (IBAction) save;

@end
