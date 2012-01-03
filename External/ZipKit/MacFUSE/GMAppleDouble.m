// ================================================================
// Copyright (c) 2007, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above
//   copyright notice, this list of conditions and the following disclaimer
//   in the documentation and/or other materials provided with the
//   distribution.
// * Neither the name of Google Inc. nor the names of its
//   contributors may be used to endorse or promote products derived from
//   this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ================================================================
//
//  GMAppleDouble.m
//  MacFUSE
//
//  Created by ted on 12/29/07.
//
#import "GMAppleDouble.h"
#import "libkern/OSByteOrder.h"

#define GM_APPLE_DOUBLE_HEADER_MAGIC   0x00051607
#define GM_APPLE_DOUBLE_HEADER_VERSION 0x00020000

typedef struct {
  UInt32 magicNumber;      // Should be 0x00051607
  UInt32 versionNumber;    // Should be 0x00020000
  char filler[16];         // Zero-filled bytes.
  UInt16 numberOfEntries;  // Number of entries.
} __attribute__((packed)) DoubleHeader;

typedef struct {
  UInt32 entryID;  // Defines what entry is (0 is invalid)
  UInt32 offset;   // Offset from beginning of file to entry data.
  UInt32 length;   // Length of entry data in bytes.
} __attribute__((packed)) DoubleEntryHeader;

@implementation GMAppleDoubleEntry

+ (GMAppleDoubleEntry *)entryWithID:(GMAppleDoubleEntryID)entryID 
                               data:(NSData *)data {
  return [[[GMAppleDoubleEntry alloc] 
           initWithEntryID:entryID data:data] autorelease];
}

- (id)initWithEntryID:(GMAppleDoubleEntryID)entryID
                 data:(NSData *)data {
  if ((self = [super init])) {
    if (entryID == DoubleEntryInvalid || data == nil) {
      [self release];
      return nil;
    }
    entryID_ = entryID;
    data_ = [data retain];
  }
  return self;
}

- (void)dealloc {
  [data_ release];
  [super dealloc];
}

- (GMAppleDoubleEntryID)entryID {
  return entryID_;
}
- (NSData *)data {
  return data_;
}

@end

@implementation GMAppleDouble

+ (GMAppleDouble *)appleDouble {
  return [[[GMAppleDouble alloc] init] autorelease];
}

+ (GMAppleDouble *)appleDoubleWithData:(NSData *)data {
  GMAppleDouble* appleDouble = [[[GMAppleDouble alloc] init] autorelease];
  if ([appleDouble addEntriesFromAppleDoubleData:data]) {
    return appleDouble;
  }
  return nil;
}

- (id)init {
  if ((self = [super init])) {
    entries_ = [[NSMutableArray alloc] init];
  }
  return self;  
}

- (void)dealloc {
  [entries_ release];
  [super dealloc];
}

- (void)addEntry:(GMAppleDoubleEntry *)entry {
  [entries_ addObject:entry];
}

- (void)addEntryWithID:(GMAppleDoubleEntryID)entryID data:(NSData *)data {
  GMAppleDoubleEntry* entry = [GMAppleDoubleEntry entryWithID:entryID data:data];
  [self addEntry:entry];
}

- (BOOL)addEntriesFromAppleDoubleData:(NSData *)data {
  const int len = [data length];
  DoubleHeader header;
  if (len < sizeof(header)) {
    return NO;  // To small to even fit our header.
  }
  [data getBytes:&header length:sizeof(header)];
  if (OSSwapBigToHostInt32(header.magicNumber) != GM_APPLE_DOUBLE_HEADER_MAGIC ||
      OSSwapBigToHostInt32(header.versionNumber) != GM_APPLE_DOUBLE_HEADER_VERSION) {
    return NO;  // Invalid header.
  }
  int count = OSSwapBigToHostInt16(header.numberOfEntries);
  int offset = sizeof(DoubleHeader);
  if (len < (offset + (count * sizeof(DoubleEntryHeader)))) {
    return NO;  // Not enough data to hold all the DoubleEntryHeader.
  }
  for (int i = 0; i < count; ++i, offset += sizeof(DoubleEntryHeader)) {
    // Extract header
    DoubleEntryHeader entryHeader;
    NSRange range = NSMakeRange(offset, sizeof(entryHeader));
    [data getBytes:&entryHeader range:range];

    // Extract data
    range = NSMakeRange(OSSwapBigToHostInt32(entryHeader.offset), 
                        OSSwapBigToHostInt32(entryHeader.length));
    if (len < (range.location + range.length)) {
      return NO;  // Given data too small to contain this entry.
    }
    NSData* entryData = [data subdataWithRange:range];
    [self addEntryWithID:OSSwapBigToHostInt32(entryHeader.entryID) data:entryData];
  }

  return YES;
}

- (NSArray *)entries {
  return entries_;
}

- (NSData *)data {
  NSMutableData* entryListData = [NSMutableData data];
  NSMutableData* entryData = [NSMutableData data];
  int dataStartOffset = 
    sizeof(DoubleHeader) + [entries_ count] * sizeof(DoubleEntryHeader);
  for (int i = 0; i < [entries_ count]; ++i) {
    GMAppleDoubleEntry* entry = [entries_ objectAtIndex:i];

    DoubleEntryHeader entryHeader;
    memset(&entryHeader, 0, sizeof(entryHeader));
    entryHeader.entryID = OSSwapHostToBigInt32((UInt32)[entry entryID]);
    entryHeader.offset = 
      OSSwapHostToBigInt32((UInt32)(dataStartOffset + [entryData length]));
    entryHeader.length = OSSwapHostToBigInt32((UInt32)[[entry data] length]);
    [entryListData appendBytes:&entryHeader length:sizeof(entryHeader)];
    [entryData appendData:[entry data]];
  }
  
  NSMutableData* data = [NSMutableData data];

  DoubleHeader header;
  memset(&header, 0, sizeof(header));
  header.magicNumber = OSSwapHostToBigConstInt32(GM_APPLE_DOUBLE_HEADER_MAGIC);
  header.versionNumber = OSSwapHostToBigConstInt32(GM_APPLE_DOUBLE_HEADER_VERSION);
  header.numberOfEntries = OSSwapHostToBigInt16((UInt16)[entries_ count]);
  [data appendBytes:&header length:sizeof(header)];
  [data appendData:entryListData];
  [data appendData:entryData];
  return data;
}

@end
