//
//  PlistViewController.h
//  UIKit Artwork Extractor
//
//  Created by Ortwin Gentz on 01.10.12.
//  Copyright (c) 2012 Cédric Luthi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PlistViewController : UIViewController
@property (nonatomic, retain) NSString *plistString;
@property (nonatomic, retain) IBOutlet UITextView *plistTextView;
@end
