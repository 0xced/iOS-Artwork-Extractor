//
//  EmojiImageView.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 09.03.12.
//  Copyright (c) 2012 Cédric Luthi. All rights reserved.
//

#import "EmojiImageView.h"

@interface EmojiImageView ()
@property (nonatomic, retain) id emoji;
@end

@implementation EmojiImageView

@synthesize emoji = _emoji;

- (id) initWithFrame:(CGRect)frame emoji:(id)emoji
{
	if (!(self = [super initWithFrame:frame]))
		return nil;
	
	self.backgroundColor = [UIColor clearColor];
	self.emoji = emoji;
	
	return self;
}

- (void) dealloc
{
	self.emoji = nil;
	[super dealloc];
}

- (void) drawRect:(CGRect)rect
{
	UIFont *emojiFont = [UIFont fontWithName:@"AppleColorEmoji" size:CGRectGetHeight(self.frame)];
	NSString *emojiString = [self.emoji valueForKey:@"emojiString"];
	[emojiString drawAtPoint:CGPointZero withFont:emojiFont];
}

- (UIImage *) image
{
	UIGraphicsBeginImageContextWithOptions(self.frame.size, NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	[self.layer renderInContext:context];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return image;
}

@end
