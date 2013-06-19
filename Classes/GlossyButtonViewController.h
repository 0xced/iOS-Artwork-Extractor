//
//  GlossyButtonViewController.h
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GlossyButtonViewController : UIViewController
{
	IBOutlet UITextField *titleTextField;
	IBOutlet UISlider *fontSizeSlider;
	IBOutlet UILabel *fontSizeLabel;
	IBOutlet UISlider *widthSlider;
	IBOutlet UILabel *widthLabel;
	IBOutlet UISlider *heightSlider;
	IBOutlet UILabel *heightLabel;
	IBOutlet UISlider *redSlider;
	IBOutlet UILabel *redLabel;
	IBOutlet UISlider *greenSlider;
	IBOutlet UILabel *greenLabel;
	IBOutlet UISlider *blueSlider;
	IBOutlet UILabel *blueLabel;
	IBOutlet UISlider *alphaSlider;
	IBOutlet UILabel *alphaLabel;

	UIButton *glossyButton;
}

@property (nonatomic, retain) IBOutlet UITextField *titleTextField;
@property (nonatomic, retain) IBOutlet UISlider *fontSizeSlider;
@property (nonatomic, retain) IBOutlet UILabel *fontSizeLabel;
@property (nonatomic, retain) IBOutlet UISlider *widthSlider;
@property (nonatomic, retain) IBOutlet UILabel *widthLabel;
@property (nonatomic, retain) IBOutlet UISlider *heightSlider;
@property (nonatomic, retain) IBOutlet UILabel *heightLabel;
@property (nonatomic, retain) IBOutlet UISlider *redSlider;
@property (nonatomic, retain) IBOutlet UILabel *redLabel;
@property (nonatomic, retain) IBOutlet UISlider *greenSlider;
@property (nonatomic, retain) IBOutlet UILabel *greenLabel;
@property (nonatomic, retain) IBOutlet UISlider *blueSlider;
@property (nonatomic, retain) IBOutlet UILabel *blueLabel;
@property (nonatomic, retain) IBOutlet UISlider *alphaSlider;
@property (nonatomic, retain) IBOutlet UILabel *alphaLabel;

@property (nonatomic, retain) UIButton *glossyButton;

- (IBAction) changeColor:(UISlider *)slider;
- (IBAction) changeSize:(UISlider *)slider;
- (IBAction) changeFontSize:(UISlider *)slider;

@end
