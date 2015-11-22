#!/bin/bash

# TBD: honor system pre-defined property/variable files from 
# /etc/hadoop/ and other /etc config for spark, hdfs, hadoop, etc

# Force to use default Java which is JDK 1.7 now
export JAVA_HOME=/usr/java/default

if [ "x${ANT_HOME}" = "x" ] ; then
  export ANT_HOME=/opt/apache-ant
fi
if [ "x${MAVEN_HOME}" = "x" ] ; then
  export MAVEN_HOME=/opt/apache-maven
fi
if [ "x${M2_HOME}" = "x" ] ; then
  export M2_HOME=/opt/apache-maven
fi
if [ "x${MAVEN_OPTS}" = "x" ] ; then
  export MAVEN_OPTS="-Xmx2g -XX:MaxPermSize=1024M -XX:ReservedCodeCacheSize=512m"
fi
if [ "x${SCALA_HOME}" = "x" ] ; then
  export SCALA_HOME=/opt/scala
fi
if [ "x${HADOOP_VERSION}" = "x" ] ; then
  export HADOOP_VERSION=2.4.1
fi
if [ "x${SPARK_VERSION}" = "x" ] ; then
  export SPARK_VERSION=1.5.2
fi
# Spark 1.5+ default Hive starts with 1.2.1, backward compatible with Hive 1.2.0
if [ "x${HIVE_VERSION}" = "x" ] ; then
  export HIVE_VERSION=1.2.1
fi
# AE-1226 temp fix on the R PATH
if [ "x${R_HOME}" = "x" ] ; then
  export R_HOME=$(dirname $(rpm -ql $(rpm -qa | grep vcc-R_.*-0.2.0- | sort -r | head -n 1 ) | grep bin | head -n 1))
  if [ "x${R_HOME}" = "x" ] ; then
    echo "warn - R_HOME not defined, CRAN R isn't installed properly in the current env"
  else
    echo "ok - R_HOME redefined to $R_HOME based on installed RPM due to AE-1226"
  fi
fi

export PATH=$PATH:$M2_HOME/bin:$SCALA_HOME/bin:$ANT_HOME/bin:$JAVA_HOME/bin:$R_HOME

# Define default spark uid:gid and build version
# and all other Spark build related env
if [ "x${SPARK_APP_NAME}" = "x" ] ; then
  export SPARK_APP_NAME=sparkjobserver
fi
if [ "x${SPARK_GID}" = "x" ] ; then
  export SPARK_GID=411460017
fi
if [ "x${SPARK_UID}" = "x" ] ; then
  export SPARK_UID=411460024
fi
if [ "x${SPARK_JS_VERSION}" = "x" ] ; then
  export SPARK_JS_VERSION=0.6.1
fi
if [ "x${SPARK_JS_PLAIN_VERSION}" = "x" ] ; then
  export SPARK_JS_PLAIN_VERSION=0.6.1
fi

# Defines which Spark version to build against
SPARK_BUILD_VERSION=$SPARK_VERSION

# Define what goes into the RPM pkg name
if [ "x${SPARK_VERSION}" = "x1.4.1" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.spark141"
elif [ "x${SPARK_VERSION}" = "x1.4.2" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.spark142"
elif [ "x${SPARK_VERSION}" = "x1.5.2" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.spark152"
elif [ "x${SPARK_VERSION}" = "x1.6.0" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.spark160"
else
  echo "error - can't recognize altiscale's SPARK_VERSION=$SPARK_VERSION"
fi

# Defines which Hadoop version to build against
HADOOP_BUILD_VERSION=$HADOOP_VERSION

# Define what goes into the RPM pkg name
if [ "x${HADOOP_VERSION}" = "x2.2.0" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.hadoop22"
elif [ "x${HADOOP_VERSION}" = "x2.4.0" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.hadoop24"
elif [ "x${HADOOP_VERSION}" = "x2.4.1" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.hadoop24"
elif [ "x${HADOOP_VERSION}" = "x2.6.0" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.hadoop26"
elif [ "x${HADOOP_VERSION}" = "x2.7.0" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.hadoop27"
elif [ "x${HADOOP_VERSION}" = "x2.7.1" ] ; then
  export SPARK_JS_VERSION="$SPARK_JS_VERSION.hadoop27"
else
  echo "error - can't recognize altiscale's HADOOP_VERSION=$HADOOP_VERSION"
fi

if [ "x${ALTISCALE_RELEASE}" = "x" ] ; then
  if [ "x${HADOOP_VERSION}" = "x2.2.0" ] ; then
    ALTISCALE_RELEASE=2.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.4.0" ] ; then
    ALTISCALE_RELEASE=3.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.4.1" ] ; then
    ALTISCALE_RELEASE=3.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.7.0" ] ; then
    ALTISCALE_RELEASE=4.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.7.1" ] ; then
    ALTISCALE_RELEASE=4.0.0
  else
    echo "error - can't recognize altiscale's HADOOP_VERSION=$HADOOP_VERSION for ALTISCALE_RELEASE"
    exit -1
  fi 
else
  # OVerride human mistake
  if [ "x${HADOOP_VERSION}" = "x2.2.0" ] ; then
    ALTISCALE_RELEASE=2.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.4.0" ] ; then
    ALTISCALE_RELEASE=3.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.4.1" ] ; then
    ALTISCALE_RELEASE=3.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.6.0" ] ; then
    ALTISCALE_RELEASE=4.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.7.0" ] ; then
    ALTISCALE_RELEASE=4.0.0
  elif [ "x${HADOOP_VERSION}" = "x2.7.1" ] ; then
    ALTISCALE_RELEASE=4.0.0
  else
    echo "error - can't recognize altiscale's HADOOP_VERSION=$HADOOP_VERSION for ALTISCALE_RELEASE"
    exit -1
  fi
fi 
export ALTISCALE_RELEASE

# The branch for the application, NOT this build script
if [ "x${APPLICATION_BRANCH_NAME}" = "x" ] ; then
  export APPLICATION_BRANCH_NAME=altiscale-branch-0.6.1
  echo "warn - applying default branch $APPLICATION_BRANCH_NAME for this build, it is recommended to explicitly set this env APPLICATION_BRANCH_NAME var"
fi

if [ "x${BUILD_TIMEOUT}" = "x" ] ; then
  export BUILD_TIMEOUT=86400
fi

BUILD_TIME=$(date +%Y%m%d%H%M)
export BUILD_TIME

# Customize build OPTS for MVN
export MAVEN_OPTS="-Xmx2048m -XX:MaxPermSize=1024m"


