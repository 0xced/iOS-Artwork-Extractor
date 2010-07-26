//
//  ArtworkViewController.h
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ArtworkViewController : UITableViewController
{
	IBOutlet UIProgressView *progressView;
	IBOutlet UIBarButtonItem *saveAllButton;

	NSMutableDictionary *images;
	NSArray *cells;

	NSIndexPath *firstCellIndexPath;

	NSUInteger saveCounter;
}

@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *saveAllButton;
@property (nonatomic, readonly) NSDictionary *images;
@property (nonatomic, retain) NSArray *cells;
@property (nonatomic, retain) NSIndexPath *firstCellIndexPath;
@property (nonatomic, assign) NSUInteger saveCounter;

- (IBAction) saveAll;

@end
