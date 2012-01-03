//
//  ZKLFHeader.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "ZKLFHeader.h"
#import "NSDate+ZKAdditions.h"
#import "NSData+ZKAdditions.h"
#import "NSString+ZKAdditions.h"
#import "ZKDefs.h"
#import "zlib.h"

@implementation ZKLFHeader

- (id) init {
	if (self = [super init]) {
		self.magicNumber = ZKLFHeaderMagicNumber;
		self.versionNeededToExtract = 20;
		self.generalPurposeBitFlag = 0;
		self.compressionMethod = Z_DEFLATED;
		self.lastModDate = [NSDate date];
		self.crc = 0;
		self.compressedSize = 0;
		self.uncompressedSize = 0;
		self.filenameLength = 0;
		self.extraFieldLength = 0;
		self.filename = nil;
		self.extraField = nil;

		[self addObserver:self forKeyPath:@"compressedSize" options:NSKeyValueObservingOptionNew context:nil];
		[self addObserver:self forKeyPath:@"uncompressedSize" options:NSKeyValueObservingOptionNew context:nil];
		[self addObserver:self forKeyPath:@"extraField" options:NSKeyValueObservingOptionNew context:nil];
		[self addObserver:self forKeyPath:@"filename" options:NSKeyValueObservingOptionNew context:nil];
	}
	return self;
}

- (void) removeObservers {
	[self removeObserver:self forKeyPath:@"compressedSize"];
	[self removeObserver:self forKeyPath:@"uncompressedSize"];
	[self removeObserver:self forKeyPath:@"extraField"];
	[self removeObserver:self forKeyPath:@"filename"];
}

- (void) finalize {
	[self removeObservers];
	[super finalize];
}

- (void) dealloc {
	[self removeObservers];
	self.lastModDate = nil;
	self.filename = nil;
	self.extraField = nil;
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *) keyPath ofObject:(id) object change:(NSDictionary *) change context:(void *) context {
	if ([keyPath isEqualToString:@"compressedSize"] || [keyPath isEqualToString:@"uncompressedSize"]) {
		self.versionNeededToExtract = ([self useZip64Extensions] ? 45 : 20);
	} else if ([keyPath isEqualToString:@"extraField"] && self.extraFieldLength < 1) {
		self.extraFieldLength = [self.extraField length];
	} else if ([keyPath isEqualToString:@"filename"] && self.filenameLength < 1) {
		self.filenameLength = [self.filename zk_precomposedUTF8Length];
	}
}

+ (ZKLFHeader *) recordWithData:(NSData *) data atOffset:(NSUInteger) offset {
	if (!data) return nil;
	NSUInteger mn = [data zk_hostInt32OffsetBy:&offset];
	if (mn != ZKLFHeaderMagicNumber) return nil;
	ZKLFHeader *record = [[ZKLFHeader new] autorelease];
	record.magicNumber = mn;
	record.versionNeededToExtract = [data zk_hostInt16OffsetBy:&offset];
	record.generalPurposeBitFlag = [data zk_hostInt16OffsetBy:&offset];
	record.compressionMethod = [data zk_hostInt16OffsetBy:&offset];
	record.lastModDate = [NSDate zk_dateWithDosDate:[data zk_hostInt32OffsetBy:&offset]];
	record.crc = [data zk_hostInt32OffsetBy:&offset];
	record.compressedSize = [data zk_hostInt32OffsetBy:&offset];
	record.uncompressedSize = [data zk_hostInt32OffsetBy:&offset];
	record.filenameLength = [data zk_hostInt16OffsetBy:&offset];
	record.extraFieldLength = [data zk_hostInt16OffsetBy:&offset];
	if ([data length] > ZKLFHeaderFixedDataLength) {
		if (record.filenameLength > 0)
			record.filename = [data zk_stringOffsetBy:&offset length:record.filenameLength];
		if (record.extraFieldLength > 0) {
			record.extraField = [data subdataWithRange:NSMakeRange(offset, record.extraFieldLength)];
			[record parseZip64ExtraField];
		}
	}
	return record;
}

+ (ZKLFHeader *) recordWithArchivePath:(NSString *) path atOffset:(unsigned long long) offset {
	NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
	[file seekToFileOffset:offset];
	NSData *fixedData = [file readDataOfLength:ZKLFHeaderFixedDataLength];
	ZKLFHeader *record = [self recordWithData:fixedData atOffset:0];
	if (record.filenameLength > 0) {
		NSData *data = [file readDataOfLength:record.filenameLength];
		record.filename = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	}
	if (record.extraFieldLength > 0) {
		record.extraField = [file readDataOfLength:record.extraFieldLength];
		[record parseZip64ExtraField];
	}
	[file closeFile];
	return record;
}

- (NSData *) data {
	self.extraField = [self zip64ExtraField];

	NSMutableData *data = [NSMutableData zk_dataWithLittleInt32:self.magicNumber];
	[data zk_appendLittleInt16:self.versionNeededToExtract];
	[data zk_appendLittleInt16:self.generalPurposeBitFlag];
	[data zk_appendLittleInt16:self.compressionMethod];
	[data zk_appendLittleInt32:[self.lastModDate zk_dosDate]];
	[data zk_appendLittleInt32:self.crc];
	if ([self useZip64Extensions]) {
		[data zk_appendLittleInt32:0xFFFFFFFF];
		[data zk_appendLittleInt32:0xFFFFFFFF];
	} else {
		[data zk_appendLittleInt32:self.compressedSize];
		[data zk_appendLittleInt32:self.uncompressedSize];
	}
	[data zk_appendLittleInt16:self.filenameLength];
	[data zk_appendLittleInt16:[self.extraField length]];
	[data zk_appendPrecomposedUTF8String:self.filename];
	[data appendData:self.extraField];
	return data;
}

- (void) parseZip64ExtraField {
	NSUInteger offset = 0, tag, length;
	while (offset < self.extraFieldLength) {
		tag = [self.extraField zk_hostInt16OffsetBy:&offset];
		length = [self.extraField zk_hostInt16OffsetBy:&offset];
		if (tag == 0x0001) {
			if (length >= 8)
				self.uncompressedSize = [self.extraField zk_hostInt64OffsetBy:&offset];
			if (length >= 16)
				self.compressedSize = [self.extraField zk_hostInt64OffsetBy:&offset];
			break;
		} else {
			offset += length;
		}
	}
}

- (NSData *) zip64ExtraField {
	NSMutableData *zip64ExtraField = nil;
	if ([self useZip64Extensions]) {
		zip64ExtraField = [NSMutableData zk_dataWithLittleInt16:0x0001];
		[zip64ExtraField zk_appendLittleInt16:16];
		[zip64ExtraField zk_appendLittleInt64:self.uncompressedSize];
		[zip64ExtraField zk_appendLittleInt64:self.compressedSize];
	}
	return zip64ExtraField;
}

- (NSUInteger) length {
	if (!self.extraField || [self.extraField length] == 0)
		self.extraField = [self zip64ExtraField];
	return ZKLFHeaderFixedDataLength + self.filenameLength + [self.extraField length];
}

- (BOOL) useZip64Extensions {
	return (self.uncompressedSize >= 0xFFFFFFFF) || (self.compressedSize >= 0xFFFFFFFF);
}

- (NSString *) description {
	return [NSString stringWithFormat:@"%@ modified %@, %qu bytes (%qu compressed)",
			self.filename, self.lastModDate, self.uncompressedSize, self.compressedSize];
}

- (BOOL) isResourceFork {
	return [self.filename zk_isResourceForkPath];
}

@synthesize magicNumber, versionNeededToExtract, generalPurposeBitFlag, compressionMethod, lastModDate, crc, compressedSize, uncompressedSize, filenameLength, extraFieldLength, filename, extraField;

@end
