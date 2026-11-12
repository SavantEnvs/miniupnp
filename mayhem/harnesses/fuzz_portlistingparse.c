/* Fuzzes ParsePortListing(): the parser for GetListOfPortMappings replies. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "portlistingparse.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	struct PortMappingParserData pdata;
	char *buf = malloc(size ? size : 1);
	if (!buf) return 0;
	memcpy(buf, data, size);
	memset(&pdata, 0, sizeof(pdata));
	ParsePortListing(buf, (int)size, &pdata);
	FreePortListing(&pdata);
	free(buf);
	return 0;
}
