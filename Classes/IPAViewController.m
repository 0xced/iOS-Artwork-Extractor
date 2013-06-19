//
//  IPAViewController.m
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 30.12.11.
//  Copyright (c) 2011 Cédric Luthi. All rights reserved.
//

#import "IPAViewController.h"

#import "AppDelegate.h"
#import "ArtworkViewController.h"
#import "IPAArchive.h"
#import "NSString+IPAArchive.h"

@implementation IPAViewController

@synthesize archives = _archives;

- (void) reloadRowsAtIndexPaths:(NSArray *)indexPaths
{
	if ([NSThread isMainThread])
	{
		[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
		[self.searchDisplayController.searchResultsTableView reloadData];
	}
	else
		[self performSelectorOnMainThread:_cmd withObject:indexPaths waitUntilDone:NO];
}

- (void) loadArchives
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSUInteger i = 0;
	for (NSString *ipaPath in [[self.archives copy] autorelease])
	{
		NSAutoreleasePool *archivePool = [[NSAutoreleasePool alloc] init];
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:ipaPath error:NULL];
		if ([attributes fileSize] > 500 * 1024 * 1024)
		{
			NSLog(@"Skipped %@ (too big)", [ipaPath lastPathComponent]);
			i++;
			continue;
		}
		IPAArchive *archive = [[[IPAArchive alloc] initWithPath:ipaPath] autorelease];
		if ([archive.imageNames count] == 0)
		{
			NSLog(@"Skipped %@ (no images)", [ipaPath lastPathComponent]);
			i++;
			continue;
		}
		[archive unload];
		[self.archives replaceObjectAtIndex:i withObject:archive];
		
		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:i++ inSection:0]];
		[self reloadRowsAtIndexPaths:indexPaths];
		
		[archivePool drain];
	}
	
	[pool drain];
}

- (void) viewDidLoad
{
	self.title = self.tabBarItem.title;
	self.tableView.rowHeight = [UIImage imageNamed:@"Unknown.png"].size.height;
	
	[self performSelectorInBackground:@selector(loadArchives) withObject:nil];
}

- (void) viewDidUnload
{
	self.archives = nil;
}

// MARK: - UITableView data source

- (NSMutableArray *) archivesForTableView:(UITableView *)tableView
{
	NSMutableArray *archives = self.archives;
	if (tableView == self.searchDisplayController.searchResultsTableView)
	{
		NSString *searchText = [NSString stringWithFormat:@"*%@*", self.searchDisplayController.searchBar.text];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"appName LIKE[c] %@", searchText];
		archives = [NSMutableArray arrayWithArray:[archives filteredArrayUsingPredicate:predicate]];
	}
	
	return archives;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[self archivesForTableView:tableView] count];
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
	IPAArchive *archive = [[self archivesForTableView:tableView] objectAtIndex:indexPath.row];
	NSString *path = [archive isKindOfClass:[IPAArchive class]] ? archive.path : (NSString *)archive;
	UIImage *icon = [archive isKindOfClass:[IPAArchive class]] ? archive.appIcon : [UIImage imageNamed:@"Unknown.png"];
	
	cell.textLabel.text = [path appName];
	cell.imageView.image = icon;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSMutableArray *archives = [self archivesForTableView:tableView];
	IPAArchive *archive = [archives objectAtIndex:indexPath.row];
	if (![archive isKindOfClass:[IPAArchive class]])
	{
		NSString *path = (NSString *)archive;
		archive = [[[IPAArchive alloc] initWithPath:path] autorelease];
		[archives replaceObjectAtIndex:indexPath.row withObject:archive];
	}
	ArtworkViewController *artworkViewController = [[[ArtworkViewController alloc] initWithArchive:archive] autorelease];
	[self.navigationController pushViewController:artworkViewController animated:YES];
}

// MARK: - Search Display Delegate

- (void) searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
	tableView.backgroundColor = self.tableView.backgroundColor;
	tableView.rowHeight = self.tableView.rowHeight;
}

@end
