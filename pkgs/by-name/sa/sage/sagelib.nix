{
  lib,
  stdenv,
  sage-src,
  env-locations,
  python,
  buildPythonPackage,
  m4,
  perl,
  pkg-config,
  sage-setup,
  setuptools,
  gd,
  iml,
  libpng,
  blas,
  boost,
  brial,
  cliquer,
  eclib,
  ecm,
  fflas-ffpack,
  flint,
  gap,
  givaro,
  glpk,
  gsl,
  lapack,
  lcalc,
  libbraiding,
  libhomfly,
  libmpc,
  linbox,
  lisp-compiler,
  lrcalc,
  m4ri,
  m4rie,
  mpfi,
  mpfr,
  ntl,
  pari,
  planarity,
  ppl,
  rankwidth,
  singular,
  sqlite,
  symmetrica,
  conway-polynomials,
  cvxopt,
  cypari2,
  cysignals,
  cython,
  fpylll,
  gmpy2,
  importlib-metadata,
  importlib-resources,
  ipykernel,
  ipython,
  ipywidgets,
  jupyter-client,
  jupyter-core,
  lrcalc-python,
  matplotlib,
  memory-allocator,
  meson-python,
  mpmath,
  networkx,
  numpy,
  pexpect,
  pillow,
  pip,
  pkgconfig,
  ninja,
  pplpy,
  primecountpy,
  ptyprocess,
  requests,
  rpy2,
  scipy,
  sphinx,
  sympy,
  typing-extensions,
}:

assert (!blas.isILP64) && (!lapack.isILP64);

# This is the core sage python package. Everything else is just wrappers gluing
# stuff together. It is not very useful on its own though, since it will not
# find many of its dependencies without `sage-env`, will not be tested without
# `sage-tests` and will not have html docs without `sagedoc`.

buildPythonPackage rec {
  version = src.version;
  pname = "sagelib";
  src = sage-src;
  pyproject = true;

  nativeBuildInputs = [
    iml
    lisp-compiler
    m4
    perl
    pip # needed to query installed packages
    pkg-config
    sage-setup
    setuptools
    meson-python
    cython
  ];

  mesonFlags = [ "-Dbuild-docs=false" ];

  buildInputs = [
    gd
    iml
    libpng
  ];

  #
  # Configuring config.py using configuration
  # ../src/sage/meson.build:129: WARNING: The variable(s) 'FOURTITWO_CIRCUITS', 'FOURTITWO_GRAVER', 'FOURTITWO_GROEBNER', 'FOURTITWO_HILBERT', 'FOURTITWO_MARKOV', 'FOURTITWO_PPI', 'FOURTITWO_QSOLVE', 'FOURTITWO_RAYS', 'FOURTITWO_ZSOLVE',
  #  'GAP_ROOT_PATHS', 'SAGE_ECMBIN', 'SAGE_MATHJAX_DIR', 'SAGE_MAXIMA', 'SAGE_MAXIMA_FAS', 'SAGE_MAXIMA_PREFIX', 'SAGE_NAUTY_BINS_PREFIX' in the input file 'src/sage/config.py.in' are not present in the given configuration data.
  # ../src/doc/meson.build:5: WARNING: Documentation building enabled, generating targets may be slow. To disable this, pass -Dbuild-docs=false.

  env = lib.optionalAttrs stdenv.cc.isClang {
    # code tries to assign a unsigned long to an int in an initialized list
    # leading to this error.
    # https://github.com/sagemath/sage/pull/39249
    NIX_CFLAGS_COMPILE = "-Wno-error=c++11-narrowing-const-reference";
  };

  propagatedBuildInputs = [
    # native dependencies (TODO: determine which ones need to be propagated)
    blas
    boost
    brial
    cliquer
    eclib
    ecm
    fflas-ffpack
    flint
    gap
    givaro
    glpk
    gsl
    lapack
    lcalc
    libbraiding
    libhomfly
    libmpc
    linbox
    lisp-compiler
    lrcalc
    m4ri
    m4rie
    mpfi
    mpfr
    ntl
    pari
    planarity
    ppl
    rankwidth
    singular
    sqlite
    symmetrica

    # from src/sage/setup.cfg and requirements.txt
    conway-polynomials
    cvxopt
    cypari2
    cysignals
    cython
    fpylll
    gmpy2
    importlib-metadata
    importlib-resources
    ipykernel
    ipython
    ipywidgets
    jupyter-client
    jupyter-core
    lrcalc-python
    matplotlib
    memory-allocator
    mpmath
    networkx
    numpy
    pexpect
    pillow
    pip
    pkgconfig
    pplpy
    primecountpy
    ptyprocess
    requests
    rpy2
    scipy
    sphinx
    sympy
    typing-extensions
  ];

  preBuild = ''
    export SAGE_ROOT="$PWD"
    export SAGE_LOCAL="$SAGE_ROOT"
    export SAGE_SHARE="$SAGE_LOCAL/share"

    # set locations of dependencies (needed for nbextensions like threejs)
    . ${env-locations}/sage-env-locations

    export JUPYTER_PATH="$SAGE_LOCAL/jupyter"
    export PATH="$SAGE_ROOT/build/bin:$SAGE_ROOT/src/bin:$PATH"

    export SAGE_NUM_THREADS="$NIX_BUILD_CORES"

    mkdir -p "$SAGE_SHARE/sage/ext/notebook-ipython"
    mkdir -p "var/lib/sage/installed"
    patchShebangs .
  '';

  doCheck = false; # we will run tests in sage-tests.nix
}
