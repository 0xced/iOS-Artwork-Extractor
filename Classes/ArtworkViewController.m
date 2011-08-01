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

#import "FindSymbol.h"
#import <mach-o/dyld.h>

struct imageMapInfo
{
	Class class;
	int unknown1;
	char *name;
	int unknown2;
};

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

static NSString *pathWithScale(NSString *path, CGFloat scale)
{
	if (scale > 1)
		return [[[path stringByDeletingPathExtension] stringByAppendingFormat:@"@%gx", scale] stringByAppendingPathExtension:[path pathExtension]];
	else
		return path;
}

// Workaround http://www.openradar.me/8225750
static UIImage *imageWithContentsOfFile(NSString *path)
{
	NSString *imagePathWithScale = pathWithScale(path, [[UIScreen mainScreen] scale]);
	if ([[NSFileManager defaultManager] fileExistsAtPath:imagePathWithScale])
		return [UIImage imageWithContentsOfFile:imagePathWithScale];
	else
		return [UIImage imageWithContentsOfFile:path];
}


@implementation ArtworkViewController

@synthesize progressView;
@synthesize saveAllButton;
@synthesize bundles;
@synthesize firstCellIndexPath;
@synthesize saveCounter;

- (BOOL) isEmoji
{
	return self.tableView.tag == 0xE770;
}

- (NSDictionary*) artwork
{
	if (artwork)
		return artwork;
	
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
				NSMutableDictionary **__mappedImages = FindSymbol(header, "___mappedImages");
				NSMutableDictionary **__images = FindSymbol(header, "___images");
				
				NSString *deviceModel = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone";
				NSString *imageMapNamesSymbol = [NSString stringWithFormat:@"_ImageMapNames_Shared_%gx_%@", [[UIScreen mainScreen] scale], deviceModel];
				BOOL isVersion5OrLater = [UIImage instancesRespondToSelector:@selector(CIImage)];
				if (isVersion5OrLater)
					imageMapNamesSymbol = [NSString stringWithFormat:@"_ImageMapNames_Shared_%gx", [[UIScreen mainScreen] scale]];
				struct imageMapInfo **imageMapNames = FindSymbol(header, [imageMapNamesSymbol UTF8String]);
				
				// Force loading all images (iOS 4 only)
				if (imageMapNames)
				{
					// iOS 4.1
					while (*imageMapNames)
					{
						struct imageMapInfo *imageInfo = *imageMapNames++;
						NSString *imageName = [NSString stringWithUTF8String:imageInfo->name];
						(void)[UIImage performSelector:@selector(kitImageNamed:) withObject:imageName];
					}
				}
				else
				{
					// iOS 4.0
					int *__sharedImageSets = FindSymbol(header, "___sharedImageSets");
					if (__sharedImageSets)
					{
						NSString **sharedImageNames = (NSString**)(*(int*)(__sharedImageSets + 4));
						NSUInteger sharedImageCount = (*(int*)(__sharedImageSets + 5));
						if (sharedImageNames)
						{
							for (int i = 0; i < sharedImageCount; i++)
							{
								NSString *imageName = sharedImageNames[i];
								(void)[UIImage performSelector:@selector(kitImageNamed:) withObject:imageName];
							}
						}
					}
				}
				
				if (__mappedImages)
					keys = [*__mappedImages allKeys]; // iOS 3
				else if (__images)
					keys = [*__images allKeys]; // iOS 4
				
				break;
			}
		}
	}
	
	artwork = [[NSMutableDictionary alloc] init];
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
		
		[artwork setObject:image forKey:imageName];
	}
	
	return artwork;
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
	NSString *oppositeInterfaceIdiomSuffix = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone ? @"~ipad" : @"~iphone";
	if ([filePath rangeOfString:oppositeInterfaceIdiomSuffix].location != NSNotFound)
		return;
	
	NSString *fileName = [filePath lastPathComponent];
	NSString *bundlePath = [filePath stringByDeletingLastPathComponent];
	NSString *bundleName = [bundlePath lastPathComponent];
	if ([bundleName length] == 0) // Extracted from .artwork file, has no actual path
		bundleName = [self isEmoji] ? @"Emoji" : @"Shared";

	// We already have higher resolution emoji
	if ([bundleName isEqualToString:@"WebCore.framework"] && [fileName hasPrefix:@"emoji"])
		return;

	for (UITableViewCell *cell in [self allCells])
	{
		if ([cell.textLabel.text caseInsensitiveCompare:fileName] == NSOrderedSame)
		{
			NSData *file1Data = [NSData dataWithContentsOfFile:cell.detailTextLabel.text];
			NSData *file2Data = [NSData dataWithContentsOfFile:filePath];
			if ([file1Data isEqualToData:file2Data]) // Filter out exact duplicates
				return;
		}
	}

	// There are only a few settings bundles, so group them
	if ([bundleName rangeOfString:@"Settings"].location != NSNotFound)
	{
		fileName = [NSString stringWithFormat:@"%@_%@", [bundleName stringByDeletingPathExtension], fileName];
		bundleName = @"Settings";
	}

	if (![self.bundles objectForKey:bundleName])
		[self.bundles setObject:[NSMutableArray array] forKey:bundleName];
	
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ImageCell"] autorelease];
	cell.textLabel.text = fileName;
	cell.textLabel.font = [UIFont systemFontOfSize:12];
	// Just because I'm too lazy to subclass UITableViewCell and I need to store the full path for duplicates comparison
	cell.detailTextLabel.text = filePath;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:FLT_EPSILON];
	UIImageView *imageView = [[[UIImageView alloc] initWithImage:image] autorelease];
	CGFloat sizeX = CGRectGetHeight(cell.frame) - 4 - ((int)image.size.width % 2);
	CGFloat sizeY = CGRectGetHeight(cell.frame) - 4 - ((int)image.size.height % 2);
	imageView.frame = CGRectMake(imageView.frame.origin.x, imageView.frame.origin.y, sizeX, sizeY);
	if (image.size.height > sizeY || image.size.width > sizeX)
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

	self.saveAllButton.enabled = [self.artwork count] > 0;

	self.bundles = [NSMutableDictionary dictionary];

	for (NSString *imageName in [[self.artwork allKeys] sortedArrayUsingSelector:@selector(compare:)])
		[self addImage:[self.artwork objectForKey:imageName] filePath:imageName];

	if ([self isEmoji])
		return;

	for (NSString *relativePath in [[NSFileManager defaultManager] enumeratorAtPath:systemLibraryPath()])
	{
		if ([relativePath hasSuffix:@"png"] && [[relativePath lowercaseString] rangeOfString:@"@2x"].location == NSNotFound)
		{
			NSString *filePath = [systemLibraryPath() stringByAppendingPathComponent:relativePath];
			[self addImage:imageWithContentsOfFile(filePath) filePath:filePath];
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
	UIImage *image = [imageInfo objectForKey:@"image"];
	NSString *imageName = [imageInfo objectForKey:@"name"];
	NSString *bundleName = [[imageInfo objectForKey:@"bundleName"] stringByReplacingOccurrencesOfString:@"." withString:@" "];
	NSString *imagePath = [[appDelegate saveDirectory:bundleName] stringByAppendingPathComponent:pathWithScale(imageName, [image scale])];
	[UIImagePNGRepresentation(image) writeToFile:imagePath atomically:YES];
	[self performSelectorOnMainThread:@selector(incrementSaveCounter) withObject:nil waitUntilDone:YES];
	[pool drain];
}

- (NSArray *) sectionKeys
{
	return [[self.bundles allKeys] sortedArrayUsingSelector:@selector(localizedCompare:)];	
}

- (IBAction) saveAll
{
	self.saveCounter = 0;
	self.progressView.hidden = NO;
	self.saveAllButton.enabled = NO;
	NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
	[queue setMaxConcurrentOperationCount:4];
	for (NSString *bundleName in [self sectionKeys])
	{
		for (UITableViewCell *cell in [self.bundles objectForKey:bundleName])
		{
			NSDictionary *imageInfo = [NSDictionary dictionaryWithObjectsAndKeys:((UIImageView*)cell.accessoryView).image, @"image", cell.textLabel.text, @"name", bundleName, @"bundleName", nil];
			NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(saveImage:) object:imageInfo];
			[queue addOperation:operation];
			[operation release];
		}
	}
}

- (void) incrementSaveCounter
{
	self.saveCounter++;
	NSUInteger count = [[self allCells] count];
	if (self.saveCounter == count)
	{
		self.progressView.hidden = YES;
		self.saveAllButton.enabled = YES;
	}
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
	NSMutableArray *sectionTitles = [NSMutableArray array];
	for (NSString *bundleName in [self sectionKeys])
	{
		NSArray *cells = [self.bundles objectForKey:bundleName];
		NSString *sectionTitle = [NSString stringWithFormat:@"%@ (%d)", bundleName, [cells count]];
		[sectionTitles addObject:sectionTitle];
	}
	return sectionTitles;
}

- (NSArray *) cellsInSection:(NSUInteger)section
{
	NSString *bundleName = [[self sectionKeys] objectAtIndex:section];
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
	NSString *bundleName = [[self sectionKeys] objectAtIndex:indexPath.section];
	NSDictionary *imageInfo = [NSDictionary dictionaryWithObjectsAndKeys:((UIImageView*)cell.accessoryView).image, @"image", cell.textLabel.text, @"name", bundleName, @"bundleName", nil];
	ArtworkDetailViewController *artworkDetailViewController = [[ArtworkDetailViewController alloc] initWithImageInfo:imageInfo];
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
		for (NSString *bundleName in [self sectionKeys])
		{
			NSArray *cells = [self.bundles objectForKey:bundleName];
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
