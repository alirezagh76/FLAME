# FLAME: a library for atomistic modeling environments

[FLAME](flame-code.org) is a highly modular open source software package to perform atomistic simulations using a wide variety of techniques.

## Installation

FLAME requires `autoconf` and `automake` to be installed.

It is recommended to install FLAME in a directory different from
the source.

### Steps to install FLAME

1. You first need to install `futile` which is
a set of utilities from the [BigDFT](http://bigdft.org) project.

Preferably, use the tar file given inside the
FLAME to avoid inconsistency of versions.

You do NOT need different installation of futile
for multiple installations of FLAME.

`Untar` the futile inside the FLAME, then
in order to build futile, make a directory somewhere
and from there run the following:

`path_to_futile_source/Installer.py build futile -c "FCFLAGS=-O2" 
"--with-ext-linalg=-L/opt/intel/composer_xe_2013.2.146/mkl/lib/intel64 
-lmkl_rt -lmkl_scalapack_lp64 -lmkl_blacs_openmpi_lp64 -liomp5 -lm" 
"CC=mpicc" "CXX=mpicxx" "FC=mpif90" "F77=mpif90" "FCLIBS= "`

Of course, the setting is given for a particular version and
installation of `MKL`, you may need to modify it.

After installation, you may need to find out how to link with
the build futile, however, in the subsequent steps you see an
example. In case, you want to know how to link you can run:

`path_to_futile_source/Installer.py link futile`

2. in FLAME source directory run:

`autoreconf -fi`

3. make a directory to build flame and then
replace `$FUTILE` by the full path of futile built
directory or define it as an environment variable:

`export FUTILE=path_to_built_futile_directory`

IMPORTANT: exporting FUTILE variable is required, not optional.

then,

`path_to_flame_source/configure FC=mpif90 F77=mpif90 CXX=mpicc CC=mpicc 
FCFLAGS="-I$FUTILE/install/include -shared-intel -mcmodel=large  -mkl=sequential" 
CFLAGS=-mcmodel=large "LIBS=-L$FUTILE/install/lib 
-L/opt/intel/composer_xe_2013.2.146/mkl/lib/intel64 -lfutile-1 -lmkl_rt 
-lmkl_scalapack_lp64 -lmkl_blacs_openmpi_lp64 -liomp5 -lm -lyaml -ldl -lrt -cxxlib"`

if you want to link with SPGLIB then add
`--with-spglib SPGLIB_ROOT=path_to_spglib`

if you want to link with BigDFT PSolver then add
`--with-bps BDIR=path_to_bigdft_root`

if you want to link with LAMMPS then add
`--with-lammps LAMMPS_ROOT=path_to_lammps_root`

4. `make`

You should be ready to use FLAME, the executable is at
`src/flame`
