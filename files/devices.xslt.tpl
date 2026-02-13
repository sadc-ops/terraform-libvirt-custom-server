<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

%{ if machine != null && machine == "q35" ~}
  <!-- =========================================================================================================
       FIX 1: Rewrite cdrom target bus from "ide" to "sata". Applies to ALL cdrom disks (cloud-init or otherwise)
       ========================================================================================================= -->
  <xsl:template match="/domain/devices/disk[@device='cdrom']/target/@bus[.='ide']">
    <xsl:attribute name="bus">
      <xsl:value-of select="'sata'"/>
    </xsl:attribute>
  </xsl:template>

  <!-- =============================================================================================================
       FIX 2: Rewrite cdrom target dev from hd* to sd*.The provider typically sets "hdd"; remap to "sda".
       We match any "hd" prefixed dev on a cdrom to be safe.
       ========================================================================================================= -->
  <xsl:template match="/domain/devices/disk[@device='cdrom']/target/@dev[starts-with(.,'hd')]">
    <xsl:attribute name="dev">
      <xsl:value-of select="concat('sd', substring(., 3))"/>
    </xsl:attribute>
  </xsl:template>

  <!-- =============================================================================================================
       FIX 3: Strip <address> from cdrom disks IDE address elements (type="drive", controller/bus/unit for IDE)
       are invalid on SATA and will cause libvirt to error. Removing them lets libvirt auto-assign a valid SATA address.
       ========================================================================================================== -->
  <xsl:template match="/domain/devices/disk[@device='cdrom']/address"/>

  <!-- ==============================================================================================================
       FIX 4: Strip <alias> from cdrom disks. Stale alias names (e.g. "ide0-1-1") become invalid after
       the bus change. Libvirt will regenerate correct aliases.
       ========================================================================================================== -->
  <xsl:template match="/domain/devices/disk[@device='cdrom']/alias"/>
%{ endif ~}

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

%{ for t in nic_tuning ~}
  <xsl:template match="domain/devices/interface[@type='network' and source/@network='${t.network_name}']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="node()"/>

      <xsl:if test="not(driver)">
        <driver name="vhost" queues="${t.vhost_queues}"/>
      </xsl:if>

    </xsl:copy>
  </xsl:template>

  <xsl:template match="domain/devices/interface[@type='network' and source/@network='${t.network_name}']/driver">
    <xsl:copy>
      <xsl:copy-of select="@*[local-name() != 'name' and local-name() != 'queues']"/>
      <xsl:attribute name="name">vhost</xsl:attribute>
      <xsl:attribute name="queues">${t.vhost_queues}</xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>
%{ endfor ~}

</xsl:stylesheet>