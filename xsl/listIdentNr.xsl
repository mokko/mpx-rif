<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns="http://www.mpx.org/mpx" xmlns:mpx="http://www.mpx.org/mpx">

	<xsl:output method="xml" version="1.0" encoding="UTF-8"
		indent="yes" />
	<xsl:strip-space elements="*" />

	<xsl:template match="/">
		<xsl:for-each select="/mpx:museumPlusExport/mpx:sammlungsobjekt/mpx:identNr">
			<xsl:sort select="." />
			<xsl:message>
				<xsl:value-of select="." />
			</xsl:message>
		</xsl:for-each>
	</xsl:template>

</xsl:stylesheet>