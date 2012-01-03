//
//  NSFileManager+ZKAdditions.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "NSFileManager+ZKAdditions.h"
#import "NSData+ZKAdditions.h"
#import "NSDictionary+ZKAdditions.h"

#if ZK_TARGET_OS_MAC
#import "GMAppleDouble+ZKAdditions.h"
#endif

const NSUInteger ZKMaxEntriesPerFetch = 40;

@implementation  NSFileManager (ZKAdditions)

- (BOOL) zk_isSymLinkAtPath:(NSString *) path {
	return [[[self attributesOfItemAtPath:path error:nil] fileType] isEqualToString:NSFileTypeSymbolicLink];
}

- (BOOL) zk_isDirAtPath:(NSString *) path {
	BOOL isDir;
	BOOL pathExists = [self fileExistsAtPath:path isDirectory:&isDir];
	return pathExists && isDir;
}

- (unsigned long long) zk_dataSizeAtFilePath:(NSString *) path {
	return [[self attributesOfItemAtPath:path error:nil] fileSize];
}

#if ZK_TARGET_OS_MAC
- (void) totalsAtDirectoryFSRef:(FSRef*) fsRef usingResourceFork:(BOOL) rfFlag
					  totalSize:(unsigned long long *) size
					  itemCount:(unsigned long long *) count {
	FSIterator iterator;
	OSErr fsErr = FSOpenIterator(fsRef, kFSIterateFlat, &iterator);
	if (fsErr == noErr) {
		ItemCount actualFetched;
		FSRef fetchedRefs[ZKMaxEntriesPerFetch];
		FSCatalogInfo fetchedInfos[ZKMaxEntriesPerFetch];
		while (fsErr == noErr) {
			fsErr = FSGetCatalogInfoBulk(iterator, ZKMaxEntriesPerFetch, &actualFetched, NULL,
										 kFSCatInfoDataSizes | kFSCatInfoRsrcSizes | kFSCatInfoNodeFlags,
										 fetchedInfos, fetchedRefs, NULL, NULL);
			if ((fsErr == noErr) || (fsErr == errFSNoMoreItems)) {
				(*count) += actualFetched;
				for (ItemCount i = 0; i < actualFetched; i++) {
					if (fetchedInfos[i].nodeFlags & kFSNodeIsDirectoryMask)
						[self totalsAtDirectoryFSRef:&fetchedRefs[i] usingResourceFork:rfFlag totalSize:size itemCount:count];
					else
						(*size) += fetchedInfos [i].dataLogicalSize + (rfFlag ? fetchedInfos [i].rsrcLogicalSize : 0);
				}
			}
		}
		FSCloseIterator(iterator);
	}
	return ;
}
#endif

- (NSDictionary *) zkTotalSizeAndItemCountAtPath:(NSString *) path usingResourceFork:(BOOL) rfFlag {
	unsigned long long size = 0;
	unsigned long long count = 0;
#if ZK_TARGET_OS_MAC
	FSRef fsRef;
	Boolean isDirectory;
	OSStatus status = FSPathMakeRef((const unsigned char*)[path fileSystemRepresentation], &fsRef, &isDirectory);
	if (status != noErr)
		return nil;
	if (isDirectory) {
		[self totalsAtDirectoryFSRef:&fsRef usingResourceFork:rfFlag totalSize:&size itemCount:&count];
	} else {
		count = 1;
		FSCatalogInfo info;
		OSErr fsErr = FSGetCatalogInfo(&fsRef, kFSCatInfoDataSizes | kFSCatInfoRsrcSizes, &info, NULL, NULL, NULL);
		if (fsErr == noErr)
			size = info.dataLogicalSize + (rfFlag ? info.rsrcLogicalSize : 0);
	}
#else
	// TODO: maybe fix this for non-Mac targets
	size = 0;
	count = 0;
#endif
	return [NSDictionary zk_totalSizeAndCountDictionaryWithSize:size andItemCount:count];
}

#if ZK_TARGET_OS_MAC
- (void) zk_combineAppleDoubleInDirectory:(NSString *) path {
	if (![self zk_isDirAtPath:path])
		return;
	NSArray *dirContents = [self contentsOfDirectoryAtPath:path error:nil];
	for (NSString *entry in dirContents) {
		NSString *subPath = [path stringByAppendingPathComponent:entry];
		if (![self zk_isSymLinkAtPath:subPath]) {
			if ([self zk_isDirAtPath:subPath])
				[self zk_combineAppleDoubleInDirectory:subPath];
			else {
				// if the file is an AppleDouble file (i.e., it begins with "._") in the __MACOSX hierarchy,
				// find its corresponding data fork and combine them
				if ([subPath rangeOfString:ZKMacOSXDirectory].location != NSNotFound) {
					NSString *fileName = [subPath lastPathComponent];
					NSRange ZKDotUnderscoreRange = [fileName rangeOfString:ZKDotUnderscore];
					if (ZKDotUnderscoreRange.location == 0 && ZKDotUnderscoreRange.length == 2) {
						NSMutableArray *pathComponents =
						(NSMutableArray *)[[[subPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:
											[fileName substringFromIndex:2]] pathComponents];
						for (NSString *pathComponent in pathComponents) {
							if ([ZKMacOSXDirectory isEqualToString:pathComponent]) {
								[pathComponents removeObject:pathComponent];
								break;
							}
						}
						NSData *appleDoubleData = [NSData dataWithContentsOfFile:subPath];
						[GMAppleDouble zk_restoreAppleDoubleData:appleDoubleData toPath:[NSString pathWithComponents:pathComponents]];
					}
				}
			}
		}
	}
}
#endif

- (NSDate *) zk_modificationDateForPath:(NSString *) path {
	return [[self attributesOfItemAtPath:path error:nil] fileModificationDate];
}

- (NSUInteger) zk_posixPermissionsAtPath:(NSString *) path {
	return [[self attributesOfItemAtPath:path error:nil] filePosixPermissions];
}

- (NSUInteger) zk_externalFileAttributesAtPath:(NSString *) path {
	return [self zk_externalFileAttributesFor:[self attributesOfItemAtPath:path error:nil]];
}

- (NSUInteger) zk_externalFileAttributesFor:(NSDictionary *) fileAttributes {
	NSUInteger externalFileAttributes = 0;
	@try {
		BOOL isSymLink = [[fileAttributes fileType] isEqualToString:NSFileTypeSymbolicLink];
		BOOL isDir = [[fileAttributes fileType] isEqualToString:NSFileTypeDirectory];
		NSUInteger posixPermissions = [fileAttributes filePosixPermissions];
		externalFileAttributes = posixPermissions << 16 | (isSymLink ? 0xA0004000 : (isDir ? 0x40004000 : 0x80004000));
	} @catch(NSException * e) {
		externalFileAttributes = 0;
	}
	return externalFileAttributes;
}

- (NSUInteger) zk_crcForPath:(NSString *) path {
	return [self zk_crcForPath:path invoker:nil throttleThreadSleepTime:0.0];
}

- (NSUInteger) zk_crcForPath:(NSString *) path invoker:(id)invoker {
	return [self zk_crcForPath:path invoker:invoker throttleThreadSleepTime:0.0];
}

- (NSUInteger) zk_crcForPath:(NSString *)path invoker:(id)invoker throttleThreadSleepTime:(NSTimeInterval) throttleThreadSleepTime {
	NSUInteger crc32 = 0;
	path = [path stringByExpandingTildeInPath];
	BOOL isDirectory;
	if ([self fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory) {
		BOOL irtsIsCancelled = [invoker respondsToSelector:@selector(isCancelled)];
		const NSUInteger crcBlockSize = 1048576;
		NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
		NSData *block = [fileHandle readDataOfLength:crcBlockSize] ;
		while ([block length] > 0) {
			crc32 = [block zk_crc32:crc32];
			if (irtsIsCancelled) {
				if ([invoker isCancelled]) {
					[fileHandle closeFile];
					return 0;
				}
			}
			block = [fileHandle readDataOfLength:crcBlockSize];
			[NSThread sleepForTimeInterval:throttleThreadSleepTime];
		}
		[fileHandle closeFile];
	} else
		crc32 = 0;
	return crc32;
}

@end
