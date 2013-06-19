//
//  NSString+IPAArchive.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 09.01.12.
//  Copyright (c) 2012 Cédric Luthi. All rights reserved.
//

#import "NSString+IPAArchive.h"

@implementation NSString (IPAArchive)

- (NSString *) appName
{
	return [[self lastPathComponent] stringByDeletingPathExtension];
}

@end
