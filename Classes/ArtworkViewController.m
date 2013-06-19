//
//  ArtworkViewController.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 19.02.10.
//  Copyright Cédric Luthi 2010. All rights reserved.
//

#import "ArtworkViewController.h"
#import "ArtworkDetailViewController.h"
#import "AppDelegate.h"
#import "EmojiImageView.h"
#import "IPAArchive.h"

#import "FindSymbol.h"
#import <mach-o/dyld.h>
#import <objc/runtime.h>

struct imageMapInfo
{
	Class class;
	int unknown1;
	char *name;
	int unknown2;
};

static NSString *systemRoot()
{
	static NSString *systemRoot = nil;
	if (systemRoot)
		return systemRoot;
	
	// Extract images from actual firmware if mounted instead of simulator
	// Use https://github.com/kennytm/Miscellaneous/blob/master/ipsw_decrypt.py
	for (NSString *volumeName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Volumes" error:NULL])
	{
		NSString *volumePath = [@"/Volumes" stringByAppendingPathComponent:volumeName];
		NSString *systemVersionPath = [volumePath stringByAppendingPathComponent:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:systemVersionPath];
		NSString *productName = [systemVersion objectForKey:@"ProductName"];
		NSString *productVersion = [systemVersion objectForKey:@"ProductVersion"];
		if ([productName isEqualToString:@"iPhone OS"] && [productVersion hasPrefix:[UIDevice currentDevice].systemVersion])
		{
			NSString *wallpaperPath = [volumePath stringByAppendingPathComponent:@"/Library/Wallpaper"];
			NSArray *wallpapers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:wallpaperPath error:NULL];
			NSString *model = [wallpapers count] == 1 ? [wallpapers lastObject] : @"iPhone";
			if ([[UIDevice currentDevice].model hasPrefix:model])
			{
				systemRoot = [volumePath retain];
				return systemRoot;
			}
		}
	}
	
	return [[[NSProcessInfo processInfo] environment] objectForKey:@"IPHONE_SIMULATOR_ROOT"] ?: @"/";
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


@interface NSObject (UIKeyboardEmojiCategory)
+ (NSInteger) numberOfCategories;
+ (id) categoryForType:(NSInteger)type;
@end


@interface NSObject (UIKeyboardEmojiImageView)
- (id) initWithFrame:(CGRect)frame emojiString:(NSString *)emojiString;
@end


@interface ArtworkViewController ()
- (NSArray *) sectionTitles;
@end


@interface NSObject (UISharedArtwork)
- (id) nameAtIndex:(NSUInteger)index;
@end

@interface NSObject (_UIAssetManager)
- (id) initWithName:(NSString *)name inBundle:(NSBundle *)bundle idiom:(UIUserInterfaceIdiom)idiom;
@end


@implementation ArtworkViewController

@synthesize progressView = _progressView;
@synthesize saveAllButton = _saveAllButton;
@synthesize bundles = _bundles;
@synthesize firstCellIndexPath = _firstCellIndexPath;
@synthesize saveCounter = _saveCounter;
@synthesize archive = _archive;

+ (void) initialize
{
	if (self != [ArtworkViewController class])
		return;
	
	Method image = class_getInstanceMethod([EmojiImageView class], @selector(image));
	class_addMethod(NSClassFromString(@"UIKeyboardEmojiImageView"), @selector(image), method_getImplementation(image), method_getTypeEncoding(image));
}

- (id) initWithArchive:(IPAArchive *)archive
{
	if (!(self = [super initWithNibName:@"ArtworkViewController" bundle:nil]))
		return nil;
	
	self.archive = archive;
	self.title = archive.appName;
	
	return self;
}

- (void) dealloc
{
	self.progressView = nil;
	self.saveAllButton = nil;
	self.bundles = nil;
	self.firstCellIndexPath = nil;
	[self.archive unload];
	self.archive = nil;
	
	[artwork release];
	
	[super dealloc];
}

- (BOOL) isArtwork
{
	return [self.title isEqualToString:@"Artwork"];
}

- (BOOL) isEmoji
{
	return [self.title isEqualToString:@"Emoji"];
}

- (BOOL) isIPA
{
	return self.archive != nil;
}

- (NSDictionary *) artwork
{
	if (artwork)
		return artwork;
	
	Class UIKeyboardEmojiImages = NSClassFromString(@"UIKeyboardEmojiImages"); // iOS 3 only
	[UIKeyboardEmojiImages performSelector:@selector(mapImagesIfNecessary)];
	
	NSArray *keys = nil;
	NSDictionary *emojiMap = nil;
	if ([self isEmoji])
	{
		Class UIKeyboardEmojiFactory = NSClassFromString(@"UIKeyboardEmojiFactory"); // removed in iOS 6
		id emojiFactory = [[[UIKeyboardEmojiFactory alloc] init] autorelease];
		@try
		{
			if (!emojiFactory)
				@throw [NSException exceptionWithName:@"EmojiException" reason:@"UIKeyboardEmojiFactory class not available" userInfo:nil];
			
			emojiMap = [emojiFactory valueForKey:@"emojiMap"]; // removed in iOS 5.1
			keys = [emojiMap allKeys];
		}
		@catch (NSException *exception)
		{
			Class UIKeyboardEmojiCategory = NSClassFromString(@"UIKeyboardEmojiCategory");
			NSMutableArray *categories = [NSMutableArray array];
			// UIKeyboardEmojiCategory has a +categories method, but it does not fill emoji. Calling categoryForType: does fill emoji
			if ([UIKeyboardEmojiCategory respondsToSelector:@selector(numberOfCategories)])
			{
				NSInteger numberOfCategories = [UIKeyboardEmojiCategory numberOfCategories];
				for (NSUInteger i = 0; i < numberOfCategories; i++)
					[categories addObject:[UIKeyboardEmojiCategory categoryForType:i]];
			}
			
			if ([categories count] == 0)
			{
				// iOS < 6
				Class UIKeyboardEmojiCategoryController = NSClassFromString(@"UIKeyboardEmojiCategoryController");
				id keyboardEmojiCategoryController = [[UIKeyboardEmojiCategoryController alloc] performSelector:@selector(initWithController:) withObject:emojiFactory];
				for (NSString *categoryName in [NSArray arrayWithObjects:@"People", @"Nature", @"Objects", @"Places", @"Symbols", nil])
				{
					NSString *categoryKey = [@"UIKeyboardEmojiCategory" stringByAppendingString:categoryName];
					id /* UIKeyboardEmojiCategory */ category = [keyboardEmojiCategoryController performSelector:@selector(categoryForKey:) withObject:categoryKey];
					[(NSMutableArray *)categories addObject:category];
				}
			}
			
			for (id /* UIKeyboardEmojiCategory */ category in categories)
			{
				NSString *categoryName = [category performSelector:@selector(name)];
				if ([categoryName hasSuffix:@"Recent"])
					continue;
				
				NSString *displayName = [category respondsToSelector:@selector(displayName)] ? [category performSelector:@selector(displayName)] : categoryName;
				if ([displayName hasPrefix:@"UIKeyboardEmojiCategory"])
					displayName = [displayName substringFromIndex:23];
				NSMutableArray *categoryList = [NSMutableArray array];
				for (id /* UIKeyboardEmoji */ emoji in [category valueForKey:@"emoji"])
				{
					NSMutableString *name = (NSMutableString *)CFStringCreateMutableCopy(kCFAllocatorDefault, 0, (CFStringRef)[emoji valueForKey:@"key"]);
					CFStringTransform((CFMutableStringRef)name, NULL, kCFStringTransformToUnicodeName, false);
					[name replaceOccurrencesOfString:@"\\N" withString:@"" options:0 range:NSMakeRange(0, [name length])];
					[name replaceOccurrencesOfString:@"{" withString:@"" options:0 range:NSMakeRange(0, [name length])];
					[name replaceOccurrencesOfString:@"}" withString:@"" options:0 range:NSMakeRange(0, [name length])];
					
					UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"EmojiCell"] autorelease];
					cell.textLabel.text = [[[(NSMutableString *)name autorelease] capitalizedString] stringByAppendingPathExtension:@"png"];
					cell.textLabel.font = [UIFont systemFontOfSize:12];
					CGFloat maximumSharpSize = 24;
					CGRect emojiFrame = CGRectMake(0, 0, maximumSharpSize, maximumSharpSize);
					cell.accessoryView = [[[NSClassFromString(@"UIKeyboardEmojiImageView") alloc] initWithFrame:emojiFrame emojiString:[emoji valueForKey:@"emojiString"]] autorelease];
					if (!cell.accessoryView)
						cell.accessoryView = [[[EmojiImageView alloc] initWithFrame:emojiFrame emoji:emoji] autorelease];
					
					[categoryList addObject:cell];
				}
				
				[self.bundles setObject:categoryList forKey:displayName];
			}
		}
	}
	else if ([self isIPA])
	{
		keys = nil;
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
	
	NSString *fileName = [[filePath lastPathComponent] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"@%gx", image.scale] withString:@""];
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

	NSString *appBundleName = [[bundlePath stringByDeletingLastPathComponent] lastPathComponent];
	if ([appBundleName isEqualToString:@"Compass.app"])
	{
		fileName = [NSString stringWithFormat:@"%@_%@", [bundleName stringByDeletingPathExtension], fileName];
		bundleName = @"Compass.app";
	}
	
	if ([filePath rangeOfString:@"GKWelcomeToGameCenter"].location != NSNotFound)
	{
		fileName = [NSString stringWithFormat:@"%@_%@", [bundleName stringByDeletingPathExtension], fileName];
		bundleName = @"Game Center~ipad.app";
	}
	
	if ([filePath rangeOfString:@"_CARRIER_"].location != NSNotFound)
	{
		bundleName = @"Carriers";
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
	
	NSString *progress = [NSString stringWithFormat:@"%@ (%u)", [bundleName stringByDeletingPathExtension], [cells count]];
	[self.navigationItem performSelectorOnMainThread:@selector(setTitle:) withObject:progress waitUntilDone:NO];
}

- (void) loadImages
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	for (NSString *imageName in [[self.artwork allKeys] sortedArrayUsingSelector:@selector(localizedCompare:)])
		[self addImage:[self.artwork objectForKey:imageName] filePath:imageName];
	
	if ([self isArtwork])
	{
		for (NSString *relativePath in [[NSFileManager defaultManager] enumeratorAtPath:systemRoot()])
		{
			BOOL scale1 = [UIScreen mainScreen].scale == 1 && [[relativePath lowercaseString] rangeOfString:@"@2x"].location == NSNotFound;
			BOOL scale2 = [UIScreen mainScreen].scale == 2 && [[relativePath lowercaseString] rangeOfString:@"@2x"].location != NSNotFound;
			NSString *filePath = [systemRoot() stringByAppendingPathComponent:relativePath];
			NSBundle *bundle = [NSBundle bundleWithPath:[filePath stringByDeletingLastPathComponent]];
			NSString *archiveName = [[relativePath lastPathComponent] stringByDeletingPathExtension];
			if ([relativePath hasSuffix:@"png"] && (scale1 || scale2))
			{
				NSString *filePath = [systemRoot() stringByAppendingPathComponent:relativePath];
				[self addImage:imageWithContentsOfFile(filePath) filePath:filePath];
			}
			else if ([[relativePath pathExtension] isEqualToString:@"artwork"])
			{
				NSRange atRange = [archiveName rangeOfString:@"@"];
				NSRange tildeRange = [archiveName rangeOfString:@"~"];
				if (atRange.location != NSNotFound)
					archiveName = [archiveName substringToIndex:atRange.location];
				else if (tildeRange.location != NSNotFound)
					archiveName = [archiveName substringToIndex:tildeRange.location];
				
				id sharedArtwork = [[[NSClassFromString(@"UISharedArtwork") alloc] performSelector:@selector(initWithName:inBundle:) withObject:archiveName withObject:bundle] autorelease];
				archiveName = [archiveName stringByAppendingPathExtension:@"artwork"];
				if ([self.bundles objectForKey:archiveName])
					continue;
				
				for (NSUInteger i = 0; i < [sharedArtwork count]; i++)
				{
					NSString *name = [sharedArtwork nameAtIndex:i];
					UIImage *image = name ? [sharedArtwork imageNamed:name] : nil;
					if (name && [image scale] == [[UIScreen mainScreen] scale])
						[self addImage:image filePath:[archiveName stringByAppendingPathComponent:name]];
				}
			}
			else if ([[relativePath pathExtension] isEqualToString:@"car"])
			{
				id assetManager = [[NSClassFromString(@"_UIAssetManager") alloc] initWithName:archiveName inBundle:bundle idiom:[[UIDevice currentDevice] userInterfaceIdiom]];
				NSArray *allRenditionNames = [assetManager valueForKeyPath:@"catalog.themeStore.store.allRenditionNames"];
				for (NSString *renditionName in allRenditionNames)
				{
					UIImage *image = [assetManager imageNamed:renditionName];
					NSString *pseudoBundlePath = [[relativePath stringByDeletingLastPathComponent] stringByAppendingFormat:@" %@", archiveName];
					NSString *filePath = [[pseudoBundlePath stringByAppendingPathComponent:renditionName] stringByAppendingPathExtension:@"png"];
					if ([image scale] == [[UIScreen mainScreen] scale])
						[self addImage:image filePath:filePath];
				}
			}
		}
	}
	else if ([self isIPA])
	{
		for (NSString *imageName in self.archive.imageNames)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			BOOL scale1 = [UIScreen mainScreen].scale == 1 && [[imageName lowercaseString] rangeOfString:@"@2x"].location == NSNotFound;
			BOOL scale2 = [UIScreen mainScreen].scale == 2 && [[imageName lowercaseString] rangeOfString:@"@2x"].location != NSNotFound;
			if ([imageName hasSuffix:@"png"] && (scale1 || scale2))
			{
				[self addImage:[self.archive imageNamed:imageName] filePath:imageName];
			}
			[pool drain];
		}
	}
	
	[self performSelectorOnMainThread:@selector(imagesDidLoad) withObject:nil waitUntilDone:NO];
	
	[pool drain];
}

- (void) imagesDidLoad
{
	self.tableView.hidden = NO;
	self.navigationItem.title = self.title;
	self.navigationItem.rightBarButtonItem = self.saveAllButton;
	
	[self.tableView reloadData];
}

- (void) viewDidLoad
{
	self.progressView.frame = CGRectMake(10, 17, 90, 11);
	self.progressView.hidden = YES;
	[self.navigationController.navigationBar addSubview:self.progressView];
	self.tableView.hidden = YES;
	
	if ([self isEmoji])
		self.tableView.tableHeaderView = nil; // removes search bar
	
	self.bundles = [NSMutableDictionary dictionary];
	
	[self performSelectorInBackground:@selector(loadImages) withObject:nil];
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
	if (self.archive.appName && [[self sectionTitles] count] > 1)
		bundleName = [self.archive.appName stringByAppendingPathComponent:bundleName];
	else if ([self isEmoji])
		bundleName = [@"Emoji" stringByAppendingPathComponent:bundleName];
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
		AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
		NSString *message = [NSString stringWithFormat:@"Artwork has been saved into\n\"%@\"", [[appDelegate saveDirectory:nil] stringByAbbreviatingWithTildeInPath]];
		UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Open", nil] autorelease];
		[alertView show];
	}
	self.progressView.progress = ((CGFloat)self.saveCounter / (CGFloat)count);
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.cancelButtonIndex == buttonIndex)
		return;
	
	AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
	NSString *openCommand = [NSString stringWithFormat:@"/usr/bin/open \"%@\"", [appDelegate saveDirectory:nil]];
	system([openCommand fileSystemRepresentation]);
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
	if ([[self sectionKeys] count] == 0)
		return nil;
	
	NSString *bundleName = [[self sectionKeys] objectAtIndex:section];
	return [self.bundles objectForKey:bundleName];
}

// MARK: Section titles

- (NSArray *) sectionIndexTitlesForTableView:(UITableView *)tableView
{
	NSArray *sectionTitles = [self sectionTitles];
	if (![self isEmoji] && tableView == self.tableView && [sectionTitles count] > 1)
	{
		NSMutableArray *sectionIndexTitles = [NSMutableArray array];
		for (NSString *title in sectionTitles)
			[sectionIndexTitles addObject:[title substringToIndex:2]];
		return sectionIndexTitles;
	}
	else
		return nil;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
{
	NSArray *sectionTitles = [self sectionTitles];
	if (tableView == self.tableView && [sectionTitles count] > 1)
		return [sectionTitles objectAtIndex:section];
	else
		return nil;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	if (tableView == self.tableView)
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
	NSString *bundleName = @"Unknown";
	for (bundleName in self.bundles)
	{
		if ([[self.bundles objectForKey:bundleName] containsObject:cell])
			break;
	}
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
