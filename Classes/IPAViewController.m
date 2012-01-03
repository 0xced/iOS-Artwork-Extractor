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

@property (nonatomic, retain) NSMutableArray *paths;
@property (nonatomic, retain) NSMutableArray *icons;

@end


@implementation IPAViewController

@synthesize paths = _paths;
@synthesize icons = _icons;

- (void) viewDidLoad
{
	self.tableView.rowHeight = 57;
	
	self.paths = [NSMutableArray array];
	self.icons = [NSMutableArray array];
	
	AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	NSString *mobileApplicationsPath = [[appDelegate homeDirectory] stringByAppendingPathComponent:@"/Music/iTunes/Mobile Applications"];
	for (NSString *relativePath in [[NSFileManager defaultManager] enumeratorAtPath:mobileApplicationsPath])
	{
		NSString *ipaPath = [mobileApplicationsPath stringByAppendingPathComponent:relativePath];
		[self.paths addObject:ipaPath];
		[self.icons addObject:[NSNull null]];
	}
}

- (void) viewDidUnload
{
	self.paths = nil;
	self.icons = nil;
}

// MARK: - UITableView data source

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.paths count];
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
	UIImage *icon = [self.icons objectAtIndex:indexPath.row];
	NSString *ipaPath = [self.paths objectAtIndex:indexPath.row];
	if (![icon isKindOfClass:[UIImage class]])
	{
		IPAArchive *archive = [[IPAArchive alloc] initWithPath:ipaPath];
		icon = archive.appIcon;
		[self.icons replaceObjectAtIndex:indexPath.row withObject:icon];
		[archive release];
	}
	
	cell.textLabel.text = [[ipaPath lastPathComponent] stringByDeletingPathExtension];
	cell.imageView.image = icon;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *ipaPath = [self.paths objectAtIndex:indexPath.row];
	ArtworkViewController *artworkViewController = [[[ArtworkViewController alloc] initWithIPAPath:ipaPath] autorelease];
	[self.navigationController pushViewController:artworkViewController animated:YES];
}

@end
