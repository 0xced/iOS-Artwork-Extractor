//
//  RunCMD.h
//  iOS Artwork Extractor
//
//  Created by Tom Kraina on 10/12/2018.
//  Copyright © 2018 Cédric Luthi. All rights reserved.
//

#ifndef RunCMD_h
#define RunCMD_h

#include <stdio.h>


/**
 Replacement for `system` function on iOS 11+
 Inspired by: https://github.com/libpd/pd-for-ios/issues/19#issuecomment-334133540

 @param cmd commnand
 */
void run_cmd(char *cmd);

#endif /* RunCMD_h */
