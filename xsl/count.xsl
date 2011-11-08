<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.mpx.org/mpx"
	xmlns:mpx="http://www.mpx.org/mpx">

	<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />
	<xsl:strip-space elements="*" />

	<xsl:template match="/">
		<xsl:message>
			<xsl:text>PersonenKörperschaften: </xsl:text>
			<xsl:value-of select="count (/mpx:museumPlusExport/mpx:personKörperschaft)" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text>Sammlungsobjekte: </xsl:text>
			<xsl:value-of select="count (/mpx:museumPlusExport/mpx:sammlungsobjekt)" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text> Sammlungsobjekte mit Resource: </xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:sammlungsobjekt[
				/mpx:museumPlusExport/mpx:multimediaobjekt/mpx:verknüpftesObjekt=@objId
			])" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text> Sammlungsobjekte mit Bild: </xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:sammlungsobjekt[
				/mpx:museumPlusExport/mpx:multimediaobjekt[
					@typ='Bild'
				]/mpx:verknüpftesObjekt=@objId
			])" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text> Sammlungsobjekte mit freigegebenen Bild: </xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:sammlungsobjekt[
				/mpx:museumPlusExport/mpx:multimediaobjekt[
					@typ='Bild' and 
					@freigabe='web' or 
					@freigabe='Web'
				]/mpx:verknüpftesObjekt=@objId
			])" />
			<xsl:text>&#10;</xsl:text>


			<xsl:text>multimediaobjekt (Resourcen): </xsl:text>
			<xsl:value-of select="count (/mpx:museumPlusExport/mpx:multimediaobjekt)" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text> Bilder insgesamt: </xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:multimediaobjekt[@typ = 'Bild'])" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text> davon Standardbilder: </xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:multimediaobjekt/mpx:standardbild)" />
			<xsl:text>&#10;</xsl:text>

			<xsl:text> Bilder freigegeben: </xsl:text>
			<xsl:value-of
				select="count (/mpx:museumPlusExport/mpx:multimediaobjekt[
					@typ = 'Bild' and 
					@freigabe ='Web' or 
					@freigabe ='web'])" />
			<xsl:text>&#10;</xsl:text>

		</xsl:message>
	</xsl:template>

</xsl:stylesheet>