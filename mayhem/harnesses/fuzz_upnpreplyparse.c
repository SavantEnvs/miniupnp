/* Fuzzes ParseNameValue(): the parser for UPnP SOAP replies. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "upnpreplyparse.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	struct NameValueParserData pdata;
	char *buf = malloc(size ? size : 1);
	if (!buf) return 0;
	memcpy(buf, data, size);
	ParseNameValue(buf, (int)size, &pdata);
	(void)GetValueFromNameValueList(&pdata, "NewExternalIPAddress");
	(void)GetValueFromNameValueList(&pdata, "errorCode");
	ClearNameValueList(&pdata);
	free(buf);
	return 0;
}
