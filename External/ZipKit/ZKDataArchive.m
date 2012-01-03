//
//  ZKDataArchive.m
//  ZipKit
//
//  Created by Karl Moskowski on 07/05/09.
//

#import "ZKDataArchive.h"
#import "ZKCDHeader.h"
#import "ZKCDTrailer.h"
#import "ZKLFHeader.h"
#import "NSData+ZKAdditions.h"
#import "NSFileManager+ZKAdditions.h"
#import "NSString+ZKAdditions.h"
#import "ZKDefs.h"
#import "zlib.h"

#if ZK_TARGET_OS_MAC
#import "GMAppleDouble+ZKAdditions.h"
#endif

@implementation ZKDataArchive

+ (ZKDataArchive *) archiveWithArchivePath:(NSString *) path {
	return [self archiveWithArchiveData:[NSMutableData dataWithContentsOfFile:path]];
}

+ (ZKDataArchive *) archiveWithArchiveData:(NSMutableData *) archiveData {
	ZKDataArchive *archive = [[ZKDataArchive new] autorelease];
	archive.data = archiveData;
	archive.cdTrailer = [ZKCDTrailer recordWithData:archive.data];
	if (archive.cdTrailer) {
		unsigned long long offset = archive.cdTrailer.offsetOfStartOfCentralDirectory;
		for (NSUInteger i = 0; i < archive.cdTrailer.totalNumberOfCentralDirectoryEntries; i++) {
			ZKCDHeader *cdHeader = [ZKCDHeader recordWithData:archive.data atOffset:offset];
			[archive.centralDirectory addObject:cdHeader];
			offset += [cdHeader length];
		}
	} else {
		archive = nil;
	}
	return archive;
}

#pragma mark -
#pragma mark Inflation

- (NSUInteger) inflateAll {
	[self.inflatedFiles removeAllObjects];
	NSDictionary *fileAttributes = nil;
	NSData *inflatedData = nil;
	for (ZKCDHeader *cdHeader in self.centralDirectory) {
		inflatedData = [self inflateFile:cdHeader attributes:&fileAttributes];
		if (!inflatedData)
			return zkFailed;
		
		if ([cdHeader isSymLink] || [cdHeader isDirectory]) {
			[self.inflatedFiles addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										   fileAttributes, ZKFileAttributesKey,
										   [[[NSString alloc] initWithData:inflatedData encoding:NSUTF8StringEncoding] autorelease], ZKPathKey,
										   nil]];
		} else {
			[self.inflatedFiles addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										   inflatedData, ZKFileDataKey,
										   fileAttributes, ZKFileAttributesKey,
										   cdHeader.filename, ZKPathKey,
										   nil]];
		}
	}
	return zkSucceeded;
}

- (NSData *) inflateFile:(ZKCDHeader *) cdHeader attributes:(NSDictionary **) fileAttributes {
	//	if (self.delegate) {
	//		if ([NSThread isMainThread])
	//			[self willUnzipPath:cdHeader.filename];
	//		else
	//			[self performSelectorOnMainThread:@selector(willUnzipPath:) withObject:cdHeader.filename waitUntilDone:NO];
	//	}
	BOOL isDirectory = [cdHeader isDirectory];
	
	ZKLFHeader *lfHeader = [ZKLFHeader recordWithData:self.data atOffset:cdHeader.localHeaderOffset];
	
	NSData *deflatedData = nil;
	if (!isDirectory)
		deflatedData = [self.data subdataWithRange:
						NSMakeRange(cdHeader.localHeaderOffset + [lfHeader length], cdHeader.compressedSize)];
	
	NSData *inflatedData = nil;
	NSString *fileType = nil;
	if ([cdHeader isSymLink]) {
		inflatedData = deflatedData; // UTF-8 encoded symlink destination path
		fileType = NSFileTypeSymbolicLink;
	} else if (isDirectory) {
		inflatedData = [cdHeader.filename dataUsingEncoding:NSUTF8StringEncoding];
		fileType = NSFileTypeDirectory;
	} else {
		if (cdHeader.compressionMethod == Z_NO_COMPRESSION)
			inflatedData = deflatedData;
		else
			inflatedData = [deflatedData zk_inflate];
		fileType = NSFileTypeRegular;
	}
	
	if (inflatedData)
		*fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
						   [cdHeader posixPermissions], NSFilePosixPermissions,
						   [cdHeader lastModDate], NSFileCreationDate,
						   [cdHeader lastModDate], NSFileModificationDate,
						   fileType, NSFileType, nil];
	else
		*fileAttributes = nil;
	
	return inflatedData;
}

- (NSUInteger) inflateInFolder:(NSString *)enclosingFolder withFolderName:(NSString *)folderName usingResourceFork:(BOOL) rfFlag {
	if ([self inflateAll] != zkSucceeded)
		return zkFailed;
	if ([self.inflatedFiles count] < 1)
		return zkSucceeded;
	
	if (![self.fileManager fileExistsAtPath:enclosingFolder])
		return zkFailed;
	
	NSString *expansionDirectory = [self uniqueExpansionDirectoryIn:enclosingFolder];
	[self.fileManager createDirectoryAtPath:expansionDirectory withIntermediateDirectories:YES attributes:nil error:nil];
	for (NSDictionary *file in self.inflatedFiles) {
		NSDictionary *fileAttributes = [file objectForKey:ZKFileAttributesKey];
		NSData *inflatedData = [file objectForKey:ZKFileDataKey];
		NSString *path = [expansionDirectory stringByAppendingPathComponent:[file objectForKey:ZKPathKey]];
		[self.fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent]
					withIntermediateDirectories:YES attributes:nil error:nil];
		if ([[fileAttributes fileType] isEqualToString:NSFileTypeRegular])
			[inflatedData writeToFile:path atomically:YES];
		else if ([[fileAttributes fileType] isEqualToString:NSFileTypeDirectory])
			[self.fileManager createDirectoryAtPath:path
						withIntermediateDirectories:YES attributes:nil error:nil];
		else if ([[fileAttributes fileType] isEqualToString:NSFileTypeSymbolicLink]) {
			NSString *symLinkDestinationPath = [[[NSString alloc] initWithData:inflatedData
																	 encoding:NSUTF8StringEncoding] autorelease];
			[self.fileManager createSymbolicLinkAtPath:path
								   withDestinationPath:symLinkDestinationPath error:nil];
		}
		[self.fileManager setAttributes:fileAttributes ofItemAtPath:path error:nil]; 
	}

#if ZK_TARGET_OS_MAC
	if (rfFlag)
		[self.fileManager zk_combineAppleDoubleInDirectory:expansionDirectory];
#endif
	[self cleanUpExpansionDirectory:expansionDirectory];

	return zkSucceeded;
}



#pragma mark -
#pragma mark Deflation

- (NSInteger) deflateFiles:(NSArray *) paths relativeToPath:(NSString *) basePath usingResourceFork:(BOOL) rfFlag {
	NSInteger rc = zkSucceeded;
	for (NSString *path in paths) {
		if ([self.fileManager zk_isDirAtPath:path] && ![self.fileManager zk_isSymLinkAtPath:path]) {
			rc = [self deflateDirectory:path relativeToPath:basePath usingResourceFork:rfFlag];
			if (rc != zkSucceeded)
				break;
		} else {
			rc = [self deflateFile:path relativeToPath:basePath usingResourceFork:rfFlag];
			if (rc != zkSucceeded)
				break;
		}
	}
	return rc;
}

- (NSInteger) deflateDirectory:(NSString *) dirPath relativeToPath:(NSString *) basePath usingResourceFork:(BOOL) rfFlag {
	NSInteger rc = [self deflateFile:dirPath relativeToPath:basePath usingResourceFork:rfFlag];
	if (rc == zkSucceeded) {
		NSDirectoryEnumerator *e = [self.fileManager enumeratorAtPath:dirPath];
		for (NSString *path in e) {
			rc = [self deflateFile:[dirPath stringByAppendingPathComponent:path] relativeToPath:basePath usingResourceFork:rfFlag];
			if (rc != zkSucceeded)
				break;
		}
	}
	return rc;
}

- (NSInteger) deflateFile:(NSString *) path relativeToPath:(NSString *) basePath usingResourceFork:(BOOL) rfFlag {
	BOOL isDir = [self.fileManager zk_isDirAtPath:path];
	BOOL isSymlink = [self.fileManager zk_isSymLinkAtPath:path];
	BOOL isFile = (!isSymlink && !isDir);
	
	//	if (self.delegate) {
	//		if ([NSThread isMainThread])
	//			[self willZipPath:path];
	//		else
	//			[self performSelectorOnMainThread:@selector(willZipPath:) withObject:path waitUntilDone:NO];
	//	}
	
	// append a trailing slash to directory paths
	if (isDir && !isSymlink && ![[path substringFromIndex:([path length] - 1)] isEqualToString:@"/"])
		path = [path stringByAppendingString:@"/"];
	
	// construct a relative path for storage in the archive directory by removing basePath from the beginning of path
	NSString *relativePath = path;
	if (basePath && [basePath length] > 0) {
		if (![basePath hasSuffix:@"/"])
			basePath = [basePath stringByAppendingString:@"/"];
		NSRange r = [path rangeOfString:basePath];
		if (r.location != NSNotFound)
			relativePath = [path substringFromIndex:r.length];
	}
	
	if (isFile) {
		NSData *fileData = [NSData dataWithContentsOfFile:path];
		NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:path error:nil];
		NSInteger rc = [self deflateData:fileData withFilename:relativePath andAttributes:fileAttributes];
#if ZK_TARGET_OS_MAC
		if (rc == zkSucceeded && rfFlag) {
			NSData *appleDoubleData = [GMAppleDouble zk_appleDoubleDataForPath:path];
			if (appleDoubleData) {
				NSString *appleDoublePath = [[ZKMacOSXDirectory stringByAppendingPathComponent:
											  [relativePath stringByDeletingLastPathComponent]]
											 stringByAppendingPathComponent:
											 [ZKDotUnderscore stringByAppendingString:[relativePath lastPathComponent]]];
				rc = [self deflateData:appleDoubleData withFilename:appleDoublePath andAttributes:fileAttributes];
			}
		}
#endif
		return rc;
	}
	
	// create the local file header for the file
	ZKLFHeader *lfHeaderData = [[ZKLFHeader new] autorelease];
	lfHeaderData.uncompressedSize = 0;
	lfHeaderData.lastModDate = [self.fileManager zk_modificationDateForPath:path];
	lfHeaderData.filename = relativePath;
	lfHeaderData.filenameLength = [lfHeaderData.filename zk_precomposedUTF8Length];
	lfHeaderData.crc = 0;
	lfHeaderData.compressedSize = 0;
	
	// remove the existing central directory from the data
	unsigned long long lfHeaderDataOffset = self.cdTrailer.offsetOfStartOfCentralDirectory;
	[self.data setLength:lfHeaderDataOffset];
	
	if (isSymlink) {
		NSString *symlinkPath = [self.fileManager destinationOfSymbolicLinkAtPath:path error:nil];
		NSData *symlinkData = [symlinkPath dataUsingEncoding:NSUTF8StringEncoding];
		lfHeaderData.crc = [symlinkData zk_crc32];
		lfHeaderData.compressedSize = [symlinkData length];
		lfHeaderData.uncompressedSize = [symlinkData length];
		lfHeaderData.compressionMethod = Z_NO_COMPRESSION;
		lfHeaderData.versionNeededToExtract = 10;
		[self.data appendData:[lfHeaderData data]];
		[self.data appendData:symlinkData];
	} else if (isDir) {
		lfHeaderData.crc = 0;
		lfHeaderData.compressedSize = 0;
		lfHeaderData.uncompressedSize = 0;
		lfHeaderData.compressionMethod = Z_NO_COMPRESSION;
		lfHeaderData.versionNeededToExtract = 10;
		[self.data appendData:[lfHeaderData data]];
	}
	
	// create the central directory header and add it to central directory
	ZKCDHeader *cdHeaderData = [[ZKCDHeader new] autorelease];
	cdHeaderData.uncompressedSize = lfHeaderData.uncompressedSize;
	cdHeaderData.lastModDate = lfHeaderData.lastModDate;
	cdHeaderData.crc = lfHeaderData.crc;
	cdHeaderData.compressedSize = lfHeaderData.compressedSize;
	cdHeaderData.filename = lfHeaderData.filename;
	cdHeaderData.filenameLength = lfHeaderData.filenameLength;
	cdHeaderData.localHeaderOffset = lfHeaderDataOffset;
	cdHeaderData.compressionMethod = lfHeaderData.compressionMethod;
	cdHeaderData.generalPurposeBitFlag = lfHeaderData.generalPurposeBitFlag;
	cdHeaderData.versionNeededToExtract = lfHeaderData.versionNeededToExtract;
	cdHeaderData.externalFileAttributes = [self.fileManager zk_externalFileAttributesAtPath:path];
	[self.centralDirectory addObject:cdHeaderData];
	
	// update the central directory trailer
	self.cdTrailer.numberOfCentralDirectoryEntriesOnThisDisk++;
	self.cdTrailer.totalNumberOfCentralDirectoryEntries++;
	self.cdTrailer.sizeOfCentralDirectory += [cdHeaderData length];
	
	self.cdTrailer.offsetOfStartOfCentralDirectory = [self.data length];
	for (ZKCDHeader *cdHeader in self.centralDirectory)
		[self.data appendData:[cdHeader data]];
	
	[self.data appendData:[self.cdTrailer data]];
	
	return zkSucceeded;
}

- (NSInteger) deflateData:(NSData *)data withFilename:(NSString *) filename andAttributes:(NSDictionary *) fileAttributes {
	if (!filename || [filename length] < 1)
		return zkFailed;
	
	NSData *deflatedData = [data zk_deflate];
	if (!deflatedData)
		return zkFailed;
	
	unsigned long long lfHeaderDataOffset = self.cdTrailer.offsetOfStartOfCentralDirectory;
	[self.data setLength:lfHeaderDataOffset];
	
	ZKLFHeader *lfHeaderData = [[ZKLFHeader new] autorelease];
	lfHeaderData.uncompressedSize = [data length];
	lfHeaderData.filename = filename;
	lfHeaderData.filenameLength = [lfHeaderData.filename zk_precomposedUTF8Length];
	lfHeaderData.crc = [data zk_crc32];
	lfHeaderData.compressedSize = [deflatedData length];
	
	ZKCDHeader *cdHeaderData = [[ZKCDHeader new] autorelease];
	cdHeaderData.uncompressedSize = lfHeaderData.uncompressedSize;
	cdHeaderData.crc = lfHeaderData.crc;
	cdHeaderData.compressedSize = lfHeaderData.compressedSize;
	cdHeaderData.filename = lfHeaderData.filename;
	cdHeaderData.filenameLength = lfHeaderData.filenameLength;
	cdHeaderData.localHeaderOffset = lfHeaderDataOffset;
	cdHeaderData.compressionMethod = lfHeaderData.compressionMethod;
	cdHeaderData.generalPurposeBitFlag = lfHeaderData.generalPurposeBitFlag;
	cdHeaderData.versionNeededToExtract = lfHeaderData.versionNeededToExtract;
	[self.centralDirectory addObject:cdHeaderData];
	
	self.cdTrailer.numberOfCentralDirectoryEntriesOnThisDisk++;
	self.cdTrailer.totalNumberOfCentralDirectoryEntries++;
	self.cdTrailer.sizeOfCentralDirectory += [cdHeaderData length];
	
	if (fileAttributes) {
		if ([[fileAttributes allKeys] containsObject:NSFileModificationDate]) {
			lfHeaderData.lastModDate = [fileAttributes objectForKey:NSFileModificationDate];
			cdHeaderData.lastModDate = lfHeaderData.lastModDate;
		}
		cdHeaderData.externalFileAttributes = [self.fileManager zk_externalFileAttributesFor:fileAttributes];
	}
	
	[self.data appendData:[lfHeaderData data]];
	[self.data appendData:deflatedData];
	
	self.cdTrailer.offsetOfStartOfCentralDirectory = [self.data length];
	for (ZKCDHeader *cdHeader in self.centralDirectory)
		[self.data appendData:[cdHeader data]];
	
	[self.data appendData:[self.cdTrailer data]];
	
	return zkSucceeded;
}

#pragma mark -
#pragma mark Setup

- (id) init {
	if (self = [super init]) {
		self.data = [NSMutableData data];
		self.inflatedFiles = [NSMutableArray array];
	}
	return self;
}

- (void) dealloc {
	self.data = nil;
	self.inflatedFiles = nil;
	[super dealloc];
}

- (void) finalize {
	self.data = nil;
	[self.inflatedFiles removeAllObjects];
	self.inflatedFiles = nil;
	[super finalize];
}

@synthesize data = _data, inflatedFiles = _inflatedFiles;

@end