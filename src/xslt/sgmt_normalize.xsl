<?xml version="1.0" encoding="UTF-8"?>
<!-- SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0 -->
<!-- Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project -->
<!-- CLONE_GATE: icp-dag-crystallizer::xslt::sgmt_normalize -->
<!--
  SGMT Normalizer — transforms agent-submission XML into canonical SGMT form.
  Pipeline entry point: raw XML → XSLT → normalized sgmt:submission
-->
<xsl:stylesheet
    version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:sgmt="urn:sovereign:sgmt">

<xsl:output method="xml" indent="yes"/>

<xsl:mode on-no-match="shallow-skip"/>

<xsl:template match="/agent-submission">

  <sgmt:submission>

    <sgmt:identity
      agent="{@agent}"
      family="{@family}"
      language="{@language}"
      generation="{@generation}"
      submission="{@submission}"/>

    <sgmt:facts>
      <xsl:apply-templates select="facts/fact"/>
    </sgmt:facts>

    <sgmt:rules>
      <xsl:apply-templates select="rules/rule"/>
    </sgmt:rules>

    <sgmt:constraints>
      <xsl:apply-templates select="constraints/constraint"/>
    </sgmt:constraints>

    <sgmt:edges>
      <xsl:apply-templates select="dependencies/dependency"/>
    </sgmt:edges>

    <sgmt:proofs>
      <xsl:apply-templates select="proof-obligations/obligation"/>
    </sgmt:proofs>

    <sgmt:kernels>
      <xsl:apply-templates select="kernel-candidates/kernel"/>
    </sgmt:kernels>

  </sgmt:submission>

</xsl:template>

<xsl:template match="fact">
  <sgmt:fact
    predicate="{@predicate}"
    arity="{@arity}"
    confidence="{@confidence}">
    <xsl:value-of select="normalize-space(.)"/>
  </sgmt:fact>
</xsl:template>

<xsl:template match="rule">
  <sgmt:rule id="{@id}">
    <sgmt:head>
      <xsl:value-of select="normalize-space(head)"/>
    </sgmt:head>
    <sgmt:body>
      <xsl:value-of select="normalize-space(body)"/>
    </sgmt:body>
  </sgmt:rule>
</xsl:template>

<xsl:template match="constraint">
  <sgmt:constraint
    id="{@id}"
    domain="{@domain}"
    severity="{@severity}">
    <xsl:value-of select="normalize-space(.)"/>
  </sgmt:constraint>
</xsl:template>

<xsl:template match="dependency">
  <sgmt:edge
    from="{@from}"
    to="{@to}"
    relation="{@relation}"/>
</xsl:template>

<xsl:template match="obligation">
  <sgmt:proof
    id="{@id}"
    prover="{@prover}">
    <xsl:value-of select="normalize-space(.)"/>
  </sgmt:proof>
</xsl:template>

<xsl:template match="kernel">
  <sgmt:kernel
    id="{@id}"
    domain="{@domain}"
    purity="{@purity}">
    <xsl:value-of select="."/>
  </sgmt:kernel>
</xsl:template>

</xsl:stylesheet>
