//
//  ArtworkViewController.h
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ArtworkViewController : UIViewController
{
	IBOutlet UIImageView *imageView;
	IBOutlet UIPickerView *pickerView;
	IBOutlet UIProgressView *progressView;
	IBOutlet UIButton *saveButton;
	IBOutlet UIButton *saveAllButton;

	NSDictionary *images;
	NSArray *imageNames;

	NSUInteger saveCounter;
}

@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UIPickerView *pickerView;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIButton *saveButton;
@property (nonatomic, retain) IBOutlet UIButton *saveAllButton;
@property (nonatomic, retain) NSDictionary *images;
@property (nonatomic, retain) NSArray *imageNames;
@property (nonatomic, assign) NSUInteger saveCounter;

- (IBAction) save;
- (IBAction) saveAll;

@end
