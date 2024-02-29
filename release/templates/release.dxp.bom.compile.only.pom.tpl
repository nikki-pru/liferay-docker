<?xml version="1.0" encoding="UTF-8"?>
<project xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.liferay.portal</groupId>
    <artifactId>release.dxp.bom.compile.only</artifactId>
    <version>__PRODUCT_VERSION__-__BUILD_TIMESTAMP__</version>
    <packaging>pom</packaging>
    <licenses>
      <license>
        <name>LGPL 2.1</name>
        <url>http://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt</url>
      </license>
    </licenses>
    <developers>
        <developer>
            <name>Brian Wing Shun Chan</name>
            <organization>Liferay, Inc.</organization>
            <organizationUrl>http://www.liferay.com</organizationUrl>
        </developer>
    </developers>
    <scm>
        <connection>scm:git:git@github.com:liferay/liferay-dxp.git</connection>
        <developerConnection>scm:git:git@github.com:liferay/liferay-dxp.git</developerConnection>
        <tag>__PRODUCT_VERSION__</tag>
        <url>https://github.com/liferay/liferay-dxp</url>
    </scm>
    <repositories>
        <repository>
            <id>liferay-public-releases</id>
            <name>Liferay Public Releases</name>
            <url>https://repository-cdn.liferay.com/nexus/content/repositories/liferay-public-releases/</url>
        </repository>
    </repositories>
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>com.liferay.portal</groupId>
                <artifactId>release.dxp.api</artifactId>
                <version>__PRODUCT_VERSION__-__BUILD_TIMESTAMP__</version>
            </dependency>
