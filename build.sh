#!/bin/bash
# shellcheck disable=SC2154
#Kernel building script

# Function to show an informational message
msg() {
	echo
    echo -e "\e[1;32m$*\e[0m"
    echo
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

cdir() {
	cd "$1" 2>/dev/null || \
		err "The directory $1 doesn't exists !"
}

installDependencies(){	
sudo apt -y update 
sudo apt -y install git automake lzop bison gperf build-essential zip \
 curl zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev libbz2-1.0 \
 libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make \
 optipng bc libstdc++6 libncurses5 wget python3 python3-pip python gcc clang  \
 libssl-dev rsync flex git-lfs libz3-dev libz3-4 axel tar gcc llvm lld g++-multilib clang default-jre libxml2

}

installDependencies

## clone Kernel
echo "Cloning Kernel"
git clone https://github.com/PixelExperience-Devices/kernel_motorola_exynos9610 -b twelve kernel

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$(pwd)/kernel
cd $KERNEL_DIR

# The name of the device for which the kernel is built
MODEL="Motorola Moto p50"

# The codename of the device
DEVICE="kane_retcn"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=kane_defconfig

# Show manufacturer info
MANUFACTURERINFO="ASUSTek Computer Inc."

# Kernel Variant
VARIANT=perf

# Build Type
BUILD_TYPE="Release"

# Specify compiler.
# 'clang' or 'clangxgcc' or 'gcc'
COMPILER=clang

# Kernel is LTO
LTO=0

# Specify linker.
# 'ld.lld'(default)
LINKER=ld.lld

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=0

TOKEN=$TELEGRAM_TOKEN

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

#Check Kernel Version
LINUXVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date
DATE=$(TZ=Asia/Kolkata date +"%Y-%m-%d")

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
	if [ $COMPILER = "clang" ]
	then
		msg "|| Cloning toolchain ||"
		git clone --depth=1 https://github.com/kdrag0n/proton-clang -b master $KERNEL_DIR/clang

	elif [ $COMPILER = "gcc" ]
	then
		msg "|| Cloning GCC 12.0.0 Bare Metal ||"
		git clone https://github.com/mvaisakh/gcc-arm64.git $KERNEL_DIR/gcc64 --depth=1
        git clone https://github.com/mvaisakh/gcc-arm.git $KERNEL_DIR/gcc32 --depth=1

	elif [ $COMPILER = "clangxgcc" ]
	then
		msg "|| Cloning toolchain ||"
		git clone --depth=1 https://github.com/kdrag0n/proton-clang -b master $KERNEL_DIR/clang

		msg "|| Cloning GCC 12.0.0 Bare Metal ||"
		git clone https://github.com/mvaisakh/gcc-arm64.git $KERNEL_DIR/gcc64 --depth=1
		git clone https://github.com/mvaisakh/gcc-arm.git $KERNEL_DIR/gcc32 --depth=1
	fi

	# Toolchain Directory defaults to clang-llvm
		TC_DIR=$KERNEL_DIR/clang

	# GCC Directory
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32

	# AnyKernel Directory
		AK_DIR=$KERNEL_DIR/Anykernel3

	    msg "|| Cloning Anykernel ||"
        git clone https://github.com/divyam234/AnyKernel3.git -b main $KERNEL_DIR/Anykernel3

	if [ $BUILD_DTBO = 1 ]
	then
		msg "|| Cloning libufdt ||"
		git clone https://android.googlesource.com/platform/system/libufdt $KERNEL_DIR/scripts/ufdt/libufdt
	fi
}


}

##---------------------------------------------------------##

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

##----------------------------------------------------------##

tg_send_sticker() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendSticker" \
        -d sticker="$1" \
        -d chat_id="$CHATID"
}

##----------------------------------------------------------------##

tg_send_files(){
    KernelFiles="$(pwd)/$KERNELNAME.zip"
	MD5CHECK=$(md5sum "$KernelFiles" | cut -d' ' -f1)
	SID="CAACAgUAAxkBAAIlv2DEzB-BSFWNyXkkz1NNNOp_pm2nAAIaAgACXGo4VcNVF3RY1YS8HwQ"
	STICK="CAACAgUAAxkBAAIlwGDEzB_igWdjj3WLj1IPro2ONbYUAAIrAgACHcUZVo23oC09VtdaHwQ"
    MSG="✅ <b>Build Done</b>
- <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s) </code>
<b>Build Type</b>
-<code>$BUILD_TYPE</code>
<b>MD5 Checksum</b>
- <code>$MD5CHECK</code>
<b>Zip Name</b>
- <code>$KERNELNAME.zip</code>"

        curl --progress-bar -F document=@"$KernelFiles" "https://api.telegram.org/bot$TOKEN/sendDocument" \
        -F chat_id="$CHATID"  \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$MSG"

}

##----------------------------------------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		make clean && make mrproper && rm -rf out
	fi

	if [ "$PTTG" = 1 ]
 	then
            tg_post_msg "<b>🔨 Redux Kernel Build Triggered</b>
<b>Host Core Count : </b><code>$PROCS</code>
<b>Device: </b><code>$MODEL</code>
<b>Codename: </b><code>$DEVICE</code>
<b>Build Date: </b><code>$DATE</code>
<b>Kernel Name: </b><code>Redux-$VARIANT-$DEVICE</code>
<b>Linux Tag Version: </b><code>$LINUXVER</code>"

	cd $AK_DIR
	zip -r9 "$KERNELNAME.zip" * -x .git README.md anykernel-real.sh .gitignore zipsigner* *.zip

	if [ $SIGN = 1 ]
	then
		## Sign the zip before sending it to telegram
		if [ "$PTTG" = 1 ]
 		then
 			msg "|| Signing Zip ||"
			tg_post_msg "<code>Signing Zip file with AOSP keys..</code>"
 		fi
		cd $AK_DIR
		java -jar zipsigner-3.0.jar $KERNELNAME.zip $KERNELNAME-signed.zip
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_send_files "$1"
	fi
}

setversioning
clone
exports
build_kernel
