//
//  ArtworkViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkViewController.h"
#import "AppDelegate.h"

#import <mach-o/dyld.h>
#import <mach-o/nlist.h>

extern UIImage *_UIImageWithName(NSString *);

@implementation ArtworkViewController

@synthesize progressView;
@synthesize saveAllButton;
@synthesize images;
@synthesize cells;
@synthesize saveCounter;

- (NSDictionary*) UIKitImages
{
	NSMutableDictionary *mappedImages = nil;

	for(uint32_t i = 0; i < _dyld_image_count(); i++)
	{
		if (strstr(_dyld_get_image_name(i), "UIKit.framework"))
		{
			struct nlist symlist[] = {{"___mappedImages", 0, 0, 0, 0}, NULL};
			if (nlist(_dyld_get_image_name(i), symlist) == 0 && symlist[0].n_value != 0)
				mappedImages = (NSMutableDictionary*)*(id*)(symlist[0].n_value + _dyld_get_image_vmaddr_slide(i));
			break;
		}
	}

	return mappedImages;
}

- (void) viewDidLoad
{
	self.progressView.frame = CGRectMake(10, 17, 90, 11);
	self.progressView.hidden = YES;
	[self.navigationController.navigationBar addSubview:self.progressView];

	self.images = [self UIKitImages];

	NSMutableArray *imageCells = [NSMutableArray arrayWithCapacity:[self.images count]];

	for (NSString *imageName in [[self.images allKeys] sortedArrayUsingSelector:@selector(compare:)])
	{
		UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ImageCell"] autorelease];
		cell.textLabel.text = imageName;
		cell.textLabel.font = [UIFont systemFontOfSize:12];
		UIImage *image = _UIImageWithName(imageName);
		UIImageView *imageView = [[[UIImageView alloc] initWithImage:image] autorelease];
		CGFloat size = CGRectGetHeight(cell.frame) - 4;
		imageView.frame = CGRectMake(imageView.frame.origin.x, imageView.frame.origin.y, size, size);
		if (image.size.height > size || image.size.width > size)
			imageView.contentMode = UIViewContentModeScaleAspectFit;
		else
			imageView.contentMode = UIViewContentModeCenter;
		cell.accessoryView = imageView;
		[imageCells addObject:cell];
	}

	self.cells = [NSArray arrayWithArray:imageCells];
}

- (void) viewDidUnload
{
	self.progressView = nil;
	self.saveAllButton = nil;
	self.images = nil;
	self.cells = nil;
}

- (void) saveImage:(NSString *)imageName
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	NSString *imagePath = [[appDelegate saveDirectory] stringByAppendingPathComponent:imageName];
	[UIImagePNGRepresentation(_UIImageWithName(imageName)) writeToFile:imagePath atomically:YES];
	[self performSelectorOnMainThread:@selector(incrementSaveCounter) withObject:nil waitUntilDone:YES];
    [pool drain];
}

- (IBAction) saveAll
{
	self.saveCounter = 0;
	self.progressView.hidden = NO;
	for (UITableViewCell *cell in self.cells)
		[self performSelectorInBackground:@selector(saveImage:) withObject:cell.textLabel.text];
}

- (void) incrementSaveCounter
{
	self.saveCounter++;
	NSUInteger count = [self.images count];
	if (self.saveCounter == count)
		self.progressView.hidden = YES;
	self.progressView.progress = ((CGFloat)self.saveCounter / (CGFloat)count);
}

// MARK: Table View Data Source

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.cells count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [self.cells objectAtIndex:indexPath.row];
}

// MARK: Table View Delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	[self saveImage:cell.textLabel.text];

	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
