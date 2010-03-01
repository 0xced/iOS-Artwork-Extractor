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
	IBOutlet UIButton *saveAllButton;

	NSDictionary *images;
	NSArray *cells;

	NSUInteger saveCounter;
}

@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIButton *saveAllButton;
@property (nonatomic, retain) NSDictionary *images;
@property (nonatomic, retain) NSArray *cells;
@property (nonatomic, assign) NSUInteger saveCounter;

- (IBAction) saveAll;

@end
