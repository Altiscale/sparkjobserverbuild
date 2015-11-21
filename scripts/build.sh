#!/bin/bash

curr_dir=`dirname $0`
curr_dir=`cd $curr_dir; pwd`

sparkjs_spec="$curr_dir/sparkjs.spec"

mock_cfg="$curr_dir/altiscale-sparkjs-centos-6-x86_64.cfg"
mock_cfg_name=$(basename "$mock_cfg")
mock_cfg_runtime=`echo $mock_cfg_name | sed "s/.cfg/.runtime.cfg/"`
build_timeout=28800

maven_settings="$HOME/.m2/settings.xml"
maven_settings_spec="$curr_dir/alti-maven-settings.spec"

git_submodulename="spark-jobserver"
git_hash=""

if [ -f "$curr_dir/setup_env.sh" ]; then
  set -a
  source "$curr_dir/setup_env.sh"
  set +a
fi

if [ "x${SPARK_JS_VERSION}" = "x" ] ; then
  echo >&2 "fail - SPARK_JS_VERSION can't be empty"
  exit -8
else
  echo "ok - SPARK_JS_VERSION=$SPARK_JS_VERSION"
fi

if [ "x${SPARK_JS_PLAIN_VERSION}" = "x" ] ; then
  echo >&2 "fail - SPARK_JS_PLAIN_VERSION can't be empty"
  exit -8
else
  echo "ok - SPARK_JS_PLAIN_VERSION=$SPARK_JS_PLAIN_VERSION"
fi

if [ "x${BUILD_TIMEOUT}" = "x" ] ; then
  build_timeout=28800
else
  build_timeout=$BUILD_TIMEOUT
fi

if [ "x${WORKSPACE}" = "x" ] ; then
  WORKSPACE="$curr_dir/../"
fi

if [ ! -f "$maven_settings" ]; then
  echo "fatal - $maven_settings DOES NOT EXIST!!!! YOU MAY PULLING IN UNTRUSTED artifact and BREACH SECURITY!!!!!!"
  exit -9
fi

if [ ! -e "$sparkjs_spec" ] ; then
  echo "fail - missing $sparkjs_spec file, can't continue, exiting"
  exit -9
fi

cleanup_secrets()
{
  # Erase our track for any sensitive credentials if necessary
  rm -f $WORKSPACE/rpmbuild/RPMS/noarch/alti-maven-settings*.rpm
  rm -f $WORKSPACE/rpmbuild/RPMS/noarch/alti-maven-settings*.src.rpm
  rm -f $WORKSPACE/rpmbuild/SRPMS/alti-maven-settings*.src.rpm
  rm -rf $WORKSPACE/rpmbuild/SOURCES/alti-maven-settings*
}

env | sort

echo "checking if scala is installed on the system"
# this chk can be smarter, however, the build script will re-download the scala libs again during build process
# we can save some build time if we can just re-use the pre-installed scala
chk_scala_rpm=$(rpm -qa *scala*)
if [ "x${chk_scala_rpm}" = "x" -o ! -d "${SCALA_HOME}" ] ; then
  echo "warn - SCALA_HOME may or may not be defined, however, $SCALA_HOME folder doesn't exist."
  if [ ! -d "/opt/scala/" ] ; then
    echo "warn - scala isn't installed on the system?"
  else
    export SCALA_HOME=/opt/scala
  fi
else
  echo "ok - detected installed scala, SCALA_HOME=$SCALA_HOME"
fi

# should switch to WORKSPACE, current folder will be in WORKSPACE/spark due to 
# hadoop_ecosystem_component_build.rb => this script will change directory into your submodule dir
# WORKSPACE is the default path when jenkin launches e.g. /mnt/ebs1/jenkins/workspace/spark_build_test-alee
# If not, you will be in the $WORKSPACE/spark folder already, just go ahead and work on the submodule
# The path in the following is all relative, if the parent jenkin config is changed, things may break here.
pushd `pwd`
cd $WORKSPACE/$git_submodulename

if [ "x${APPLICATION_BRANCH_NAME}" = "x" ] ; then
  echo "error - APPLICATION_BRANCH_NAME is not defined, even though, you may checkout the code from hadoop_ecosystem_component_build, this does not gurantee you have the right branch. Please specify the APPLICATION_BRANCH_NAME explicitly. Exiting!"
  exit -9
fi
echo "ok - switching to spark branch $APPLICATION_BRANCH_NAME and refetch the files"
git checkout $APPLICATION_BRANCH_NAME
git fetch --all
git_hash=$(git rev-parse HEAD | tr -d '\n')
popd

echo "ok - tar zip source file, preparing for build/compile by rpmbuild"
# spark is located at $WORKSPACE/spark
# tar cvzf $WORKSPACE/spark.tar.gz spark

# Looks like this is not installed on all machines
# rpmdev-setuptree
sparkjs_tar="sparkjs.tar"
mkdir -p $WORKSPACE/rpmbuild/{BUILD,BUILDROOT,RPMS,SPECS,SOURCES,SRPMS}/
cp "$sparkjs_spec" $WORKSPACE/rpmbuild/SPECS/sparkjs.spec
pushd $WORKSPACE/
tar --exclude .git --exclude .gitignore -cf $WORKSPACE/rpmbuild/SOURCES/${sparkjs_tar} $git_submodulename test_sparkjs
popd
pushd "$WORKSPACE/rpmbuild/SOURCES/"
tar -xf $sparkjs_tar
if [ -d alti-sparkjobserver ] ; then
  rm -rf alti-sparkjobserver
fi
mv $git_submodulename alti-sparkjobserver
cp -rp test_sparkjs alti-sparkjobserver/
tar --exclude .git --exclude .gitignore -czf alti-sparkjobserver.tar.gz alti-sparkjobserver
if [ -f "$maven_settings" ] ; then
  mkdir -p  alti-maven-settings
  cp "$maven_settings" alti-maven-settings/
  tar -cvzf alti-maven-settings.tar.gz alti-maven-settings
  cp "$maven_settings_spec" $WORKSPACE/rpmbuild/SPECS/
fi
popd

# Build alti-maven-settings RPM separately so it doesn't get exposed to spark's SRPM or any external trace
rpmbuild -vv -ba $WORKSPACE/rpmbuild/SPECS/alti-maven-settings.spec --define "_topdir $WORKSPACE/rpmbuild" --buildroot $WORKSPACE/rpmbuild/BUILDROOT/
if [ $? -ne "0" ] ; then
  echo "fail - alti-maven-settings SRPM build failed"
  cleanup_secrets
  exit -95
fi

# The patches is no longer needed since we merge the results into a branch on github.
# cp $WORKSPACE/patches/* $WORKSPACE/rpmbuild/SOURCES/

echo "ok - applying version number $SPARK_JS_VERSION and release number $BUILD_TIME, the pattern delimiter is / here"
sed -i "s/SPARK_JS_VERSION_REPLACE/$SPARK_JS_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_JS_PLAINVERSION_REPLACE/$SPARK_JS_PLAIN_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s:CURRENT_WORKSPACE_REPLACE:$WORKSPACE:g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/HADOOP_VERSION_REPLACE/$HADOOP_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/HADOOP_BUILD_VERSION_REPLACE/$HADOOP_BUILD_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_USER/$SPARK_USER/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_GID/$SPARK_GID/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_UID/$SPARK_UID/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/BUILD_TIME/$BUILD_TIME/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/ALTISCALE_RELEASE/$ALTISCALE_RELEASE/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/GITHASH_REV_RELEASE/$git_hash/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
SCALA_HOME=$SCALA_HOME rpmbuild -vv -bs $WORKSPACE/rpmbuild/SPECS/sparkjs.spec --define "_topdir $WORKSPACE/rpmbuild" --buildroot $WORKSPACE/rpmbuild/BUILDROOT/

if [ $? -ne "0" ] ; then
  echo "fail - spark SRPM build failed"
  cleanup_secrets
  exit -98
fi

stat "$WORKSPACE/rpmbuild/SRPMS/alti-spark-${SPARK_JS_VERSION}-${SPARK_JS_VERSION}-${ALTISCALE_RELEASE}.${BUILD_TIME}.el6.src.rpm"
rpm -ivvv "$WORKSPACE/rpmbuild/SRPMS/alti-spark-${SPARK_JS_VERSION}-${SPARK_JS_VERSION}-${ALTISCALE_RELEASE}.${BUILD_TIME}.el6.src.rpm"

echo "ok - applying $WORKSPACE for the new BASEDIR for mock, pattern delimiter here should be :"
# the path includeds /, so we need a diff pattern delimiter

mkdir -p "$WORKSPACE/var/lib/mock"
chmod 2755 "$WORKSPACE/var/lib/mock"
mkdir -p "$WORKSPACE/var/cache/mock"
chmod 2755 "$WORKSPACE/var/cache/mock"
sed "s:BASEDIR:$WORKSPACE:g" "$mock_cfg" > "$curr_dir/$mock_cfg_runtime"
sed -i "s:SPARK_JS_VERSION:$SPARK_JS_VERSION:g" "$curr_dir/$mock_cfg_runtime"
echo "ok - applying mock config $curr_dir/$mock_cfg_runtime"
cat "$curr_dir/$mock_cfg_runtime"

# The following initialization is not cool, need a better way to manage this
# mock -vvv --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --scrub=all
mock -vvv --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --init

mock -vvv --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --no-clean --no-cleanup-after --install $WORKSPACE/rpmbuild/RPMS/noarch/alti-maven-settings-1.0-1.el6.noarch.rpm

mock -vvv --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --no-clean --rpmbuild_timeout=$build_timeout --resultdir=$WORKSPACE/rpmbuild/RPMS/ --rebuild $WORKSPACE/rpmbuild/SRPMS/alti-spark-${SPARK_JS_VERSION}-${SPARK_JS_VERSION}-${ALTISCALE_RELEASE}.${BUILD_TIME}.el6.src.rpm

if [ $? -ne "0" ] ; then
  echo "fail - mock RPM build failed"
  cleanup_secrets
  # mock --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --clean
  mock --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --scrub=all
  exit -99
fi

# mock --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --clean
mock --configdir=$curr_dir -r altiscale-sparkjs-centos-6-x86_64.runtime --scrub=all

# Delete all src.rpm in the RPMS folder since this is redundant and copied by the mock process
rm -f $WORKSPACE/rpmbuild/RPMS/*.src.rpm

cleanup_secrets

echo "ok - build Completed successfully!"

exit 0












