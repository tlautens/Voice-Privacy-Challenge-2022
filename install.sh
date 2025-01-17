#!/bin/bash

set -e

nj=$(nproc)

home=$PWD

#conda_url=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
conda_url=https://repo.anaconda.com/miniconda/Miniconda3-py38_4.10.3-Linux-x86_64.sh
venv_dir=$PWD/venv

netcdf=https://github.com/Unidata/netcdf-c/archive/v4.3.3.1.tar.gz
netcdf_dir=$PWD/netcdf-c-4.3.3.1

boost=https://netix.dl.sourceforge.net/project/boost/boost/1.59.0/boost_1_59_0.tar.gz
boost_dir=$PWD/boost_1_59_0

flac=https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.3.3.tar.xz
flac_dir=$PWD/flac-1.3.3

nii_cmake=$PWD/nii_cmake/CMakeLists.txt
nii_dir=$PWD/nii
currennt_dir=$nii_dir/CURRENNT_codes

sv56=https://github.com/openitu/STL/archive/refs/tags/v2009.tar.gz
sv56_dir=$PWD/STL-2009

nii_pytorchdir=$PWD/nii_pytorch


mark=.done-venv
if [ ! -f $mark ]; then
  echo 'Making python virtual environment'
  name=$(basename $conda_url)
  if [ ! -f $name ]; then
    wget $conda_url || exit 1
  fi
  [ ! -f $name ] && echo "File $name does not exist" && exit 1
  [ -d $venv_dir ] && rm -r $venv_dir
  sh $name -b -p $venv_dir || exit 1
  . $venv_dir/bin/activate
  echo 'Installing python dependencies'
  pip install -r requirements.txt || exit 1
  touch $mark
fi
echo "if [ \$(which python) != $venv_dir/bin/python ]; then source $venv_dir/bin/activate; fi" > env.sh

mark=.done-kaldi-tools
if [ ! -f $mark ]; then
  echo 'Building Kaldi tools'
  cd kaldi/tools
  extras/check_dependencies.sh || exit 1
  make -j $nj || exit 1
  cd $home
  touch $mark
fi

mark=.done-kaldi-src
if [ ! -f $mark ]; then
  echo 'Building Kaldi src'
  cd kaldi/src
  ./configure --shared || exit 1
  make clean || exit 1
  make depend -j $nj || exit 1
  make -j $nj || exit 1
  cd $home
  touch $mark
fi

mark=.done-netcdf
if [ ! -f $mark ]; then
  if [ ! -f $(basename $netcdf) ]; then
    wget $netcdf || exit 1
  fi
  echo 'Unpacking NetCDF source files'
  dir=$netcdf_dir
  [ -d $dir ] && rm -r $dir
  tar -xf $(basename $netcdf) || exit 1
  echo 'Building NetCDF'
  build=$dir/build
  cd $dir
  ./configure --disable-netcdf-4 --prefix=$build || exit 1
  make -j $nj || exit 1
  make install || exit 1
  cd $home
  touch $mark
fi
netcdf_bin=$netcdf_dir/build/bin
netcdf_lib=$netcdf_dir/build/lib
echo "export PATH=$netcdf_bin:\$PATH" >> env.sh
echo "export LD_LIBRARY_PATH=$netcdf_bin:\$LD_LIBRARY_PATH" >> env.sh

mark=.done-boost
if [ ! -f $mark ]; then
  if [ ! -f $(basename $boost) ]; then
    wget $boost || exit 1
  fi
  echo 'Unpacking boost source files'
  dir=$boost_dir
  [ -d $dir ] && rm -r $dir
  tar -xf $(basename $boost) || exit 1
  echo 'Building boost libraries'
  build=$dir/build
  cd $dir
  ./bootstrap.sh --with-libraries=program_options,filesystem,system,random,thread || exit 1
  ./b2 -j $nj --prefix=$build || exit 1
  cd $home
  touch $mark
fi
boost_root=$boost_dir
echo "export LD_LIBRARY_PATH=$boost_root/stage/lib:\$LD_LIBRARY_PATH" >> env.sh

mark=.done-flac
if [ ! -f $mark ]; then
  if [ -z "$(which flac)" ]; then
    if [ ! -f $(basename $flac) ]; then
      wget $flac || exit 1
    fi
    echo 'Unpacking flac source files'
    [ -d $flac_dir ] && rm -r $flac_dir
    tar -xf $(basename $flac) || exit 1
    echo 'Building flac'
    cd $flac_dir
    ./configure --prefix=$PWD/install || exit 1
    make -j $nj || exit 1
    # make -j $nj check || exit 1
    make install || exit 1
  fi
  cd $home
  touch $mark
fi
[ -f $flac_dir/install/bin/flac ] && \
  echo "export PATH=$flac_dir/install/bin:\$PATH" >> env.sh


mark=.done-sv56
if [ ! -f $mark ]; then
  if [ -z "$(which sv56demo)" ]; then
    if [ ! -f $(basename $sv56) ]; then
      wget -q $sv56 || exit 1
    fi
    echo 'Unpacking sv56 source files'
    [ -d $sv56_dir ] && rm -r $sv56_dir
    tar -xf $(basename $sv56) || exit 1
    echo 'Building sv56'
    cd $sv56_dir/src/sv56
    make -f makefile.unx || exit 1
    if [ ! -e $sv56_dir/src/sv56/sv56demo ]; then
	echo 'fail to compile sv56'
	exit 1
    fi
  fi
  cd $home
  touch $mark
fi
[ -f $sv56_dir/src/sv56/sv56demo ] && \
  echo "export PATH=$sv56_dir/src/sv56:\$PATH" >> env.sh

mark=.done-nii
if [ ! -f $mark ]; then
  echo 'Building nii'
  cp $nii_cmake $currennt_dir || exit 1
  dir=$currennt_dir/build
  [ -d $dir ] && rm -r $dir
  mkdir -p $dir || exit 1
  cd $dir
  cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBOOST_ROOT=$boost_root \
    -DNETCDF_LIB=$netcdf_lib || exit 1
  make -j $nj || exit 1
  cd $home
  touch $mark
fi


echo "export PATH=$currennt_dir/build:\$PATH" >> env.sh
echo "export PYTHONPATH=$nii_pytorchdir:$currennt_dir:$nii_dir/pyTools:$PWD/nii_scripts:\$PYTHONPATH" >> env.sh
echo "export nii_scripts=$PWD/nii_scripts" >> env.sh
echo "export nii_dir=$nii_dir" >> env.sh
echo "export nii_pt_scripts=$PWD/nii_pytorch" >> env.sh
echo Done
