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


@interface IPAViewController ()

@property (nonatomic, retain) NSMutableArray *archives;

@end


@implementation IPAViewController

@synthesize archiveLoadingView = _archiveLoadingView;
@synthesize appNameLabel = _appNameLabel;
@synthesize progressView = _progressView;

@synthesize archives = _archives;

- (void) loadArchives
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	NSString *mobileApplicationsPath = [[appDelegate homeDirectory] stringByAppendingPathComponent:@"/Music/iTunes/Mobile Applications"];
	CGFloat i = 0.0f;
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	NSArray *mobileApplications = [fileManager contentsOfDirectoryAtPath:mobileApplicationsPath error:NULL];
	for (NSString *relativePath in mobileApplications)
	{
		NSAutoreleasePool *archivePool = [[NSAutoreleasePool alloc] init];
		NSString *ipaPath = [mobileApplicationsPath stringByAppendingPathComponent:relativePath];
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:ipaPath error:NULL];
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
		[self.archives addObject:archive];
		
		NSDictionary *progressInfo = [NSDictionary dictionaryWithObjectsAndKeys:archive.appName, @"title", [NSNumber numberWithFloat:i / [mobileApplications count]], @"progress", nil];
		[self performSelectorOnMainThread:@selector(loadingDidProgress:) withObject:progressInfo waitUntilDone:NO];
		i = i + 1.0f;
		
		[archivePool drain];
	}
	
	[self performSelectorOnMainThread:@selector(archivesDidLoad) withObject:nil waitUntilDone:NO];
	
	[pool drain];
}

- (void) loadingDidProgress:(NSDictionary *)progressInfo
{
	self.appNameLabel.text = [progressInfo objectForKey:@"title"];
	self.progressView.progress = [[progressInfo objectForKey:@"progress"] floatValue];
}

- (void) archivesDidLoad
{
	[self.archiveLoadingView removeFromSuperview];
	[self.tableView reloadData];
}

- (void) viewDidLoad
{
	self.archiveLoadingView.frame = self.view.frame;
	[self.view addSubview:self.archiveLoadingView];
	
	self.title = self.tabBarItem.title;
	self.tableView.rowHeight = 57;
	
	self.archives = [NSMutableArray array];
	
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
	
	cell.textLabel.text = archive.appName;
	cell.imageView.image = archive.appIcon;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	IPAArchive *archive = [self.archives objectAtIndex:indexPath.row];
	ArtworkViewController *artworkViewController = [[[ArtworkViewController alloc] initWithArchive:archive] autorelease];
	[self.navigationController pushViewController:artworkViewController animated:YES];
}

@end
