//
//  ZKFileArchive.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "ZKFileArchive.h"
#import "ZKCDHeader.h"
#import "ZKCDTrailer.h"
#import "ZKCDTrailer64.h"
#import "ZKCDTrailer64Locator.h"
#import "ZKLFHeader.h"
#import "ZKLog.h"
#import "NSData+ZKAdditions.h"
#import "NSDictionary+ZKAdditions.h"
#import "NSFileHandle+ZKAdditions.h"
#import "NSFileManager+ZKAdditions.h"
#import "NSString+ZKAdditions.h"
#import "ZKDefs.h"
#import "zlib.h"

#if ZK_TARGET_OS_MAC
#import "GMAppleDouble+ZKAdditions.h"
#endif

@implementation ZKFileArchive

/*
 rfFlag indicates whether the AppleDouble'd resource fork should be processed (like Mac OS X's Archive Utility); it's ignored when using building for iPhoneOS

 invoker should be an object that responds to isCancelled (e.g., NSOperation) so processing can be cancelled

 delegate should be an object that responds to one or more of the messages in the above category to display progress (see the Application or Tool targets for examples)
 */

+ (ZKFileArchive *) process:(id)item usingResourceFork:(BOOL)rfFlag withInvoker:(id)invoker andDelegate:(id)delegate {
	ZKFileArchive *archive = nil;

	if ([item isKindOfClass:[NSArray class]])
		if ([item count] == 1)
			item = [item objectAtIndex:0];

	if ([item isKindOfClass:[NSString class]]) {
		NSString *path = (NSString *)item;
		if ([self validArchiveAtPath:path]) {
			archive = [self archiveWithArchivePath:path];
			if (!archive)
				return nil;
			archive.invoker = invoker;
			if (delegate) {
				archive.delegate = delegate;
				if ([archive delegateWantsSizes]) {
					if ([NSThread isMainThread]) {
						[archive didUpdateTotalSize:[archive.centralDirectory valueForKeyPath:@"@sum.uncompressedSize"]];
						[archive didUpdateTotalCount:[NSNumber numberWithUnsignedLongLong:[archive.centralDirectory count]]];
					} else {
						[archive performSelectorOnMainThread:@selector(didUpdateTotalSize:)
												  withObject:[archive.centralDirectory valueForKeyPath:@"@sum.uncompressedSize"]
											   waitUntilDone:NO];
						[archive performSelectorOnMainThread:@selector(didUpdateTotalCount:)
												  withObject:[NSNumber numberWithUnsignedLongLong:[archive.centralDirectory count]]
											   waitUntilDone:NO];
					}
				}
				if ([NSThread isMainThread])
					[archive didBeginUnzip];
				else
					[archive performSelectorOnMainThread:@selector(didBeginUnzip) withObject:nil waitUntilDone:NO];
			}

			NSInteger result = [archive inflateToDiskUsingResourceFork:rfFlag];
			if (result == zkSucceeded) {
				if (archive.delegate) {
					if ([NSThread isMainThread])
						[archive didEndUnzip];
					else
						[archive performSelectorOnMainThread:@selector(didEndUnzip) withObject:nil waitUntilDone:NO];
				}
			} else if (result == zkCancelled) {
				if (archive.delegate) {
					if ([NSThread isMainThread])
						[archive didCancel];
					else
						[archive performSelectorOnMainThread:@selector(didCancel) withObject:nil waitUntilDone:NO];
				}
			} else if (result == zkFailed) {
				if (archive.delegate) {
					if ([NSThread isMainThread])
						[archive didFail];
					else
						[archive performSelectorOnMainThread:@selector(didFail) withObject:nil waitUntilDone:NO];
				}
			}
		} else {
			NSString *archivePath = [self uniquify:[[path stringByDeletingPathExtension]
			                                        stringByAppendingPathExtension:ZKArchiveFileExtension]];
			archive = [self archiveWithArchivePath:archivePath];
			if (!archive)
				return nil;
			archive.invoker = invoker;
			if (delegate) {
				archive.delegate = delegate;
				[NSThread detachNewThreadSelector:@selector(calculateSizeAndItemCount:) toTarget:archive
									   withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:path], ZKPathsKey,
												   [NSNumber numberWithBool:rfFlag], ZKusingResourceForkKey, nil]];
				if ([NSThread isMainThread])
					[archive didBeginZip];
				else
					[archive performSelectorOnMainThread:@selector(didBeginZip) withObject:nil waitUntilDone:NO];
			}
			NSInteger result = zkSucceeded;
			if ([archive.fileManager zk_isDirAtPath:path] && ![archive.fileManager zk_isSymLinkAtPath:path])
				result = [archive deflateDirectory:path relativeToPath:[path stringByDeletingLastPathComponent] usingResourceFork:rfFlag];
			else
				result = [archive deflateFile:path relativeToPath:[path stringByDeletingLastPathComponent] usingResourceFork:rfFlag];
			if (result == zkSucceeded) {
				if (archive.delegate) {
					if ([NSThread isMainThread])
						[archive didEndZip];
					else
						[archive performSelectorOnMainThread:@selector(didEndZip) withObject:nil waitUntilDone:NO];
				}
			} else if (result == zkCancelled) {
				[archive.fileManager removeItemAtPath:archivePath error:nil];
				if (archive.delegate)
					[archive performSelectorOnMainThread:@selector(didCancel) withObject:nil waitUntilDone:NO];
			} else if (result == zkFailed) {
				[archive.fileManager removeItemAtPath:archivePath error:nil];
				if (archive.delegate) {
					if ([NSThread isMainThread])
						[archive didFail];
					else
						[archive performSelectorOnMainThread:@selector(didFail) withObject:nil waitUntilDone:NO];
				}
			}
		}
	} else if ([item isKindOfClass:[NSArray class]]) {
		NSArray *paths = item;
		NSString *firstPath = [paths objectAtIndex:0];
		NSString *basePath = [firstPath stringByDeletingLastPathComponent];
		NSString *archiveName = [NSLocalizedString(@"Archive", @"default archive filename")
		                         stringByAppendingPathExtension:ZKArchiveFileExtension];
		NSString *archivePath = [self uniquify:[basePath stringByAppendingPathComponent:archiveName]];
		archive = [self archiveWithArchivePath:archivePath];
		if (!archive)
			return nil;
		archive.invoker = invoker;
		if (delegate) {
			archive.delegate = delegate;
			[NSThread detachNewThreadSelector:@selector(calculateSizeAndItemCount:) toTarget:archive
								   withObject:[NSDictionary dictionaryWithObjectsAndKeys:paths, ZKPathsKey,
											   [NSNumber numberWithBool:rfFlag], ZKusingResourceForkKey, nil]];
			if ([NSThread isMainThread])
				[archive didBeginZip];
			else
				[archive performSelectorOnMainThread:@selector(didBeginZip) withObject:nil waitUntilDone:NO];
		}
		NSInteger result = [archive deflateFiles:paths relativeToPath:basePath usingResourceFork:rfFlag];
		if (result == zkSucceeded) {
			if (archive.delegate) {
				if ([NSThread isMainThread])
					[archive didEndZip];
				else
					[archive performSelectorOnMainThread:@selector(didEndZip) withObject:nil waitUntilDone:NO];
			}
		} else if (result == zkCancelled) {
			[archive.fileManager removeItemAtPath:archivePath error:nil];
			if (archive.delegate)
				[archive performSelectorOnMainThread:@selector(didCancel) withObject:nil waitUntilDone:NO];
		} else if (result == zkFailed) {
			[archive.fileManager removeItemAtPath:archivePath error:nil];
			if (archive.delegate) {
				if ([NSThread isMainThread])
					[archive didFail];
				else
					[archive performSelectorOnMainThread:@selector(didFail) withObject:nil waitUntilDone:NO];
			}
		}
	} else
		ZKLogError(@"Skipping %@ - not a NSString or NSArray", item);
	return archive;
}

+ (ZKFileArchive *) archiveWithArchivePath:(NSString *)path {
	ZKFileArchive *archive = [[ZKFileArchive new] autorelease];
	archive.archivePath = path;
	if ([archive.fileManager fileExistsAtPath:archive.archivePath]) {
		archive.cdTrailer = [ZKCDTrailer recordWithArchivePath:path];
		if (archive.cdTrailer) {
			ZKCDTrailer64Locator *trailer64Locator = [ZKCDTrailer64Locator recordWithArchivePath:path
																			  andCDTrailerLength:[archive.cdTrailer length]];
			if (trailer64Locator) {
				ZKCDTrailer64 *trailer64 = [ZKCDTrailer64 recordWithArchivePath:path atOffset:
				                            trailer64Locator.offsetOfStartOfCentralDirectoryTrailer64];
				if (trailer64) {
					archive.cdTrailer.offsetOfStartOfCentralDirectory = trailer64.offsetOfStartOfCentralDirectory;
					archive.cdTrailer.sizeOfCentralDirectory = trailer64.sizeOfCentralDirectory;
				}
			}
			unsigned long long offset = archive.cdTrailer.offsetOfStartOfCentralDirectory;
			for (NSUInteger i = 0; i < archive.cdTrailer.totalNumberOfCentralDirectoryEntries; i++) {
				ZKCDHeader *cdHeader = [ZKCDHeader recordWithArchivePath:path atOffset:offset];
				[archive.centralDirectory addObject:cdHeader];
				archive.useZip64Extensions = (archive.useZip64Extensions || [cdHeader useZip64Extensions]);
				offset += [cdHeader length];
			}
		} else
			archive = nil;
	}
	return archive;
}

#pragma mark -
#pragma mark Inflation

- (NSInteger) inflateToDiskUsingResourceFork:(BOOL)rfFlag {
	NSString *enclosingFolder = [self.archivePath stringByDeletingLastPathComponent];
	NSString *expansionDirectory = [self uniqueExpansionDirectoryIn:enclosingFolder];
	return [self inflateToDirectory:expansionDirectory usingResourceFork:rfFlag];
}
- (NSInteger) inflateToDirectory:(NSString *)expansionDirectory usingResourceFork:(BOOL)rfFlag {
	NSInteger result = zkSucceeded;
	for (ZKCDHeader *cdHeader in self.centralDirectory) {
		result = [self inflateFile:cdHeader toDirectory:expansionDirectory];
		if (result != zkSucceeded)
			break;
	}
	if (result == zkSucceeded) {
		for (ZKCDHeader *cdHeader in self.centralDirectory) {
			NSString *path = [expansionDirectory stringByAppendingPathComponent:cdHeader.filename];
			[self.fileManager setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
											 [cdHeader posixPermissions], NSFilePosixPermissions,
											 [cdHeader lastModDate], NSFileCreationDate,
											 [cdHeader lastModDate], NSFileModificationDate, nil] ofItemAtPath:path error:nil];
		}
	}

#if ZK_TARGET_OS_MAC
	if (result == zkSucceeded && rfFlag)
		[self.fileManager zk_combineAppleDoubleInDirectory:expansionDirectory];
#endif
	[self cleanUpExpansionDirectory:expansionDirectory];

	return result;
}

- (NSInteger) inflateFile:(ZKCDHeader *)cdHeader toDirectory:(NSString *)expansionDirectory {
	if (self.delegate) {
		if ([NSThread isMainThread])
			[self willUnzipPath:cdHeader.filename];
		else
			[self performSelectorOnMainThread:@selector(willUnzipPath:) withObject:cdHeader.filename waitUntilDone:NO];
	}

	// find the local file header corresponding to the central directory header
	BOOL result = NO;
	ZKLFHeader *lfHeader = [ZKLFHeader recordWithArchivePath:self.archivePath atOffset:cdHeader.localHeaderOffset];
	NSString *path = [expansionDirectory stringByAppendingPathComponent:cdHeader.filename];

	NSFileHandle *archiveFile = [NSFileHandle fileHandleForReadingAtPath:self.archivePath];
	[archiveFile seekToFileOffset:(cdHeader.localHeaderOffset + [lfHeader length])];
	if ([cdHeader isSymLink]) {
		// symbolic links are stored as uncompressed UTF-8-encoded string data in the archive
		NSData *symLinkData = [archiveFile readDataOfLength:cdHeader.compressedSize];
		NSString *symLinkDestinationPath = [[[NSString alloc] initWithData:symLinkData encoding:NSUTF8StringEncoding] autorelease];
		NSString *filename = [expansionDirectory stringByAppendingPathComponent:cdHeader.filename];
		result = [self.fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent]
							 withIntermediateDirectories:YES attributes:nil error:nil];
		if (result)
			result = [self.fileManager createSymbolicLinkAtPath:filename withDestinationPath:symLinkDestinationPath error:nil];
	} else if ([cdHeader isDirectory])
		result = [self.fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	else {
		NSData *deflatedData = nil;
		NSUInteger have, chunkSize, bytesRead, totalBytesRead = 0, crc = 0;
		unsigned long long block = 0, bytesWritten = 0;
		int ret = Z_OK;
		if (cdHeader.compressionMethod == Z_DEFLATED) {
			// inflate the the deflated data from the archive to the file
			z_stream strm;
			strm.zalloc = Z_NULL;
			strm.zfree = Z_NULL;
			strm.opaque = Z_NULL;
			strm.next_in = Z_NULL;
			strm.avail_in = 0;
			strm.total_out = 0;
			ret = inflateInit2(&strm, -MAX_WBITS);
			if (ret == Z_OK) {
				NSFileHandle *inflatedFile = [NSFileHandle zk_newFileHandleForWritingAtPath:path];
				unsigned char out[ZKZipBlockSize];
				NSAutoreleasePool *pool = [NSAutoreleasePool new];
				do {
					chunkSize = MIN(ZKZipBlockSize, cdHeader.compressedSize - totalBytesRead);
					[pool drain];
					pool = [NSAutoreleasePool new];
					deflatedData = [archiveFile readDataOfLength:chunkSize];
					bytesRead = [deflatedData length];
					totalBytesRead += bytesRead;
					if (bytesRead > 0 && totalBytesRead <= cdHeader.compressedSize) {
						strm.avail_in = bytesRead;
						strm.next_in = (Bytef *)[deflatedData bytes];
						do {
							strm.avail_out = chunkSize;
							strm.next_out = out;
							ret = inflate(&strm, Z_SYNC_FLUSH);
							if (ret != Z_STREAM_ERROR) {
								have = (chunkSize - strm.avail_out);
								crc = crc32(crc, out, have);
								[inflatedFile writeData:[NSData dataWithBytesNoCopy:out length:have freeWhenDone:NO]];
								bytesWritten += have;
							} else
								ZKLogError(@"Stream error: %@", path);
							if (irtsIsCancelled) {
								if ([self.invoker isCancelled]) {
									[inflatedFile closeFile];
									if (self.delegate)
										[self performSelectorOnMainThread:@selector(didCancel) withObject:nil waitUntilDone:NO];
									[archiveFile closeFile];
									[pool drain];
									return zkCancelled;
								}
							}
						} while (strm.avail_out == 0 && ret != Z_STREAM_ERROR);
					} else
						ret = Z_STREAM_END;
					if ([self delegateWantsSizes]) {
						if (ZKNotificationIterations > 0 && ++block % ZKNotificationIterations == 0) {
							if ([NSThread isMainThread])
								[self didUpdateBytesWritten:[NSNumber numberWithUnsignedLongLong:bytesWritten]];
							else
								[self performSelectorOnMainThread:@selector(didUpdateBytesWritten:)
													   withObject:[NSNumber numberWithUnsignedLongLong:bytesWritten] waitUntilDone:NO];
							bytesWritten = 0;
						}
					}
					[NSThread sleepForTimeInterval:self.throttleThreadSleepTime];
				} while (ret != Z_STREAM_END && ret != Z_STREAM_ERROR);
				[pool drain];
				pool = nil;
				if ([self delegateWantsSizes]) {
					if ([NSThread isMainThread])
						[self didUpdateBytesWritten:[NSNumber numberWithUnsignedLongLong:bytesWritten]];
					else
						[self performSelectorOnMainThread:@selector(didUpdateBytesWritten:)
											   withObject:[NSNumber numberWithUnsignedLongLong:bytesWritten] waitUntilDone:NO];
				}
				if (ret != Z_STREAM_ERROR)
					inflateEnd(&strm);
				[inflatedFile closeFile];
				if (cdHeader.crc != crc) {
					ret = Z_DATA_ERROR;
					ZKLogError(@"Inflation CRC mismatch for %@ - stored: %u, calculated: %u", path, cdHeader.crc, crc);
				}
			}
		} else if (cdHeader.compressionMethod == Z_NO_COMPRESSION) {
			if (totalBytesRead <= cdHeader.compressedSize) {
				NSFileHandle *inflatedFile = [NSFileHandle zk_newFileHandleForWritingAtPath:path];
				NSAutoreleasePool *pool = [NSAutoreleasePool new];
				do {
					chunkSize = MIN(ZKZipBlockSize, cdHeader.compressedSize - totalBytesRead);
					deflatedData = [archiveFile readDataOfLength:chunkSize];
					bytesRead = [deflatedData length];
					totalBytesRead += bytesRead;
					
					[inflatedFile writeData:deflatedData];
					bytesWritten += bytesRead;
					crc = [deflatedData zk_crc32:crc];

					[pool drain];
					pool = [NSAutoreleasePool new];

					if ([self delegateWantsSizes]) {
						if (ZKNotificationIterations > 0 && ++block % ZKNotificationIterations == 0) {
							if ([NSThread isMainThread])
								[self didUpdateBytesWritten:[NSNumber numberWithUnsignedLongLong:bytesWritten]];
							else
								[self performSelectorOnMainThread:@selector(didUpdateBytesWritten:)
													   withObject:[NSNumber numberWithUnsignedLongLong:bytesWritten] waitUntilDone:NO];
							bytesWritten = 0;
						}
					}
					[NSThread sleepForTimeInterval:self.throttleThreadSleepTime];
					if (irtsIsCancelled) {
						if ([self.invoker isCancelled]) {
							[inflatedFile closeFile];
							if (self.delegate)
								[self performSelectorOnMainThread:@selector(didCancel) withObject:nil waitUntilDone:NO];
							[archiveFile closeFile];
							[pool drain];
							return zkCancelled;
						}
					}
				} while (totalBytesRead < cdHeader.compressedSize);
				[pool drain];
				[inflatedFile closeFile];
				if (cdHeader.crc != crc) {
					ret = Z_DATA_ERROR;
					ZKLogError(@"Inflation CRC mismatch for %@ - stored: %u, calculated: %u", path, cdHeader.crc, crc);
				}
			}
		}
		result = (ret == Z_OK || ret == Z_STREAM_END);
	}

	// restore the extracted file's attributes
	if (result) {
		[self.fileManager setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
										 [cdHeader posixPermissions], NSFilePosixPermissions,
										 [cdHeader lastModDate], NSFileCreationDate,
										 [cdHeader lastModDate], NSFileModificationDate, nil] ofItemAtPath:path error:nil];
	}

	[archiveFile closeFile];

	return result ? zkSucceeded : zkFailed;
}

#pragma mark -
#pragma mark Deflation

- (NSInteger) deflateFiles:(NSArray *)paths relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)rfFlag {
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

- (NSInteger) deflateDirectory:(NSString *)dirPath relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)rfFlag {
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

- (NSInteger) deflateFile:(NSString *)path relativeToPath:(NSString *)basePath usingResourceFork:(BOOL)rfFlag {
	BOOL isDir = [self.fileManager zk_isDirAtPath:path];
	BOOL isSymlink = [self.fileManager zk_isSymLinkAtPath:path];

	NSFileHandle *archiveFile = [NSFileHandle zk_newFileHandleForWritingAtPath:self.archivePath];

	// append a trailing slash to directory paths
	if (isDir && !isSymlink && ![[path substringFromIndex:([path length] - 1)] isEqualToString:@"/"])
		path = [path stringByAppendingString:@"/"];

	if (self.delegate) {
		if ([NSThread isMainThread])
			[self willZipPath:path];
		else
			[self performSelectorOnMainThread:@selector(willZipPath:) withObject:path waitUntilDone:NO];
	}

	// construct a relative path for storage in the archive directory by removing basePath from the beginning of path
    if ([[basePath substringFromIndex:([basePath length] - 1)] isEqualToString:@"/"])
        basePath = [basePath substringToIndex:([basePath length] - 1)];

	NSString *relativePath = path;
	if (basePath && [basePath length] > 0) {
		if (![basePath hasSuffix:@"/"])
			basePath = [basePath stringByAppendingString:@"/"];
		NSRange r = [path rangeOfString:basePath];
		if (r.location != NSNotFound)
			relativePath = [path substringFromIndex:r.length];
	}

	// create the local file header for the file
	ZKLFHeader *lfHeaderData = [[ZKLFHeader new] autorelease];
	lfHeaderData.uncompressedSize = [self.fileManager zk_dataSizeAtFilePath:path];
	lfHeaderData.lastModDate = [self.fileManager zk_modificationDateForPath:path];
	lfHeaderData.filename = relativePath;
	lfHeaderData.filenameLength = [lfHeaderData.filename zk_precomposedUTF8Length];
	lfHeaderData.crc = 0;
	lfHeaderData.compressedSize = 0;

	// write the local file header to the archive
	unsigned long long lfHeaderDataOffset = self.cdTrailer.offsetOfStartOfCentralDirectory;
	[archiveFile seekToFileOffset:lfHeaderDataOffset];
	[archiveFile writeData:[lfHeaderData data]];

	if (isSymlink) {
		NSString *symlinkPath = [self.fileManager destinationOfSymbolicLinkAtPath:path error:nil];
		NSData *symlinkData = [symlinkPath dataUsingEncoding:NSUTF8StringEncoding];
		lfHeaderData.crc = [symlinkData zk_crc32];
		lfHeaderData.compressedSize = [symlinkData length];
		lfHeaderData.uncompressedSize = [symlinkData length];
		lfHeaderData.compressionMethod = Z_NO_COMPRESSION;
		lfHeaderData.versionNeededToExtract = 10;
		[archiveFile writeData:symlinkData];
#if ZK_TARGET_OS_MAC
		rfFlag = NO;
#endif
	} else if (isDir) {
		lfHeaderData.crc = 0;
		lfHeaderData.compressedSize = 0;
		lfHeaderData.uncompressedSize = 0;
		lfHeaderData.compressionMethod = Z_NO_COMPRESSION;
		lfHeaderData.versionNeededToExtract = 10;
#if ZK_TARGET_OS_MAC
		rfFlag = NO;
#endif
	} else {
		// deflate the file's data, writing it to the archive
		z_stream strm;
		strm.zalloc = Z_NULL;
		strm.zfree = Z_NULL;
		strm.opaque = Z_NULL;
		strm.next_in = Z_NULL;
		strm.avail_in = 0;
		strm.total_out = 0;
		NSInteger ret = deflateInit2(&strm, Z_BEST_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY);
		if (ret == Z_OK) {
			NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
			NSData *fileData = nil;
			NSData *archiveData = nil;
			unsigned char out[ZKZipBlockSize];
			unsigned long long compressedSize = 0, block = 0, bytesWritten = 0;
			NSUInteger flush, have, crc = 0;
			NSAutoreleasePool *pool = [NSAutoreleasePool new];
			do {
				[pool drain];
				pool = [NSAutoreleasePool new];
				fileData = [file readDataOfLength:ZKZipBlockSize];
				strm.avail_in = [fileData length];
				bytesWritten += strm.avail_in;
				flush = Z_FINISH;
				if (strm.avail_in > 0) {
					flush = Z_SYNC_FLUSH;
					strm.next_in = (Bytef *)[fileData bytes];
					crc = crc32(crc, strm.next_in, strm.avail_in);
				}
				do {
					strm.avail_out = ZKZipBlockSize;
					strm.next_out = out;
					ret = deflate(&strm, flush);
					if (ret != Z_STREAM_ERROR) {
						have = (ZKZipBlockSize - strm.avail_out);
						compressedSize += have;
						archiveData = [NSData dataWithBytesNoCopy:out length:have freeWhenDone:NO];
						[archiveFile writeData:archiveData];
						if (irtsIsCancelled) {
							if ([self.invoker isCancelled]) {
								[file closeFile];
								[archiveFile closeFile];
								if (self.delegate)
									[self performSelectorOnMainThread:@selector(didCancel) withObject:nil waitUntilDone:NO];
								[pool drain];
								return zkCancelled;
							}
						}
					} else {
						ZKLogError(@"Error in deflate");
						[file closeFile];
						[archiveFile closeFile];
						[pool drain];
						return zkFailed;
					}
				} while (strm.avail_out == 0);
				if (strm.avail_in != 0) {
					ZKLogError(@"All input not used");
					[file closeFile];
					[archiveFile closeFile];
					[pool drain];
					return zkFailed;
				}
				if ([self delegateWantsSizes]) {
					if (ZKNotificationIterations > 0 && ++block % ZKNotificationIterations == 0) {
						if ([NSThread isMainThread])
							[self didUpdateBytesWritten:[NSNumber numberWithUnsignedLongLong:bytesWritten]];
						else
							[self performSelectorOnMainThread:@selector(didUpdateBytesWritten:)
												   withObject:[NSNumber numberWithUnsignedLongLong:bytesWritten] waitUntilDone:NO];
						bytesWritten = 0;
					}
				}
				[NSThread sleepForTimeInterval:self.throttleThreadSleepTime];
			} while (flush != Z_FINISH);
			deflateEnd(&strm);
			[file closeFile];
			if ([self delegateWantsSizes]) {
				if ([NSThread isMainThread])
					[self didUpdateBytesWritten:[NSNumber numberWithUnsignedLongLong:bytesWritten]];
				else
					[self performSelectorOnMainThread:@selector(didUpdateBytesWritten:)
										   withObject:[NSNumber numberWithUnsignedLongLong:bytesWritten] waitUntilDone:NO];
			}
			if (ret != Z_STREAM_END) {
				ZKLogError(@"Stream incomplete");
				[archiveFile closeFile];
				[pool drain];
				return zkFailed;
			}

			// replace the local file header's default values with those calculated during deflation
			lfHeaderData.crc = crc;
			lfHeaderData.compressedSize = compressedSize;

			[pool drain];
			pool = nil;
		}
	}

	// create the central directory header and add it to central directory
	ZKCDHeader *dataCDHeader = [[ZKCDHeader new] autorelease];
	dataCDHeader.uncompressedSize = lfHeaderData.uncompressedSize;
	dataCDHeader.lastModDate = lfHeaderData.lastModDate;
	dataCDHeader.crc = lfHeaderData.crc;
	dataCDHeader.compressedSize = lfHeaderData.compressedSize;
	dataCDHeader.filename = lfHeaderData.filename;
	dataCDHeader.filenameLength = lfHeaderData.filenameLength;
	dataCDHeader.localHeaderOffset = lfHeaderDataOffset;
	dataCDHeader.compressionMethod = lfHeaderData.compressionMethod;
	dataCDHeader.generalPurposeBitFlag = lfHeaderData.generalPurposeBitFlag;
	dataCDHeader.versionNeededToExtract = lfHeaderData.versionNeededToExtract;
	dataCDHeader.externalFileAttributes = [self.fileManager zk_externalFileAttributesAtPath:path];
	[self.centralDirectory addObject:dataCDHeader];
	self.useZip64Extensions = (self.useZip64Extensions || [dataCDHeader useZip64Extensions]);

	// update the central directory trailer
	self.cdTrailer.offsetOfStartOfCentralDirectory = [archiveFile offsetInFile];
	self.cdTrailer.numberOfCentralDirectoryEntriesOnThisDisk++;
	self.cdTrailer.totalNumberOfCentralDirectoryEntries++;
	self.cdTrailer.sizeOfCentralDirectory += [dataCDHeader length];

#if ZK_TARGET_OS_MAC
	if (rfFlag) {
		// optionally include the file's deflated AppleDoubled Finder info and resource fork in the archive
		NSData *appleDoubleData = [GMAppleDouble zk_appleDoubleDataForPath:path];
		if (appleDoubleData) {
			NSData *deflatedData = [appleDoubleData zk_deflate];

			ZKLFHeader *lfHeaderResource = [[ZKLFHeader new] autorelease];
			lfHeaderResource.uncompressedSize = [appleDoubleData length];
			lfHeaderResource.lastModDate = lfHeaderData.lastModDate;
			lfHeaderResource.filename = [[ZKMacOSXDirectory stringByAppendingPathComponent:
			                              [relativePath stringByDeletingLastPathComponent]]
			                             stringByAppendingPathComponent:
			                             [ZKDotUnderscore stringByAppendingString:[relativePath lastPathComponent]]];
			lfHeaderResource.filenameLength = [lfHeaderResource.filename zk_precomposedUTF8Length];
			lfHeaderResource.crc = [appleDoubleData zk_crc32];
			lfHeaderResource.compressedSize = [deflatedData length];

			ZKCDHeader *resourceCDHeader = [[ZKCDHeader new] autorelease];
			resourceCDHeader.uncompressedSize = lfHeaderResource.uncompressedSize;
			resourceCDHeader.lastModDate = lfHeaderResource.lastModDate;
			resourceCDHeader.crc = lfHeaderResource.crc;
			resourceCDHeader.compressedSize = lfHeaderResource.compressedSize;
			resourceCDHeader.filename = lfHeaderResource.filename;
			resourceCDHeader.filenameLength = lfHeaderResource.filenameLength;
			resourceCDHeader.localHeaderOffset = [archiveFile offsetInFile];
			resourceCDHeader.externalFileAttributes = dataCDHeader.externalFileAttributes;
			[self.centralDirectory addObject:resourceCDHeader];
			self.useZip64Extensions = (self.useZip64Extensions || [resourceCDHeader useZip64Extensions]);

			[archiveFile writeData:[lfHeaderResource data]];
			[archiveFile writeData:deflatedData];

			self.cdTrailer.offsetOfStartOfCentralDirectory = [archiveFile offsetInFile];
			self.cdTrailer.numberOfCentralDirectoryEntriesOnThisDisk++;
			self.cdTrailer.totalNumberOfCentralDirectoryEntries++;
			self.cdTrailer.sizeOfCentralDirectory += [resourceCDHeader length];
		}
	}
#endif

	// write the central directory to the archive
	self.useZip64Extensions = (self.useZip64Extensions || [self.cdTrailer useZip64Extensions]);
	if (self.useZip64Extensions) {
		ZKCDTrailer64 *cdTrailer64 = [[ZKCDTrailer64 new] autorelease];
		cdTrailer64.numberOfCentralDirectoryEntriesOnThisDisk = self.cdTrailer.numberOfCentralDirectoryEntriesOnThisDisk;
		cdTrailer64.totalNumberOfCentralDirectoryEntries = self.cdTrailer.totalNumberOfCentralDirectoryEntries;
		cdTrailer64.sizeOfCentralDirectory = self.cdTrailer.sizeOfCentralDirectory;
		cdTrailer64.offsetOfStartOfCentralDirectory = [archiveFile offsetInFile];
		for (ZKCDHeader *cdHeader in self.centralDirectory)
			[archiveFile writeData:[cdHeader data]];
		ZKCDTrailer64Locator *cdTrailer64Locator = [[ZKCDTrailer64Locator new] autorelease];
		cdTrailer64Locator.offsetOfStartOfCentralDirectoryTrailer64 = [archiveFile offsetInFile];
		[archiveFile writeData:[cdTrailer64 data]];
		[archiveFile writeData:[cdTrailer64Locator data]];
	} else
		for (ZKCDHeader *cdHeader in self.centralDirectory)
			[archiveFile writeData:[cdHeader data]];

	[archiveFile writeData:[self.cdTrailer data]];

	// overwrite the updated local file header
	[archiveFile seekToFileOffset:lfHeaderDataOffset];
	[archiveFile writeData:[lfHeaderData data]];
	[archiveFile closeFile];

	return zkSucceeded;
}

#pragma mark -
#pragma mark Setup

- (id) init {
	if (self = [super init])
		self.useZip64Extensions = NO;
	return self;
}

@synthesize useZip64Extensions = _useZip64Extensions;

@end
