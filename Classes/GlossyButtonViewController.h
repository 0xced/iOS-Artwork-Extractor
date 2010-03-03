//
//  GlossyButtonViewController.h
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GlossyButtonViewController : UIViewController
{
	IBOutlet UISlider *redSlider;
	IBOutlet UISlider *greenSlider;
	IBOutlet UISlider *blueSlider;
	IBOutlet UISlider *alphaSlider;
	IBOutlet UISlider *widthSlider;
	IBOutlet UISlider *heightSlider;
	IBOutlet UITextField *titleTextField;

	UIButton *glossyButton;
}

@property (nonatomic, retain) IBOutlet UISlider *redSlider;
@property (nonatomic, retain) IBOutlet UISlider *greenSlider;
@property (nonatomic, retain) IBOutlet UISlider *blueSlider;
@property (nonatomic, retain) IBOutlet UISlider *alphaSlider;
@property (nonatomic, retain) IBOutlet UISlider *widthSlider;
@property (nonatomic, retain) IBOutlet UISlider *heightSlider;
@property (nonatomic, retain) IBOutlet UITextField *titleTextField;

@property (nonatomic, retain) UIButton *glossyButton;

- (IBAction) changeColor:(UISlider *)slider;
- (IBAction) changeSize:(UISlider *)slider;

@end
