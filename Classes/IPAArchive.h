//
//  IPAArchive.h
//  iOS Artwork Extractor
//
//  Created by Cédric Luthi on 30.12.11.
//  Copyright (c) 2011 Cédric Luthi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IPAArchive : NSObject

- (id) initWithPath:(NSString *)ipaPath;
@property (nonatomic, readonly, retain) NSString *path;

@property (nonatomic, readonly, retain) NSString *appName;
@property (nonatomic, readonly, retain) UIImage *appIcon;
@property (nonatomic, readonly, retain) NSArray *imageNames;

@property (nonatomic, readonly) BOOL iPhone;
@property (nonatomic, readonly) BOOL iPad;

- (UIImage *) imageNamed:(NSString *)imageName;

- (void) unload;

@end
