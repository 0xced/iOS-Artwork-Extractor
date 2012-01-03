//
//  IPAArchive.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 30.12.11.
//  Copyright (c) 2011 Cédric Luthi. All rights reserved.
//

#import "IPAArchive.h"

#import "ZKCDHeader.h"
#import "ZKDataArchive.h"

@interface IPAArchive ()
@property (nonatomic, readwrite, retain) UIImage *appIcon;
@property (nonatomic, readwrite, retain) NSArray *imageNames;

@property (nonatomic, retain) ZKDataArchive *ipa;
@property (nonatomic, retain) NSDictionary *metadata;
@property (nonatomic, retain) NSDictionary *infoPlist;
@end


@implementation IPAArchive

@synthesize ipa = _ipa;
@synthesize metadata = _metadata;
@synthesize infoPlist = _infoPlist;
@synthesize appIcon = _appIcon;
@synthesize imageNames = _imageNames;

- (id) initWithPath:(NSString *)ipaPath;
{
	if (!(self = [super init]))
		return nil;
	
	self.ipa = [ZKDataArchive archiveWithArchivePath:ipaPath];
	
	return self;
}

- (void) dealloc
{
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
		if ([header.filename hasSuffix:@"Info.plist"] && [[header.filename componentsSeparatedByString:@"/"] count] == 3)
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
		bundleIconFiles = [NSArray arrayWithObject:[self.infoPlist objectForKey:@"CFBundleIconFile"] ?: @"Icon.png"];
	
	NSMutableArray *icons = [NSMutableArray array];
	for (NSString *iconFile in bundleIconFiles)
	{
		for (ZKCDHeader *header in self.ipa.centralDirectory)
		{
			if ([header.filename hasSuffix:iconFile] && [[header.filename componentsSeparatedByString:@"/"] count] == 3)
			{
				NSDictionary *attributes = nil;
				NSData *iconData = [self.ipa inflateFile:header attributes:&attributes];
				UIImage *icon = [UIImage imageWithData:iconData];
				[icons addObject:icon];
				break;
			}
		}
	}
	
	for (UIImage *icon in icons)
	{
		CGFloat iconSize = 57 * [UIScreen mainScreen].scale;
		if (CGSizeEqualToSize(icon.size, CGSizeMake(iconSize, iconSize)))
		{
			_appIcon = [icon retain];
			break;
		}
	}
	
	if (!_appIcon)
		_appIcon = [[icons lastObject] retain];
	
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
			image = [UIImage imageWithData:imageData];
			break;
		}
	}
	
	return image;
}

@end
