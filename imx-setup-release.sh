#!/bin/bash
#
# i.MX Yocto Project Build Environment Setup Script
#
# Copyright (C) 2011-2016 Freescale Semiconductor
# Copyright 2017 NXP
#
# 2018-2020 Markus Niebel <Markus.Niebel@tq-group.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

. sources/meta-imx/tools/setup-utils.sh

CWD=$(pwd)
PROGNAME="setup-environment"
# get first tqma8 machine from meta-tq
DEFAULT_MACHINE=$(./ls-machines | grep tqma8 | head -1 | awk '{$1=$1;print}')
SUPPORTED_DISTROS=$(ls sources/meta-imx/meta-sdk/conf/distro/*.conf \
	| sed s/\.conf//g | xargs -n1 basename )
DEFAULT_DISTRO="fsl-imx-wayland"

exit_message ()
{
   echo "To return to this build environment later please run:"
   echo "    source setup-environment <build_dir>"

}

usage()
{
    echo -e "\nUsage: source imx-setup-release.sh
    Optional parameters: [-b build-dir] [-h]"
echo "
    * [-b build-dir]: Build directory, if unspecified script uses 'build' as output directory
    * [-h]: help
"
}


clean_up()
{
    unset CWD BUILD_DIR FSLDISTRO
    unset fsl_setup_help fsl_setup_error fsl_setup_flag
    unset usage clean_up
    unset ARM_DIR META_FSL_BSP_RELEASE
    exit_message clean_up
}

# get command line options
OLD_OPTIND=$OPTIND
unset FSLDISTRO

while getopts "k:r:t:b:e:gh" fsl_setup_flag
do
    case $fsl_setup_flag in
        b) BUILD_DIR="$OPTARG";
           echo -e "\n Build directory is " $BUILD_DIR
           ;;
        h) fsl_setup_help='true';
           ;;
        \?) fsl_setup_error='true';
           ;;
    esac
done
shift $((OPTIND-1))
if [ $# -ne 0 ]; then
    fsl_setup_error=true
    echo -e "Invalid command line ending: '$@'"
fi
OPTIND=$OLD_OPTIND
if test $fsl_setup_help; then
    usage && clean_up && return 1
elif test $fsl_setup_error; then
    clean_up && return 1
fi


if [ -z "$DISTRO" ]; then
    if [ -z "$FSLDISTRO" ]; then
        FSLDISTRO=${DEFAULT_DISTRO}
    fi
else
    FSLDISTRO="$DISTRO"
fi

if [ -z "$BUILD_DIR" ]; then
    BUILD_DIR='build'
fi

if [ -z "$MACHINE" ]; then
    echo setting to default machine
    MACHINE=${DEFAULT_MACHINE}
fi

case $MACHINE in
imx8*)
    case $FSLDISTRO in
    *wayland)
        : ok
        ;;
    *)
        echo -e "\n ERROR - Only Wayland distros are supported for i.MX 8 or i.MX 8M"
        echo -e "\n"
        return 1
        ;;
    esac
    ;;
*)
    : ok
    ;;
esac

# Cleanup previous meta-freescale/EULA overrides
cd $CWD/sources/meta-freescale
if [ -h EULA ]; then
    echo Cleanup meta-freescale/EULA...
    git checkout -- EULA
fi
if [ ! -f classes/fsl-eula-unpack.bbclass ]; then
    echo Cleanup meta-freescale/classes/fsl-eula-unpack.bbclass...
    git checkout -- classes/fsl-eula-unpack.bbclass
fi
cd -

# Override the click-through in meta-freescale/EULA
FSL_EULA_FILE=$CWD/sources/meta-imx/EULA.txt

# Set up the basic yocto environment
if [ -z "$DISTRO" ]; then
   DISTRO=$FSLDISTRO MACHINE=$MACHINE . ./$PROGNAME $BUILD_DIR imx
else
   MACHINE=$MACHINE . ./$PROGNAME $BUILD_DIR imx
fi

# Point to the current directory since the last command changed the directory to $BUILD_DIR
BUILD_DIR=$(pwd)

if [ ! -e $BUILD_DIR/conf/local.conf ]; then
    echo -e "\n ERROR - No build directory is set yet. Run the 'setup-environment' script before running this script to create " $BUILD_DIR
    echo -e "\n"
    return 1
fi

# On the first script run, backup the local.conf file
# Consecutive runs, it restores the backup and changes are appended on this one.
if [ ! -e $BUILD_DIR/conf/local.conf.org ]; then
    cp $BUILD_DIR/conf/local.conf $BUILD_DIR/conf/local.conf.org
else
    cp $BUILD_DIR/conf/local.conf.org $BUILD_DIR/conf/local.conf
fi


if [ ! -e $BUILD_DIR/conf/bblayers.conf.org ]; then
    cp $BUILD_DIR/conf/bblayers.conf $BUILD_DIR/conf/bblayers.conf.org
else
    cp $BUILD_DIR/conf/bblayers.conf.org $BUILD_DIR/conf/bblayers.conf
fi


META_FSL_BSP_RELEASE="${CWD}/sources/meta-imx/meta-bsp"

echo "# start fsl-setup-release-magic" >> $BUILD_DIR/conf/bblayers.conf
echo "# i.MX Yocto Project Release layers" >> $BUILD_DIR/conf/bblayers.conf
hook_in_layer meta-imx/meta-bsp
hook_in_layer meta-imx/meta-sdk
hook_in_layer meta-imx/meta-ml

echo "" >> $BUILD_DIR/conf/bblayers.conf
echo "BBLAYERS += \"\${BSPDIR}/sources/meta-browser\"" >> $BUILD_DIR/conf/bblayers.conf
echo "BBLAYERS += \"\${BSPDIR}/sources/meta-rust\"" >> $BUILD_DIR/conf/bblayers.conf
echo "BBLAYERS += \"\${BSPDIR}/sources/meta-clang\"" >> $BUILD_DIR/conf/bblayers.conf
# we do not use meta-gnome in our builds - so remove it from bblayers.conf
# echo "BBLAYERS += \"\${BSPDIR}/sources/meta-openembedded/meta-gnome\"" >> $BUILD_DIR/conf/bblayers.conf
echo "BBLAYERS += \"\${BSPDIR}/sources/meta-openembedded/meta-networking\"" >> $BUILD_DIR/conf/bblayers.conf
echo "BBLAYERS += \"\${BSPDIR}/sources/meta-openembedded/meta-filesystems\"" >> $BUILD_DIR/conf/bblayers.conf

echo "BBLAYERS += \"\${BSPDIR}/sources/meta-qt5\"" >> $BUILD_DIR/conf/bblayers.conf
echo "BBLAYERS += \"\${BSPDIR}/sources/meta-python2\"" >> $BUILD_DIR/conf/bblayers.conf

echo "# end fsl-setup-release-magic" >> $BUILD_DIR/conf/bblayers.conf

echo "BSPDIR=${BSPDIR}"
echo "BUILD_DIR=${BUILD_DIR}"

# Support integrating community meta-freescale instead of meta-fsl-arm
# no changes needed, we use meta-freescale anyway ...
#if [ -d ../sources/meta-freescale ]; then
#    echo meta-freescale directory found
#    # Change settings according to environment
#    sed -e "s,meta-fsl-arm\s,meta-freescale ,g" -i conf/bblayers.conf
#    sed -e "s,\$.BSPDIR./sources/meta-fsl-arm-extra\s,,g" -i conf/bblayers.conf
#fi

# since we bring in the layers needed, just restore $BUILD_DIR/conf/bblayers.conf
sed -i '1,/# start fsl-setup-release-magic/!d' $BUILD_DIR/conf/bblayers.conf
sed -i '$ d' $BUILD_DIR/conf/bblayers.conf

cd ${BUILD_DIR}
clean_up
unset FSLDISTRO
