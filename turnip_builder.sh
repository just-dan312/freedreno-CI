#!/bin/bash -e
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="meson ninja patchelf unzip curl pip flex bison zip"
workdir="$(pwd)/turnip_workdir"
driverdir="$workdir/turnip_module"
ndkver="android-ndk-r26d"
sdkver="29"
mesasrc="https://github.com/SolDev69/unified-mesa-project/archive/refs/heads/feat/mesa-update/24.1.zip"
clear



echo "Checking system for required Dependencies ..."
for deps_chk in $deps;
	do 
		sleep 0.25
		if command -v $deps_chk >/dev/null 2>&1 ; then
			echo -e "$green - $deps_chk found $nocolor"
		else
			echo -e "$red - $deps_chk not found, can't countinue. $nocolor"
			deps_missing=1
		fi;
	done
	
	if [ "$deps_missing" == "1" ]
		then echo "Please install missing dependencies" && exit 1
	fi



echo "Installing python Mako dependency (if missing) ..." $'\n'
pip install mako &> /dev/null



echo "Creating and entering to work directory ..." $'\n'
mkdir -p $workdir && cd $workdir



echo "Downloading android-ndk from google server (~506 MB) ..." $'\n'
curl https://dl.google.com/android/repository/"$ndkver"-linux.zip --output "$ndkver"-linux.zip &> /dev/null
###
echo "Exracting android-ndk to a folder ..." $'\n'
unzip "$ndkver"-linux.zip  &> /dev/null



echo "Downloading mesa source (~50 MB) ..." $'\n'
wget -O ump-24.1.zip "$mesasrc" &> /dev/null
###
echo "Exracting mesa source to a folder ..." $'\n'
unzip ump-24.1.zip &> /dev/null
cd unified-mesa-project-feat-mesa-update-24.1



echo "Creating meson cross file ..." $'\n'
ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"
cat <<EOF >"android-aarch64"
[binaries]
ar = '$ndk/llvm-ar'
c = ['ccache', '$ndk/aarch64-linux-android$sdkver-clang']
cpp = ['ccache', '$ndk/aarch64-linux-android$sdkver-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$ndk/aarch64-linux-android-strip'
pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkgconfig', '/usr/bin/pkg-config']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF



echo "Generating build files ..." $'\n'
meson build-android-aarch64 --cross-file $workdir/unified-mesa-project-feat-mesa-update-24.1/android-aarch64 -Dbuildtype=release -Dplatforms=android -Dplatform-sdk-version=$sdkver -Dandroid-stub=true -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl -Db_lto=true &> $workdir/meson_log



echo "Compiling build files ..." $'\n'
ninja -C build-android-aarch64 &> $workdir/ninja_log



echo "Using patchelf to match soname ..."  $'\n'
cp $workdir/unified-mesa-project-feat-mesa-update-24.1/build-android-aarch64/src/freedreno/vulkan/libvulkan_freedreno.so $workdir
cp $workdir/unified-mesa-project-feat-mesa-update-24.1/build-android-aarch64/src/android_stub/libhardware.so $workdir
cp $workdir/unified-mesa-project-feat-mesa-update-24.1/build-android-aarch64/src/android_stub/libsync.so $workdir
cp $workdir/unified-mesa-project-feat-mesa-update-24.1/build-android-aarch64/src/android_stub/libbacktrace.so $workdir
cd $workdir
patchelf --set-soname vulkan.adreno.so libvulkan_freedreno.so
mv libvulkan_freedreno.so vulkan.adreno.so



if ! [ -a vulkan.adreno.so ]; then
	echo -e "$red Build failed! $nocolor" && exit 1
fi



echo "Prepare magisk module structure ..." $'\n'
mkdir -p $driverdir
cd $driverdir


cat <<EOF >"meta.json"
{
  "schemaVersion": 1,
  "name": "Mesa Turnip Adreno Driver 24.1.2",
  "description": "Open-source Vulkan driver build from Unified Mesa Project drivers repo",
  "author": "PurpleVoyager401",
  "packageVersion": "A10-compatibility",
  "vendor": "Mesa",
  "driverVersion": "24.1.2",
  "minApi": 29,
  "libraryName": "vulkan.adreno.so"
}
EOF


echo "Copy necessary files from work directory ..." $'\n'
cp $workdir/vulkan.adreno.so $driverdir
cp $workdir/libhardware.so $driverdir
cp $workdir/libsync.so $driverdir
cp $workdir/libbacktrace.so $driverdir



echo "Packing files in to magisk module ..." $'\n'
zip -r $workdir/turnip-24.1.2-A10-compat.adpkg.zip * &> /dev/null
if ! [ -a $workdir/turnip-24.1.2-A10-compat.adpkg.zip ];
	then echo -e "$red-Packing failed!$nocolor" && exit 1
	else echo -e "$green-All done, you can take your module from here;$nocolor" && echo $workdir/turnip-24.1.2-A10-compat.adpkg.zip
fi
