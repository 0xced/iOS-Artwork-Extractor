#import "FindSymbol.h"

#import <mach-o/nlist.h>
#import <string.h>

// Adapted from MoreAddrToSym / GetFunctionName()
// http://www.opensource.apple.com/source/openmpi/openmpi-8/openmpi/opal/mca/backtrace/darwin/MoreBacktrace/MoreDebugging/MoreAddrToSym.c
void *FindSymbol(struct mach_header *image, const char *symbol)
{
	if ((image == NULL) || (symbol == NULL))
		return NULL;
	
	struct segment_command *seg_linkedit = NULL;
	struct segment_command *seg_text = NULL;
	struct symtab_command *symtab = NULL;
	unsigned int index;
	
	struct load_command *cmd = (struct load_command*)((char*)image + sizeof(struct mach_header));
	for (index = 0; index < image->ncmds; index += 1, cmd = (struct load_command*)((char*)cmd + cmd->cmdsize))
	{
		switch(cmd->cmd)
		{
			case LC_SEGMENT:
				if (!strcmp(((struct segment_command*)cmd)->segname, SEG_TEXT))
					seg_text = (struct segment_command*)cmd;
				else if (!strcmp(((struct segment_command*)cmd)->segname, SEG_LINKEDIT))
					seg_linkedit = (struct segment_command*)cmd;
				break;
				
			case LC_SYMTAB:
				symtab = (struct symtab_command*)cmd;
				break;
		}
	}
	
	if ((seg_text == NULL) || (seg_linkedit == NULL) || (symtab == NULL))
		return NULL;
	
	unsigned int vm_slide = (unsigned long)image - (unsigned long)seg_text->vmaddr;
	unsigned int file_slide = ((unsigned long)seg_linkedit->vmaddr - (unsigned long)seg_text->vmaddr) - seg_linkedit->fileoff;
	struct nlist *symbase = (struct nlist*)((unsigned long)image + (symtab->symoff + file_slide));
	char *strings = (char*)((unsigned long)image + (symtab->stroff + file_slide));
	struct nlist *sym;
	
	for (index = 0, sym = symbase; index < symtab->nsyms; index += 1, sym += 1)
	{
		if (sym->n_un.n_strx != 0 && !strcmp(symbol, strings + sym->n_un.n_strx))
		{
			unsigned int address = vm_slide + sym->n_value;
			if (sym->n_desc & N_ARM_THUMB_DEF)
				return (void*)(address | 1);
			else
				return (void*)(address);
		}
	}
	
	return NULL;
}
