//
//  ArtworkViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkViewController.h"
#import "ArtworkDetailViewController.h"
#import "AppDelegate.h"

#import "APELite.h"
#import <mach-o/dyld.h>

#import <Availability.h>
#import <objc/runtime.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@interface UIScreen (iOS4)
@property(nonatomic,readonly) CGFloat scale;
@end
#endif

CGFloat UIScreen_scale(id self, SEL _cmd)
{
	return 1.0;
}

@implementation ArtworkViewController

@synthesize progressView;
@synthesize saveAllButton;
@synthesize cells;
@synthesize firstCellIndexPath;
@synthesize saveCounter;

+ (void) initialize
{
	Method alpha = class_getInstanceMethod([UIView class], @selector(alpha));
	if (![UIScreen instancesRespondToSelector:@selector(scale)])
		class_addMethod([UIScreen class], @selector(scale), (IMP)UIScreen_scale, method_getTypeEncoding(alpha));
}

- (BOOL) isEmoji
{
	return self.tableView.tag == 0xE770;
}

- (NSDictionary*) images
{
	if (images)
		return images;
	
	Class UIKeyboardEmojiImages = NSClassFromString(@"UIKeyboardEmojiImages"); // iOS 3 only
	[UIKeyboardEmojiImages performSelector:@selector(mapImagesIfNecessary)];
	
	Class UIKeyboardEmojiFactory = NSClassFromString(@"UIKeyboardEmojiFactory");
	id emojiFactory = [[[UIKeyboardEmojiFactory alloc] init] autorelease];
	NSDictionary *emojiMap = [emojiFactory valueForKey:@"emojiMap"];
	
	NSArray *keys = nil;
	if ([self isEmoji])
	{
		keys = [emojiMap allKeys];
	}
	else
	{
		for(uint32_t i = 0; i < _dyld_image_count(); i++)
		{
			if (strstr(_dyld_get_image_name(i), "UIKit.framework"))
			{
				struct mach_header* header = (struct mach_header*)_dyld_get_image_header(i);
				NSMutableDictionary **__mappedImages = APEFindSymbol(header, "___mappedImages");
				NSMutableDictionary **__images = APEFindSymbol(header, "___images");
				int (*_UIPackedImageTableMinIdentifier)(void) = APEFindSymbol(header, "__UIPackedImageTableMinIdentifier");
				int (*_UIPackedImageTableMaxIdentifier)(void) = APEFindSymbol(header, "__UIPackedImageTableMaxIdentifier");
				UIImage* (*_UISharedImageWithIdentifier)(int) = APEFindSymbol(header, "__UISharedImageWithIdentifier");
				
				if (_UIPackedImageTableMinIdentifier && _UIPackedImageTableMaxIdentifier && _UISharedImageWithIdentifier)
				{
					// Force loading all images (iOS 4 only)
					int minIdentifier = _UIPackedImageTableMinIdentifier();
					int maxIdentifier = _UIPackedImageTableMaxIdentifier();
					for (int i = minIdentifier; i <= maxIdentifier; i++)
						(void)_UISharedImageWithIdentifier(i);
				}
				
				if (__mappedImages)
					keys = [*__mappedImages allKeys]; // iOS 3
				else if (__images)
					keys = [*__images allKeys]; // iOS 4
				
				break;
			}
		}
	}
	
	
	images = [[NSMutableDictionary alloc] init];
	for (NSString *key in keys)
	{
		NSString *imageName = nil;
		UIImage *image = nil;
		
		if ([self isEmoji])
		{
			id emoji = [emojiMap objectForKey:key];
			imageName = [emoji valueForKey:@"imageName"];
			image = [emoji valueForKey:@"image"];
		}
		else
		{
			imageName = key;
			image = [UIImage performSelector:@selector(kitImageNamed:) withObject:key]; // calls _UIImageWithName
		}
		
		[images setObject:image forKey:imageName];
	}
	
	return images;
}

- (void) viewDidLoad
{
	self.progressView.frame = CGRectMake(10, 17, 90, 11);
	self.progressView.hidden = YES;
	[self.navigationController.navigationBar addSubview:self.progressView];

	self.saveAllButton.enabled = [self.images count] > 0;

	NSMutableArray *imageCells = [NSMutableArray arrayWithCapacity:[self.images count]];

	for (NSString *imageName in [[self.images allKeys] sortedArrayUsingSelector:@selector(compare:)])
	{
		UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ImageCell"] autorelease];
		cell.textLabel.text = imageName;
		cell.textLabel.font = [UIFont systemFontOfSize:12];
		UIImage *image = [self.images objectForKey:imageName];
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

- (void) viewWillAppear:(BOOL)animated
{
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath)
		[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:animated];
}

- (void) viewDidAppear:(BOOL)animated
{
	self.title = [[self.tabBarController.tabBar.items objectAtIndex:self.tabBarController.selectedIndex] title];
	self.saveAllButton.target = self;
	self.navigationController.navigationBar.topItem.rightBarButtonItem = self.saveAllButton;
}

- (void) viewDidUnload
{
	self.progressView = nil;
	self.saveAllButton = nil;
	self.cells = nil;
}

- (void) saveImage:(NSString *)imageName
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	CGFloat scale = [[UIScreen mainScreen] scale];
	NSString *imageNameWithScale = imageName;
	if (scale > 1)
		imageNameWithScale = [[[imageName stringByDeletingPathExtension] stringByAppendingFormat:@"@%gx", scale] stringByAppendingPathExtension:[imageName pathExtension]];
	NSString *imagePath = [[appDelegate saveDirectory] stringByAppendingPathComponent:imageNameWithScale];
	[UIImagePNGRepresentation([self.images objectForKey:imageName]) writeToFile:imagePath atomically:YES];
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

- (NSArray *) filteredCells
{
	NSString *searchText = [NSString stringWithFormat:@"*%@*", [self.searchDisplayController.searchBar.text lowercaseString]];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"textLabel.text.lowercaseString LIKE %@", searchText];
	NSArray *filteredCells = [self.cells filteredArrayUsingPredicate:predicate];
	return filteredCells;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (tableView == self.tableView)
		return [self.cells count];
	else
		return [[self filteredCells] count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (tableView == self.tableView)
		return [self.cells objectAtIndex:indexPath.row];
	else
		return [[self filteredCells] objectAtIndex:indexPath.row];
}

// MARK: Table View Delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *imageName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
	
	ArtworkDetailViewController *artworkDetailViewController = [[ArtworkDetailViewController alloc] initWithImage:[self.images objectForKey:imageName] name:imageName];
	[self.navigationController pushViewController:artworkDetailViewController animated:YES];
	[artworkDetailViewController release];
}

// MARK: Search Display Delegate

- (void) searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
	tableView.backgroundColor = self.tableView.backgroundColor;
}

- (void) searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
	[self.tableView reloadData];

	NSArray *indexPathsForVisibleRows = [controller.searchResultsTableView indexPathsForVisibleRows];
	UITableViewCell *firstVisibleCell = nil;
	if ([indexPathsForVisibleRows count] > 0)
		firstVisibleCell = [controller.searchResultsTableView cellForRowAtIndexPath:[indexPathsForVisibleRows objectAtIndex:0]];

	if (firstVisibleCell)
		self.firstCellIndexPath = [NSIndexPath indexPathForRow:[self.cells indexOfObject:firstVisibleCell] inSection:0];
	else
		self.firstCellIndexPath = nil;
}

- (void) searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
	[self.tableView scrollToRowAtIndexPath:self.firstCellIndexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

@end
