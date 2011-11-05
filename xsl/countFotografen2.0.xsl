<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns="http://www.mpx.org/mpx" xmlns:mpx="http://www.mpx.org/mpx">
	<xsl:template match="/">

		<xsl:for-each-group
			select="/mpx:museumPlusExport/mpx:multimediaobjekt/mpx:multimediaUrhebFotograf"
			group-by=".">
			<xsl:sort select="." />
			<xsl:message>
				<xsl:value-of select="." />
				<xsl:text>: </xsl:text>
				<xsl:value-of select="count (current-group())" />
			</xsl:message>
		</xsl:for-each-group>




	</xsl:template>

</xsl:stylesheet>