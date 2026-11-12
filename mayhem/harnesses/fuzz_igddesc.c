/* Fuzzes parserootdesc() (the IGD root description parser) and the URL building done on its result. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "igd_desc_parse.h"
#include "miniupnpc.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	struct IGDdatas igd;
	struct UPNPUrls urls;
	char *buf = malloc(size ? size : 1);
	if (!buf) return 0;
	memcpy(buf, data, size);
	memset(&igd, 0, sizeof(igd));
	parserootdesc(buf, (int)size, &igd);
	memset(&urls, 0, sizeof(urls));
	GetUPNPUrls(&urls, &igd, "http://192.168.0.1:5000/rootDesc.xml", 0);
	FreeUPNPUrls(&urls);
	free(buf);
	return 0;
}
