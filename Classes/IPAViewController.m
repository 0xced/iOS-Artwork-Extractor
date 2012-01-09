//
//  IPAViewController.m
//  UIKit Artwork Extractor
//
//  Created by Cédric Luthi on 30.12.11.
//  Copyright (c) 2011 Cédric Luthi. All rights reserved.
//

#import "IPAViewController.h"

#import "AppDelegate.h"
#import "ArtworkViewController.h"
#import "IPAArchive.h"


static NSString * mobileApplicationsPath()
{
	static NSString *mobileApplicationsPath = nil;
	if (!mobileApplicationsPath)
	{
		AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
		mobileApplicationsPath = [[[appDelegate homeDirectory] stringByAppendingPathComponent:@"/Music/iTunes/Mobile Applications"] retain];
	}
	return mobileApplicationsPath;
}

static NSArray * mobileApplications()
{
	static NSArray *mobileApplications = nil;
	if (!mobileApplications)
		mobileApplications = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:mobileApplicationsPath() error:NULL] retain];
	
	return mobileApplications;
}


@interface IPAViewController ()

@property (nonatomic, retain) NSMutableArray *archives;

@end


@implementation IPAViewController

@synthesize archives = _archives;

- (void) reloadRowsAtIndexPaths:(NSArray *)indexPaths
{
	if ([NSThread isMainThread])
		[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
	else
		[self performSelectorOnMainThread:_cmd withObject:indexPaths waitUntilDone:NO];
}

- (void) loadArchives
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSUInteger i = 0;
	for (NSString *relativePath in mobileApplications())
	{
		NSAutoreleasePool *archivePool = [[NSAutoreleasePool alloc] init];
		NSString *ipaPath = [mobileApplicationsPath() stringByAppendingPathComponent:relativePath];
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:ipaPath error:NULL];
		if ([attributes fileSize] > 500 * 1024 * 1024)
		{
			NSLog(@"Skipped %@ (too big)", [ipaPath lastPathComponent]);
			continue;
		}
		IPAArchive *archive = [[[IPAArchive alloc] initWithPath:ipaPath] autorelease];
		if ([archive.imageNames count] == 0)
		{
			NSLog(@"Skipped %@ (no images)", [ipaPath lastPathComponent]);
			continue;
		}
		[archive unload];
		[self.archives replaceObjectAtIndex:i withObject:archive];
		
		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:i++ inSection:0]];
		[self reloadRowsAtIndexPaths:indexPaths];
		
		[archivePool drain];
	}
	
	[self performSelectorOnMainThread:@selector(archivesDidLoad) withObject:nil waitUntilDone:NO];
	
	[pool drain];
}

- (void) archivesDidLoad
{
	[self.tableView reloadData];
}

- (void) viewDidLoad
{
	self.archives = [NSMutableArray array];
	for (NSString *relativePath in mobileApplications())
	{
		NSString *ipaPath = [mobileApplicationsPath() stringByAppendingPathComponent:relativePath];
		[self.archives addObject:ipaPath];
	}
	
	self.title = self.tabBarItem.title;
	self.tableView.rowHeight = [UIImage imageNamed:@"Unknown.png"].size.height;
	
	[self performSelectorInBackground:@selector(loadArchives) withObject:nil];
}

- (void) viewDidUnload
{
	self.archives = nil;
}

// MARK: - UITableView data source

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.archives count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IPACell"];
	if (!cell)
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"IPACell"] autorelease];
	
	return cell;
}

// MARK: - UITableView delegate

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	IPAArchive *archive = [self.archives objectAtIndex:indexPath.row];
	NSString *path = [archive isKindOfClass:[IPAArchive class]] ? archive.path : (NSString *)archive;
	UIImage *icon = [archive isKindOfClass:[IPAArchive class]] ? archive.appIcon : [UIImage imageNamed:@"Unknown.png"];
	
	cell.textLabel.text = [[path lastPathComponent] stringByDeletingPathExtension];
	cell.imageView.image = icon;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	IPAArchive *archive = [self.archives objectAtIndex:indexPath.row];
	if (![archive isKindOfClass:[IPAArchive class]])
	{
		NSString *path = (NSString *)archive;
		archive = [[[IPAArchive alloc] initWithPath:path] autorelease];
		[self.archives replaceObjectAtIndex:indexPath.row withObject:archive];
	}
	ArtworkViewController *artworkViewController = [[[ArtworkViewController alloc] initWithArchive:archive] autorelease];
	[self.navigationController pushViewController:artworkViewController animated:YES];
}

@end
