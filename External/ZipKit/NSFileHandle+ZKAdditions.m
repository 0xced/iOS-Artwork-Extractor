//
//  NSFileHandle+ZKAdditions.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "NSFileHandle+ZKAdditions.h"

@implementation NSFileHandle (ZKAdditions)

+ (NSFileHandle *)zk_newFileHandleForWritingAtPath:(NSString *)path {
	NSFileManager *fm = [NSFileManager new];
	if (![fm fileExistsAtPath:path]) {
		[fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		[fm createFileAtPath:path contents:nil attributes:nil];
	}
	NSFileHandle *fileHandle = [self fileHandleForWritingAtPath:path];
    [fm release];
    return fileHandle;
}

@end