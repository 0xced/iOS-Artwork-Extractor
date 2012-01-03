//
//  ZKLog.m
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import "ZKLog.h"

NSString* const ZKLogLevelKey = @"ZKLogLevel";
NSString* const ZKLogToFileKey = @"ZKLogToFile";

@implementation ZKLog

- (void) logFile:(char*) sourceFile lineNumber:(NSUInteger) lineNumber level:(NSUInteger) level format:(NSString*) format, ... {
	if (level >= self.minimumLevel) {
		va_list args;
		va_start(args, format);
		NSString *message = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
		va_end(args);
		NSString *label = [self levelToLabel:level];
		NSString *now = [self.dateFormatter stringFromDate:[NSDate date]];
		if (label) {
			NSString *line = [NSString stringWithFormat:@"%@ [%i] %@ %@ (%@:%u)", now, self.pid, label, message, [[NSString stringWithUTF8String:sourceFile] lastPathComponent], lineNumber];
			fprintf(stderr, "%s\n", [line UTF8String]);
			fflush(stderr);
		}
	}
	return;
}

- (NSUInteger) minimumLevel {
	return minimumLevel;
}
- (void) setMinimumLevel:(NSUInteger) value {
	switch (value) {
		case ZKLogLevelError:
		case ZKLogLevelNotice:
		case ZKLogLevelDebug:
		case ZKLogLevelAll:
			minimumLevel = value;
			break;
		default:
			ZKLogError(@"Invalid logging level: %u. Old value %@ unchanged.", value, [self levelToLabel:self.minimumLevel]);
			break;
	}
	return;
}

- (NSString *) levelToLabel:(NSUInteger) level {
	NSString *label = nil;
	switch (level) {
		case ZKLogLevelError:
			label = @"<ERROR->";
			break;
		case ZKLogLevelNotice:
			label = @"<Notice>";
			break;
		case ZKLogLevelDebug:
			label = @"<Debug->";
			break;
		default:
			label = nil;
			break;
	}
	return label;
}

static ZKLog *sharedInstance = nil;
+ (ZKLog *) sharedInstance {
	@synchronized(self) {
		if (sharedInstance == nil) {
			sharedInstance = [self new];
		}
	}
	return sharedInstance;
}

- (id) init {
	@synchronized([self class]) {
		if (sharedInstance == nil) {
			if (self = [super init]) {
				sharedInstance = self;
				
				self.pid = [[NSProcessInfo processInfo] processIdentifier];
				self.minimumLevel = ZKLogLevelError;
				self.dateFormatter = [[NSDateFormatter new] autorelease];
				[self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
				
				if ([[NSUserDefaults standardUserDefaults] boolForKey:ZKLogToFileKey]) {
					NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
					NSString *libraryFolder = [searchPaths objectAtIndex:0];
					NSString *logFolder = [libraryFolder stringByAppendingPathComponent:@"Logs"];
					[[[NSFileManager new] autorelease] createDirectoryAtPath:logFolder withIntermediateDirectories:YES attributes:nil error:nil];
					self.logFilePath = [logFolder stringByAppendingPathComponent:
										[[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] 
										 stringByAppendingPathExtension:@"log"]];
					freopen([self.logFilePath fileSystemRepresentation], "a+", stderr);
				}
			}
		}
	}
	return sharedInstance;
}

+ (id) allocWithZone:(NSZone *) zone {
	@synchronized(self) {
		if (sharedInstance == nil) {
			return [super allocWithZone:zone];
		}
	}
	return sharedInstance;
}

+ (void) initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:
	 [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:ZKLogToFileKey]];
	[super initialize];
}

- (id) copyWithZone:(NSZone *) zone {
	return self;
}

- (void) finalize {
	if (self.logFilePointer)
		fclose(self.logFilePointer);
	[super finalize];
}

- (void) dealloc {
	if (self.logFilePointer) 
		fclose(self.logFilePointer);	
	self.dateFormatter = nil;
	self.logFilePath = nil;
	[super dealloc];
}

@synthesize dateFormatter, pid, logFilePath, logFilePointer;
@dynamic minimumLevel;

@end