//
//  RunCMD.c
//  iOS Artwork Extractor
//
//  Created by Tom Kraina on 10/12/2018.
//  Copyright © 2018 Cédric Luthi. All rights reserved.
//

#include "RunCMD.h"
#include <spawn.h>
#include <sys/types.h>
#include <sys/wait.h>

extern char **environ;

void run_cmd(char *cmd)
{
	pid_t pid;
	char *argv[] = {"sh", "-c", cmd, NULL};
	int status;
	
	status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
	if (status == 0) {
		if (waitpid(pid, &status, 0) == -1) {
			perror("waitpid");
		}
	}
}
