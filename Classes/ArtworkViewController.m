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

static NSString *systemLibraryPath()
{
	NSString *systemFrameworksPath = @"/System/Library/Frameworks";
	for (NSBundle *framework in [NSBundle allFrameworks])
	{
		// So that it works on both simulator and device
		NSString *frameworkName = [[framework bundlePath] lastPathComponent];
		if ([frameworkName isEqualToString:@"Foundation.framework"])
		{
			systemFrameworksPath = [[framework bundlePath] stringByDeletingLastPathComponent];
			break;
		}
	}
	return [systemFrameworksPath stringByDeletingLastPathComponent];
}


@implementation ArtworkViewController

@synthesize progressView;
@synthesize saveAllButton;
@synthesize bundles;
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

- (NSArray *) allCells
{
	NSMutableArray *allCells = [NSMutableArray array];
	for (NSArray *cells in [self.bundles allValues])
		[allCells addObjectsFromArray:cells];
	return allCells;
}

- (void) addImage:(UIImage *)image filePath:(NSString *)filePath
{
	NSString *fileName = [filePath lastPathComponent];
	// We already have higher resolution emoji
	if ([fileName hasPrefix:@"emoji"])
		return;

	NSString *bundlePath = [filePath stringByDeletingLastPathComponent];
	NSString *bundleName = [[bundlePath lastPathComponent] stringByDeletingPathExtension];
	if ([bundleName length] == 0) // Extracted from .artwork file, has no actual path
		bundleName = @" Artwork"; // With a space so that it's the first section

	for (UITableViewCell *cell in [self allCells])
	{
		if ([cell.textLabel.text isEqualToString:fileName])
		{
			NSData *file1Data = [NSData dataWithContentsOfFile:cell.detailTextLabel.text];
			NSData *file2Data = [NSData dataWithContentsOfFile:filePath];
			if ([file1Data isEqualToData:file2Data]) // Filter out exact duplicates
				return;

			// Avoid duplicate file names so that "Save All" does not clobber any file
			fileName = [bundleName stringByAppendingFormat:@"_%@", fileName];
		}
	}

	// There are only a few settings bundles, so group them
	if ([bundleName rangeOfString:@"Settings"].location != NSNotFound)
		bundleName = @"Settings";

	if (![self.bundles objectForKey:bundleName])
		[self.bundles setObject:[NSMutableArray array] forKey:bundleName];

	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ImageCell"] autorelease];
	cell.textLabel.text = fileName;
	cell.textLabel.font = [UIFont systemFontOfSize:12];
	// Just because I'm too lazy to subclass UITableViewCell and I need to store the full path for duplicates comparison
	cell.detailTextLabel.text = filePath;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:FLT_EPSILON];
	UIImageView *imageView = [[[UIImageView alloc] initWithImage:image] autorelease];
	CGFloat size = CGRectGetHeight(cell.frame) - 4;
	imageView.frame = CGRectMake(imageView.frame.origin.x, imageView.frame.origin.y, size, size);
	if (image.size.height > size || image.size.width > size)
		imageView.contentMode = UIViewContentModeScaleAspectFit;
	else
		imageView.contentMode = UIViewContentModeCenter;
	cell.accessoryView = imageView;

	NSMutableArray *cells = [self.bundles objectForKey:bundleName];
	[cells addObject:cell];
}

- (void) viewDidLoad
{
	self.progressView.frame = CGRectMake(10, 17, 90, 11);
	self.progressView.hidden = YES;
	[self.navigationController.navigationBar addSubview:self.progressView];

	self.saveAllButton.enabled = [self.images count] > 0;

	self.bundles = [NSMutableDictionary dictionary];

	for (NSString *imageName in [[self.images allKeys] sortedArrayUsingSelector:@selector(compare:)])
		[self addImage:[self.images objectForKey:imageName] filePath:imageName];

	if ([self isEmoji])
		return;

	for (NSString *relativePath in [[NSFileManager defaultManager] enumeratorAtPath:systemLibraryPath()])
	{
		if ([relativePath hasSuffix:@"png"] && [relativePath rangeOfString:@"@2x"].location == NSNotFound)
		{
			NSString *filePath = [systemLibraryPath() stringByAppendingPathComponent:relativePath];
			// TODO: workaround http://www.openradar.me/8225750
			[self addImage:[UIImage imageWithContentsOfFile:filePath] filePath:filePath];
		}
	}
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
	self.bundles = nil;
}

- (void) saveImage:(NSDictionary *)imageInfo
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	CGFloat scale = [[UIScreen mainScreen] scale];
	NSString *imageName = [imageInfo objectForKey:@"name"];
	NSString *imageNameWithScale = imageName;
	if (scale > 1)
		imageNameWithScale = [[[imageName stringByDeletingPathExtension] stringByAppendingFormat:@"@%gx", scale] stringByAppendingPathExtension:[imageName pathExtension]];
	NSString *imagePath = [[appDelegate saveDirectory] stringByAppendingPathComponent:imageNameWithScale];
	[UIImagePNGRepresentation([imageInfo objectForKey:@"image"]) writeToFile:imagePath atomically:YES];
	[self performSelectorOnMainThread:@selector(incrementSaveCounter) withObject:nil waitUntilDone:YES];
	[pool drain];
}

- (IBAction) saveAll
{
	self.saveCounter = 0;
	self.progressView.hidden = NO;
	for (UITableViewCell *cell in [self allCells])
	{
		NSDictionary *imageInfo = [NSDictionary dictionaryWithObjectsAndKeys:((UIImageView*)cell.accessoryView).image, @"image", cell.textLabel.text, @"name", nil];
		[self performSelectorInBackground:@selector(saveImage:) withObject:imageInfo];
	}
}

- (void) incrementSaveCounter
{
	self.saveCounter++;
	NSUInteger count = [self.images count];
	if (self.saveCounter == count)
		self.progressView.hidden = YES;
	self.progressView.progress = ((CGFloat)self.saveCounter / (CGFloat)count);
}

// MARK: -
// MARK: Table View Data Source

- (NSArray *) filteredCells
{
	NSString *searchText = [NSString stringWithFormat:@"*%@*", [self.searchDisplayController.searchBar.text lowercaseString]];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"textLabel.text.lowercaseString LIKE %@", searchText];
	NSArray *filteredCells = [[self allCells] filteredArrayUsingPredicate:predicate];
	return filteredCells;
}

- (NSArray *) sectionTitles
{
	return [[self.bundles allKeys] sortedArrayUsingSelector:@selector(localizedCompare:)];
}

- (NSArray *) cellsInSection:(NSUInteger)section
{
	NSString *bundleName = [[self sectionTitles] objectAtIndex:section];
	return [self.bundles objectForKey:bundleName];
}

// MARK: Section titles

- (NSArray *) sectionIndexTitlesForTableView:(UITableView *)tableView
{
	if (tableView == self.tableView && ![self isEmoji])
	{
		NSMutableArray *sectionIndexTitles = [NSMutableArray array];
		for (NSString *title in [self sectionTitles])
			[sectionIndexTitles addObject:[title substringToIndex:2]];
		return sectionIndexTitles;
	}
	else
		return nil;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
{
	if (tableView == self.tableView && ![self isEmoji])
		return [[self sectionTitles] objectAtIndex:section];
	else
		return nil;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	if (tableView == self.tableView && ![self isEmoji])
		return [[self.bundles allKeys] count];
	else
		return 1;
}

// MARK: Cells

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (tableView == self.tableView)
		return [[self cellsInSection:section] count];
	else
		return [[self filteredCells] count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (tableView == self.tableView)
		return [[self cellsInSection:indexPath.section] objectAtIndex:indexPath.row];
	else
		return [[self filteredCells] objectAtIndex:indexPath.row];
}

// MARK: -
// MARK: Table View Delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UIImage *image = ((UIImageView*)cell.accessoryView).image;
	NSString *imageName = cell.textLabel.text;
	ArtworkDetailViewController *artworkDetailViewController = [[ArtworkDetailViewController alloc] initWithImage:image name:imageName];
	[self.navigationController pushViewController:artworkDetailViewController animated:YES];
	[artworkDetailViewController release];
}

// MARK: -
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
	{
		NSUInteger section = 0;
		NSUInteger row = 0;
		for (NSString *title in [self sectionTitles])
		{
			NSArray *cells = [self.bundles objectForKey:title];
			row = [cells indexOfObject:firstVisibleCell];
			if (row != NSNotFound)
				break;
			section++;
		}
		self.firstCellIndexPath = [NSIndexPath indexPathForRow:row inSection:section];
	}
	else
		self.firstCellIndexPath = nil;
}

- (void) searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
	[self.tableView scrollToRowAtIndexPath:self.firstCellIndexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

@end
