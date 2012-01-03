//
//  ZKDefs.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "ZKDefs.h"

NSString* const ZKArchiveFileExtension = @"zip";
NSString* const ZKMacOSXDirectory = @"__MACOSX";
NSString* const ZKDotUnderscore = @"._";
NSString* const ZKExpansionDirectoryName = @".ZipKit";

NSString* const ZKPathsKey = @"paths";
NSString* const ZKusingResourceForkKey = @"usingResourceFork";

NSString* const ZKFileDataKey = @"fileData";
NSString* const ZKFileAttributesKey = @"fileAttributes";
NSString* const ZKPathKey = @"path";

const NSUInteger ZKZipBlockSize = 262144;
const NSUInteger ZKNotificationIterations = 100;

const NSUInteger ZKCDHeaderMagicNumber = 0x02014B50;
const NSUInteger ZKCDHeaderFixedDataLength = 46;

const NSUInteger ZKCDTrailerMagicNumber = 0x06054B50;
const NSUInteger ZKCDTrailerFixedDataLength = 22;

const NSUInteger ZKLFHeaderMagicNumber = 0x04034B50;
const NSUInteger ZKLFHeaderFixedDataLength = 30;

const NSUInteger ZKCDTrailer64MagicNumber = 0x06064b50;
const NSUInteger ZKCDTrailer64FixedDataLength = 56;

const NSUInteger ZKCDTrailer64LocatorMagicNumber = 0x07064b50;
const NSUInteger ZKCDTrailer64LocatorFixedDataLength = 20;
