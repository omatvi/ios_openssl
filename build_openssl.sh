#!/bin/bash
# Oleksandr Matviishyn - 2018
# The purpose of this script is to build Openssl: libssl and libcrypto for iOS (device and simulator)
# Openssl download link http://www.openssl.org/source/

# Define current or desired version of library to be downloaded
OPENSSL_VERSION="openssl-1.0.2p"

# To get the CHECKSUM visit Openssl download link and download the file with .sha256 extension open it with your fames texteditor and copy/paste it here
VERSION_SHA256_CHECKSUM="50a98e07b1a89eb8f6a99477f262df71c6fa7bef77df4dc83025a2845c827d00"

# iOS SDK version 
IOS_SDK_VERSION=$(xcodebuild -version -sdk iphoneos | grep SDKVersion | cut -f2 -d ':' | tr -d '[[:space:]]')

# Define your minimum iOS version here
MIN_IOS_VERSION="7.0"

# Define your minimum OSx version here
MIN_OSX_VERSION="10.7"

# Print collected information from the system
echo "***************************************************"
echo "*     OpenSSL version: ${OPENSSL_VERSION}"
echo "*     iOS SDK version: ${IOS_SDK_VERSION}"
echo "*     iOS deployment target: ${MIN_IOS_VERSION}"
echo "*     OS X deployment target: ${MIN_OSX_VERSION}"
echo "***************************************************"
echo " "

DEVELOPER=`xcode-select -print-path`

# Check provided checksum from the official web site and downloaded tar file
checksum() {
    # Run a checksum to ensure this file wasn't tampered with
    echo "Checking Openssl tar file with provided checksum."
    FILE_CHECKSUM=$(shasum -a 256 $OPENSSL_VERSION.tar.gz | awk '{print $1; exit}')
    if [ "$FILE_CHECKSUM" != "$VERSION_SHA256_CHECKSUM" ]; then
        echo "OpenSSL $OPENSSL_VERSION failed checksum. Please ensure that you are on a trusted network."
        exit 1
    fi
    echo "OpenSSL $OPENSSL_VERSION checksum is correct."
}

buildMac() {
	ARCH=$1
	echo "Start Building ${OPENSSL_VERSION} for ${ARCH}"
	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
	fi
	
	export CC="${BUILD_TOOLS}/usr/bin/clang -mmacosx-version-min=${MIN_OSX_VERSION}"
	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	echo "Configure Openssl for the OSx"
	./Configure ${TARGET} --openssldir="/tmp/${OPENSSL_VERSION}-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-${ARCH}.log"
	make >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	echo "make install"
	make install >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	echo "make clean"
	make clean >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
	
	echo "Done Building ${OPENSSL_VERSION} for ${ARCH}"
}

buildIOS() {
	ARCH=$1
	echo "Start Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	
	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -mios-version-min=${MIN_IOS_VERSION} -arch ${ARCH}"
	
	echo "Configure Openssl for the iOS"
	if [[ "${ARCH}" == "x86_64" ]]; then
		./Configure darwin64-x86_64-cc --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
	else
		./Configure iphoneos-cross --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
	fi
	# add -isysroot to CC=
	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mios-version-min=${MIN_IOS_VERSION} !" "Makefile"
	echo "make"
	make >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "make install"
	make install >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "make clean"
	make clean  >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
	
	echo "Done Building ${OPENSSL_VERSION} for ${ARCH}"
}
echo "Cleaning up"
rm -rf include/openssl/* lib/*
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}
mkdir -p lib/iOS
mkdir -p lib/Mac
mkdir -p include/openssl/
rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"
rm -rf "${OPENSSL_VERSION}"
if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi
checksum
echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"
buildMac "x86_64"
echo "Copying headers"
cp /tmp/${OPENSSL_VERSION}-x86_64/include/openssl/* include/openssl/
echo "Building OSx libraries"
lipo \
	"/tmp/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
	-create -output lib/Mac/libcrypto.a
lipo \
	"/tmp/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
	-create -output lib/Mac/libssl.a
buildIOS "armv7"
buildIOS "arm64"
buildIOS "x86_64"
echo "Building iOS libraries"
lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
	-create -output lib/iOS/libcrypto.a
lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
	-create -output lib/iOS/libssl.a
echo "Cleaning up"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}
echo "Done"