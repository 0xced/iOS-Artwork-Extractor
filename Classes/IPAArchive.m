//
//  IPAArchive.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 30.12.11.
//  Copyright (c) 2011 Cédric Luthi. All rights reserved.
//

#import "IPAArchive.h"

#import <dlfcn.h>
#import "ZKCDHeader.h"
#import "ZKDataArchive.h"

static CGImageRef (*LICreateIconForImage)(CGImageRef image, NSUInteger variant, NSUInteger flags) = NULL;


@interface IPAArchive ()
@property (nonatomic, readwrite, retain) UIImage *appIcon;
@property (nonatomic, readwrite, retain) NSArray *imageNames;

@property (nonatomic, readwrite, retain) NSString *path;
@property (nonatomic, retain) ZKDataArchive *ipa;
@property (nonatomic, retain) NSDictionary *metadata;
@property (nonatomic, retain) NSDictionary *infoPlist;
@end


@implementation IPAArchive

@synthesize path = _path;
@synthesize ipa = _ipa;
@synthesize metadata = _metadata;
@synthesize infoPlist = _infoPlist;
@synthesize appIcon = _appIcon;
@synthesize imageNames = _imageNames;

+ (void) initialize
{
	if (self != [IPAArchive class])
		return;
	
	NSString *root = [[[NSProcessInfo processInfo] environment] objectForKey:@"IPHONE_SIMULATOR_ROOT"] ?: @"";
	void *MobileIcons = dlopen([[root stringByAppendingPathComponent:@"/System/Library/PrivateFrameworks/MobileIcons.framework/MobileIcons"] fileSystemRepresentation], RTLD_NOW);
	LICreateIconForImage = dlsym(MobileIcons, "LICreateIconForImage");
}

- (id) initWithPath:(NSString *)ipaPath;
{
	if (!(self = [super init]))
		return nil;
	
	self.path = ipaPath;
	
	return self;
}

- (void) dealloc
{
	self.path = nil;
	self.imageNames = nil;
	self.appIcon = nil;
	self.ipa = nil;
	self.metadata = nil;
	self.infoPlist = nil;
	
	[super dealloc];
}

- (NSDictionary *) metadata
{
	if (_metadata)
		return _metadata;
	
	for (ZKCDHeader *header in self.ipa.centralDirectory)
	{
		if ([header.filename isEqualToString:@"iTunesMetadata.plist"])
		{
			NSDictionary *attributes = nil;
			NSData *iTunesMetadata = [self.ipa inflateFile:header attributes:&attributes];
			_metadata = [[NSPropertyListSerialization propertyListWithData:iTunesMetadata options:0 format:NULL error:NULL] retain];
		}
	}
	
	return _metadata;
}

- (NSDictionary *) infoPlist
{
	if (_infoPlist)
		return _infoPlist;
	
	for (ZKCDHeader *header in self.ipa.centralDirectory)
	{
		if ([header.filename hasSuffix:@"/Info.plist"] && [[header.filename componentsSeparatedByString:@"/"] count] == 3)
		{
			NSDictionary *attributes = nil;
			NSData *infoData = [self.ipa inflateFile:header attributes:&attributes];
			_infoPlist = [[NSPropertyListSerialization propertyListWithData:infoData options:0 format:NULL error:NULL] retain];
			break;
		}
	}
	
	return _infoPlist;
}

- (NSString *) appName
{
	return [self.metadata objectForKey:@"itemName"];
}

- (UIImage *) appIcon
{
	if (_appIcon)
		return _appIcon;
	
	NSDictionary *bundleIcons = [self.infoPlist objectForKey:@"CFBundleIcons"];
	NSArray *bundleIconFiles = [[bundleIcons objectForKey:@"CFBundlePrimaryIcon"] objectForKey:@"CFBundleIconFiles"];
	if (!bundleIconFiles)
		bundleIconFiles = [self.infoPlist objectForKey:@"CFBundleIconFiles"];
	if (!bundleIconFiles)
	{
		NSString *bundleIconFile = [self.infoPlist objectForKey:@"CFBundleIconFile"];
		if ([bundleIconFile length] > 0)
			bundleIconFiles = [NSArray arrayWithObject:bundleIconFile];
	}
	if ([bundleIconFiles count] == 0)
	{
		bundleIconFiles = [NSArray arrayWithObjects:@"Icon.png", @"Icon@2x.png", @"Icon@3x.png", nil];
	}
	
	NSMutableArray *icons = [NSMutableArray array];
	for (NSString *iconFile in bundleIconFiles)
	{
		if ([iconFile length] > 0 && [[iconFile stringByDeletingPathExtension] isEqualToString:iconFile])
			iconFile = [iconFile stringByAppendingPathExtension:@"png"];
		
		for (ZKCDHeader *header in self.ipa.centralDirectory)
		{
			NSArray *pathComponents = [header.filename componentsSeparatedByString:@"/"];
			if ([pathComponents count] == 3)
			{
				NSString *iconName = [[pathComponents objectAtIndex:2] uppercaseString];
				if ([[iconFile uppercaseString] isEqualToString:iconName])
				{
					NSDictionary *attributes = nil;
					NSData *iconData = [self.ipa inflateFile:header attributes:&attributes];
					UIImage *icon = [UIImage imageWithData:iconData];
					if (icon)
						[icons addObject:icon];
				}
			}
		}
	}
	
	CGFloat screenScale = [UIScreen mainScreen].scale;
	for (NSNumber *scale in [NSArray arrayWithObjects:[NSNumber numberWithFloat:screenScale], [NSNumber numberWithFloat:screenScale > 1 ? 1 : 2], nil])
	{
		for (UIImage *icon in icons)
		{
			CGFloat iconSize = (self.iPhone ? 57 : 72) * [scale floatValue];
			if (CGSizeEqualToSize(icon.size, CGSizeMake(iconSize, iconSize)))
			{
				_appIcon = [icon retain];
				break;
			}
		}
		if (_appIcon)
			break;
	}
	
	if (LICreateIconForImage && _appIcon)
	{
		CGFloat scale = _appIcon.scale;
		CGImageRef icon = LICreateIconForImage(_appIcon.CGImage, 15, [[self.infoPlist objectForKey:@"UIPrerenderedIcon"] boolValue] ? 2 : 0);
		[_appIcon release];
		_appIcon = [[UIImage alloc] initWithCGImage:icon scale:scale orientation:UIImageOrientationUp];
		CGImageRelease(icon);
	}
	
	if (!_appIcon)
		_appIcon = [[UIImage imageNamed:@"Unknown.png"] retain];
	
	return _appIcon;
}

- (NSArray *) imageNames
{
	if (_imageNames)
		return _imageNames;
	
	_imageNames = [[NSMutableArray alloc] init];
	for (ZKCDHeader *header in self.ipa.centralDirectory)
	{
		if ([header.filename hasSuffix:@"png"])
			[(NSMutableArray*)_imageNames addObject:header.filename];
	}
	
	return _imageNames;
}

- (UIImage *) imageNamed:(NSString *)imageName
{
	UIImage *image = nil;
	
	for (ZKCDHeader *header in self.ipa.centralDirectory)
	{
		if ([header.filename isEqualToString:imageName])
		{
			NSDictionary *attributes = nil;
			NSData *imageData = [self.ipa inflateFile:header attributes:&attributes];
			CGDataProviderRef source = CGDataProviderCreateWithCFData((CFDataRef)imageData);
			CGImageRef imageRef = CGImageCreateWithPNGDataProvider(source, NULL, false, kCGRenderingIntentDefault);
			CGFloat scale;
			if ([[imageName lowercaseString] rangeOfString:@"@2x"].location != NSNotFound) {
				scale = 2;
			} else if ([[imageName lowercaseString] rangeOfString:@"@3x"].location != NSNotFound) {
				scale = 3;
			} else {
				scale = 1;
			}
			image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
			CGImageRelease(imageRef);
			CGDataProviderRelease(source);
			break;
		}
	}
	
	return image;
}

- (BOOL) iPhone
{
	NSArray *deviceFamily = [[self infoPlist] objectForKey:@"UIDeviceFamily"];
	return [deviceFamily containsObject:[NSNumber numberWithInteger:1]] || deviceFamily == nil;
}

- (BOOL) iPad
{
	return [[[self infoPlist] objectForKey:@"UIDeviceFamily"] containsObject:[NSNumber numberWithInteger:2]];
}

- (ZKDataArchive *) ipa
{
	if (!_ipa)
		_ipa = [[ZKDataArchive archiveWithArchivePath:self.path] retain];
	
	return _ipa;
}

- (void) unload
{
	[self appIcon];
	[self metadata];
	[self infoPlist];
	self.ipa = nil;
}

@end
