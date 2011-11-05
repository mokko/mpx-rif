<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns="http://www.mpx.org/mpx" xmlns:mpx="http://www.mpx.org/mpx">

	<xsl:output method="xml" version="1.0" encoding="UTF-8"
		indent="yes" />
	<xsl:strip-space elements="*" />

	<xsl:template match="/">
		<xsl:message>
			<xsl:text>#PersonKörperschaft:</xsl:text>
			<xsl:value-of select="count (/mpx:museumPlusExport/mpx:personKörperschaft)" />
			<xsl:text>
		</xsl:text>

			<xsl:text>#multimediaobjekt:</xsl:text>
			<xsl:value-of select="count (/mpx:museumPlusExport/mpx:multimediaobjekt)" />
			<xsl:text>
		</xsl:text>

			<xsl:text>#sammlungsobjekt:</xsl:text>
			<xsl:value-of select="count (/mpx:museumPlusExport/mpx:sammlungsobjekt)" />
			<xsl:text>
		</xsl:text>

			<xsl:text>#standardbilder:</xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:multimediaobjekt/mpx:standardbild)" />
			<xsl:text>
		</xsl:text>
		</xsl:message>

	</xsl:template>

</xsl:stylesheet>