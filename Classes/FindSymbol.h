#import <mach-o/loader.h>

void *FindSymbol(struct mach_header *image, const char *symbol);
