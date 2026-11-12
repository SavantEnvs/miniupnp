/* Fuzzes minixml's parsexml() with the IGD description callbacks, the same code path as
 * upstream's miniupnpc/src/testminixml.c (the legacy target of the same name). */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "minixml.h"
#include "igd_desc_parse.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	struct IGDdatas igd;
	struct xmlparser parser;
	char *buf = malloc(size ? size : 1);
	if (!buf) return 0;
	memcpy(buf, data, size);
	memset(&igd, 0, sizeof(igd));
	parser.xmlstart = buf;
	parser.xmlsize = (int)size;
	parser.data = &igd;
	parser.starteltfunc = IGDstartelt;
	parser.endeltfunc = IGDendelt;
	parser.datafunc = IGDdata;
	parser.attfunc = 0;
	parsexml(&parser);
	free(buf);
	return 0;
}
