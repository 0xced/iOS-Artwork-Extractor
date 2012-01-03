//
//  NSString+ZKAdditions.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "NSString+ZKAdditions.h"
#import "ZKDefs.h"

@implementation NSString (ZKAdditions)

- (NSUInteger) zk_precomposedUTF8Length {
	return [[self precomposedStringWithCanonicalMapping] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL) zk_isResourceForkPath {
	return [[[self pathComponents] objectAtIndex:0] isEqualToString:ZKMacOSXDirectory];
}


@end