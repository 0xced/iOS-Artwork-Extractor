//
//  IPAViewController.h
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 30.12.11.
//  Copyright (c) 2011 Cédric Luthi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IPAViewController : UITableViewController

@property (nonatomic, retain) IBOutlet UIView *archiveLoadingView;
@property (nonatomic, retain) IBOutlet UILabel *appNameLabel;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;

@end
