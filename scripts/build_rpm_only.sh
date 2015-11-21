#!/bin/bash

curr_dir=`dirname $0`
curr_dir=`cd $curr_dir; pwd`

sparkjs_spec="$curr_dir/sparkjs.spec"

mock_cfg="$curr_dir/altiscale-sparkjs-centos-6-x86_64.cfg"
mock_cfg_name=$(basename "$mock_cfg")
mock_cfg_runtime=`echo $mock_cfg_name | sed "s/.cfg/.runtime.cfg/"`
build_timeout=14400

maven_settings="$HOME/.m2/settings.xml"
maven_settings_spec="$curr_dir/alti-maven-settings.spec"

git_hash=""

if [ -f "$curr_dir/setup_env.sh" ]; then
  set -a
  # source "$curr_dir/setup_env.sh"
  . "$curr_dir/setup_env.sh"
  set +a
fi

if [ "x${BUILD_TIMEOUT}" = "x" ] ; then
  build_timeout=14400
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
  echo hello
}

env | sort
pushd `pwd`
cd $WORKSPACE/sparkjs
if [ "x${SPARK_BRANCH_NAME}" = "x" ] ; then
  echo "error - SPARK_BRANCH_NAME is not defined. Please specify the BRANCH_NAME explicitly. Exiting!"
  exit -9
fi
  echo "ok - switching to latest branch $SPARK_BRANCH_NAME and refetch the files"
  git checkout $SPARK_BRANCH_NAME
  git fetch --all
  git pull
  git_hash=$(git rev-parse HEAD | tr -d '\n')
popd

echo "ok - tar zip source file, preparing for build/compile by rpmbuild"
mkdir -p $WORKSPACE/rpmbuild/{BUILD,BUILDROOT,RPMS,SPECS,SOURCES,SRPMS}/
cp -f "$sparkjs_spec" $WORKSPACE/rpmbuild/SPECS/sparkjs.spec
sparkjs_tar="sparkjs.tar"
pushd $WORKSPACE
tar --exclude .git --exclude .gitignore -cf $WORKSPACE/rpmbuild/SOURCES/${sparkjs_tar} sparkjobserver test_sparkjs
popd

pushd "$WORKSPACE/rpmbuild/SOURCES/"
tar -xf $sparkjs_tar
if [ -d alti-sparkjobserver ] ; then
  rm -rf alti-sparkjobserver
fi
mv sparkjobserver alti-sparkjobserver
cp -rp test_sparkjs alti-sparkjobserver/
tar --exclude .git --exclude .gitignore -cpzf alti-sparkjobserver.tar.gz alti-sparkjobserver
stat alti-sparkjobserver.tar.gz

if [ -f "$maven_settings" ] ; then
  mkdir -p  alti-maven-settings
  cp "$maven_settings" alti-maven-settings/
  tar -cvzf alti-maven-settings.tar.gz alti-maven-settings
  cp "$maven_settings_spec" $WORKSPACE/rpmbuild/SPECS/
fi
# 
# Explicitly define SPARK_HOME here for build purpose
export SPARK_HOME=$WORKSPACE/rpmbuild/BUILD/alti-sparkjobserver
echo "ok - applying version number $SPARK_JS_VERSION and release number $BUILD_TIME, the pattern delimiter is / here"
sed -i "s/SPARK_JS_VERSION_REPLACE/$SPARK_JS_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_JS_PLAINVERSION_REPLACE/$SPARK_JS_PLAIN_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s:CURRENT_WORKSPACE_REPLACE:$WORKSPACE:g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/HADOOP_VERSION_REPLACE/$HADOOP_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/HADOOP_BUILD_VERSION_REPLACE/$HADOOP_BUILD_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/HIVE_VERSION_REPLACE/$HIVE_VERSION/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_USER/$SPARK_USER/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_GID/$SPARK_GID/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/SPARK_UID/$SPARK_UID/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/BUILD_TIME/$BUILD_TIME/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/ALTISCALE_RELEASE/$ALTISCALE_RELEASE/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"
sed -i "s/GITHASH_REV_RELEASE/$git_hash/g" "$WORKSPACE/rpmbuild/SPECS/sparkjs.spec"

rpmbuild -vvv -ba --define "_topdir $WORKSPACE/rpmbuild" --buildroot $WORKSPACE/rpmbuild/BUILDROOT/ $WORKSPACE/rpmbuild/SPECS/sparkjs.spec
if [ $? -ne "0" ] ; then
  echo "fail - rpmbuild -ba RPM build failed"
  exit -96
fi

rpmbuild -vvv -bi --short-circuit --define "_topdir $WORKSPACE/rpmbuild" --buildroot $WORKSPACE/rpmbuild/BUILDROOT/ $WORKSPACE/rpmbuild/SPECS/sparkjs.spec
if [ $? -ne "0" ] ; then
  echo "fail - rpmbuild -bi --short-circuit RPM build failed"
  exit -97
fi

exit 0












