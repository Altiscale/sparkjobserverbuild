%global apache_name            SPARK_APP_NAME
%global spark_uid              SPARK_UID
%global spark_gid              SPARK_GID

%define git_hash_release       GITHASH_REV_RELEASE
%define altiscale_release_ver  ALTISCALE_RELEASE
%define rpm_package_name       alti-sparkjobserver
%define sparkjs_version        SPARK_JS_VERSION_REPLACE
%define sparkjs_plain_version  SPARK_JS_PLAINVERSION_REPLACE
%define current_workspace      CURRENT_WORKSPACE_REPLACE
%define hadoop_version         HADOOP_VERSION_REPLACE
%define hadoop_build_version   HADOOP_BUILD_VERSION_REPLACE
%define build_service_name     alti-sparkjobserver
%define sparkjs_folder_name    %{rpm_package_name}-%{sparkjs_version}
%define sparkjs_testsuite_name %{sparkjs_folder_name}
%define install_sparkjs_dest   /opt/%{sparkjs_folder_name}
%define install_sparkjs_bin    /opt/%{sparkjs_folder_name}/bin
%define install_sparkjs_label  /opt/%{sparkjs_folder_name}/VERSION
%define install_sparkjs_conf   /opt/%{sparkjs_folder_name}/config
%define install_sparkjs_logs   /service/log/%{apache_name}
%define build_release          BUILD_TIME

Name: %{rpm_package_name}-%{sparkjs_version}
Summary: %{sparkjs_folder_name} RPM Installer AE-1541
Version: %{sparkjs_version}
Release: %{altiscale_release_ver}.%{build_release}%{?dist}
License: ASL 2.0
Group: Development/Libraries
Source: %{_sourcedir}/%{build_service_name}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{release}-root-%{build_service_name}
Requires(pre): shadow-utils
Requires: scala >= 2.10.4
# BuildRequires: vcc-hive-%{hive_version}
BuildRequires: scala >= 2.10.4
BuildRequires: apache-maven >= 3.3.3
BuildRequires: jdk >= 1.7.0.51

Url: https://github.com/spark-jobserver/spark-jobserver
%description
Build from TBD with 
build script TBD 
Origin source form https://github.com/spark-jobserver/spark-jobserver/TBD
%{sparkjs_folder_name} is a re-compiled and packaged spark distro that is compiled against Altiscale's 
Hadoop 2.7.x with YARN 2.7.x enabled, and spark-1.5+. This package should work with Altiscale 
Hadoop 2.7.1 and (vcc-hadoop-2.7.1 and alti-spark-1.5.x+).

%pre

%prep

%setup -q -n %{build_service_name}

%build
if [ "x${SCALA_HOME}" = "x" ] ; then
  echo "ok - SCALA_HOME not defined, trying to set SCALA_HOME to default location /opt/scala/"
  export SCALA_HOME=/opt/scala/
fi
if [ "x${JAVA_HOME}" = "x" ] ; then
  export JAVA_HOME=/usr/java/default
  # Hijack JAva path to use our JDK 1.7 here instead of openjdk
  export PATH=$JAVA_HOME/bin:$PATH
fi
export MAVEN_OPTS="-Xmx2048m -XX:MaxPermSize=1024m"

echo "build - spark job server in %{_builddir}"
pushd `pwd`
cd %{_builddir}/%{build_service_name}/

if [ "x%{hadoop_version}" = "x" ] ; then
  echo "fatal - HADOOP_VERSION needs to be set, can't build anything, exiting"
  exit -8
else
  export SPARK_HADOOP_VERSION=%{hadoop_version}
  echo "ok - applying customized hadoop version $SPARK_HADOOP_VERSION"
fi

if [ "x%{hadoop_build_version}" = "x" ] ; then
  echo "fatal - hadoop_build_version needs to be set, can't build anything, exiting"
  exit -8
fi

env | sort

echo "ok - building assembly with HADOOP_VERSION=$SPARK_HADOOP_VERSION"

# PURGE LOCAL CACHE for clean build
# mvn dependency:purge-local-repository

########################
# BUILD ENTIRE PACKAGE #
########################
# This will build the overall JARs we need in each folder
# and install them locally for further reference. We assume the build
# environment is clean, so we don't need to delete ~/.ivy2 and ~/.m2
# Default JDK version applied is 1.7 here.

if [ -f /etc/alti-maven-settings/settings.xml ] ; then
  echo "ok - applying local maven repo settings.xml for first priority"
  if [[ $SPARK_HADOOP_VERSION == 2.4.* ]] ; then
    mvn -U -X -Phadoop-2.4 -Pspark-1.4 --settings /etc/alti-maven-settings/settings.xml --global-settings /etc/alti-maven-settings/settings.xml -DskipTests compile package
  elif [[ $SPARK_HADOOP_VERSION == 2.7.* ]] ; then
    mvn -U -X -Phadoop-2.7 -Pspark-1.5 --settings /etc/alti-maven-settings/settings.xml --global-settings /etc/alti-maven-settings/settings.xml -DskipTests compile package
  else
    echo "fatal - Unrecognize hadoop version $SPARK_HADOOP_VERSION, can't continue, exiting, no cleanup"
    exit -9
  fi
else
  echo "ok - applying default repository form pom.xml"
  if [[ $SPARK_HADOOP_VERSION == 2.4.* ]] ; then
    mvn -U -X -Phadoop-2.4 -Pspark-1.4 -DskipTests compile package
  elif [[ $SPARK_HADOOP_VERSION == 2.7.* ]] ; then
    mvn -U -X -Phadoop-2.7 -Pspark-1.5 -DskipTests compile package
  else
    echo "fatal - Unrecognize hadoop version $SPARK_HADOOP_VERSION, can't continue, exiting, no cleanup"
    exit -9
  fi
fi
popd
echo "ok - build spark job server completed successfully!"

%install
# manual cleanup for compatibility, and to be safe if the %clean isn't implemented
rm -rf %{buildroot}%{install_sparkjs_dest}
# re-create installed dest folders
mkdir -p %{buildroot}%{install_sparkjs_dest}
echo "compiled/built folder is (not the same as buildroot) RPM_BUILD_DIR = %{_builddir}"
echo "test installtion folder (aka buildroot) is RPM_BUILD_ROOT = %{buildroot}"
echo "test install spark dest = %{buildroot}/%{install_sparkjs_dest}"
echo "test install spark label sparkjs_folder_name = %{sparkjs_folder_name}"
%{__mkdir} -p %{buildroot}%{install_sparkjs_dest}/
%{__mkdir} -p %{buildroot}%{install_sparkjs_bin}/
%{__mkdir} -p %{buildroot}%{install_sparkjs_conf}/
%{__mkdir} -p %{buildroot}%{install_sparkjs_dest}/akka-app/target/
%{__mkdir} -p %{buildroot}%{install_sparkjs_dest}/job-server-api/target/
%{__mkdir} -p %{buildroot}%{install_sparkjs_dest}/job-server/target/
# work and logs folder is for runtime, this is a dummy placeholder here to set the right permission within RPMs
# logs folder should coordinate with log4j and be redirected to /var/log for syslog/flume to pick up
%{__mkdir} -p %{buildroot}%{install_sparkjs_logs}
# copy all necessary jars
cp -rp %{_builddir}/%{build_service_name}/akka-app/target/*.jar %{buildroot}/%{install_sparkjs_dest}/akka-app/target/
cp -rp %{_builddir}/%{build_service_name}/job-server-api/target/*.jar %{buildroot}/%{install_sparkjs_dest}/job-server-api/target/
cp -rp %{_builddir}/%{build_service_name}/job-server/target/*.jar %{buildroot}/%{install_sparkjs_dest}/job-server/target/

# deploy the config folder
cp -rp %{_builddir}/%{build_service_name}/job-server/config/* %{buildroot}/%{install_sparkjs_conf}

# Inherit license, readme, etc
cp -p %{_builddir}/%{build_service_name}/README.md %{buildroot}%{install_sparkjs_dest}
cp -p %{_builddir}/%{build_service_name}/LICENSE.md %{buildroot}%{install_sparkjs_dest}

# This will capture the installation property form this spec file for further references
rm -f %{buildroot}/%{install_sparkjs_label}
touch %{buildroot}/%{install_sparkjs_label}
echo "name=%{name}" >> %{buildroot}/%{install_sparkjs_label}
echo "version=%{sparkjs_version}" >> %{buildroot}/%{install_sparkjs_label}
echo "release=%{name}-%{release}" >> %{buildroot}/%{install_sparkjs_label}
echo "git_rev=%{git_hash_release}" >> %{buildroot}/%{install_sparkjs_label}

# add dummy file to warn user that CLUSTER mode is not for Production
echo "DO NOT HAND EDIT, DEPLOYED BY RPM and CHEF" >  %{buildroot}%{install_sparkjs_conf}/DO_NOT_HAND_EDIT.txt
echo "THIS IS A SNAPSHOT BUILD, see VERSION file for more details" >  %{buildroot}%{install_sparkjs_dest}/THIS_IS_A_SNAPSHOT_BUILD.txt

%clean
echo "ok - cleaning up temporary files, deleting %{buildroot}%{install_sparkjs_dest}"
rm -rf %{buildroot}%{install_sparkjs_dest}

%files
%defattr(0644,spark,spark,0644)
%attr(0444,spark,spark) %{install_sparkjs_dest}/THIS_IS_A_SNAPSHOT_BUILD.txt
%attr(0644,spark,spark) %{install_sparkjs_dest}/akka-app/target
%attr(0644,spark,spark) %{install_sparkjs_dest}/job-server-api/target
%attr(0644,spark,spark) %{install_sparkjs_dest}/job-server/target
%docdir %{install_sparkjs_dest}/doc
%doc %{install_sparkjs_label}
%doc %{install_sparkjs_dest}/LICENSE.md
%doc %{install_sparkjs_dest}/README.md
%attr(0755,spark,spark) %{install_sparkjs_conf}/*.sh
%attr(0644,spark,spark) %{install_sparkjs_conf}/*.properties
%attr(0644,spark,spark) %{install_sparkjs_conf}/*.conf
%attr(0644,spark,spark) %{install_sparkjs_conf}/*.template
%attr(0444,spark,spark) %{install_sparkjs_conf}/DO_NOT_HAND_EDIT.txt
%attr(1777,spark,spark) %{install_sparkjs_logs}
%config(noreplace) %{install_sparkjs_conf}

%post
if [ "$1" = "1" ]; then
  echo "ok - performing fresh installation"
elif [ "$1" = "2" ]; then
  echo "ok - upgrading system"
fi
rm -vf /opt/%{apache_name}/logs
rm -vf /opt/%{apache_name}
ln -vsf %{install_sparkjs_dest} /opt/%{apache_name}
ln -vsf %{install_sparkjs_logs} /opt/%{apache_name}/logs

%postun
if [ "$1" = "0" ]; then
  ret=$(rpm -qa | grep %{rpm_package_name} | grep -v test | wc -l)
  if [ "x${ret}" != "x0" ] ; then
    echo "ok - detected other spark job server version, no need to clean up symbolic links"
    echo "ok - cleaning up version specific directories only regarding this uninstallation"
    rm -vrf %{install_sparkjs_dest}
    rm -vrf %{install_sparkjs_conf}
  else
    echo "ok - uninstalling %{rpm_package_name} on system, removing symbolic links"
    rm -vf /opt/%{apache_name}/logs
    rm -vf /opt/%{apache_name}
    rm -vrf %{install_sparkjs_dest}
    rm -vrf %{install_sparkjs_conf}
  fi
fi
# Don't delete the users after uninstallation.

%changelog
* Sat Nov 21 2015 Andrew Lee 20151121
- First working version for this spec file
