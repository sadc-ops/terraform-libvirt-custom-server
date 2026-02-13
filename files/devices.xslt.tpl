<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/domain/devices">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>

%{ for gpu in gpus ~}
      <xsl:if test="not(hostdev[@type='pci' and source/address[
        @domain='${gpu.domain}' and @bus='${gpu.bus}' and @slot='${gpu.slot}' and @function='${gpu.function}'
      ]])">
        <hostdev mode="subsystem" type="pci" managed="yes">
          <driver name="vfio"/>
          <source>
            <address domain="${gpu.domain}" bus="${gpu.bus}" slot="${gpu.slot}" function="${gpu.function}"/>
          </source>
        </hostdev>
      </xsl:if>
%{ endfor ~}

    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>