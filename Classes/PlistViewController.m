//
//  PlistViewController.m
//  UIKit Artwork Extractor
//
//  Created by Ortwin Gentz on 01.10.12.
//  Copyright (c) 2012 Cédric Luthi. All rights reserved.
//

#import "PlistViewController.h"

@interface PlistViewController ()

@end

@implementation PlistViewController

- (void)viewWillAppear:(BOOL)animated {
	self.plistTextView.text = self.plistString;
}
@end
