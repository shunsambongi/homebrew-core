class Openblas < Formula
  desc "Optimized BLAS library"
  homepage "https://www.openblas.net/"
  url "https://github.com/xianyi/OpenBLAS/archive/v0.3.10.tar.gz"
  sha256 "0484d275f87e9b8641ff2eecaa9df2830cbe276ac79ad80494822721de6e1693"
  license "BSD-3-Clause"
  revision 2
  head "https://github.com/xianyi/OpenBLAS.git", branch: "develop"

  bottle do
    cellar :any
    sha256 "dcffce6b09f1710f3b620122c67a31aea99073ef036a9abf2e8261a999c5cbb5" => :catalina
    sha256 "cf345fcf861d1a699832126476a7385b9cc212dc5b1b985749e219481473e836" => :mojave
    sha256 "09e6222e227fccb3d1a86aa0b0ac77fec3e512ba9266ecf72f235c58c6795009" => :high_sierra
  end

  keg_only :shadowed_by_macos, "macOS provides BLAS in Accelerate.framework"

  depends_on "gcc" # for gfortran
  fails_with :clang

  # This patch fixes a known issue with large matrices in numpy on Haswell and later
  # chipsets.  See https://github.com/xianyi/OpenBLAS/pull/2729 for details
  patch do
    url "https://github.com/xianyi/OpenBLAS/commit/6c33764ca43c7311bdd61e2371b08395cf3e3f01.diff?full_index=1"
    sha256 "a1b0c27384e424d8cabb5a4e3aeb47b9d0a1fbbc36507431b13719120b6d26d3"
  end

  def install
    ENV["DYNAMIC_ARCH"] = "1"
    ENV["USE_OPENMP"] = "1"
    ENV["NO_AVX512"] = "1"
    ENV["TARGET"] = case Hardware.oldest_cpu
    when :arm_vortex_tempest
      "VORTEX"
    else
      Hardware.oldest_cpu.upcase.to_s
    end

    # Must call in two steps
    system "make", "CC=#{ENV.cc}", "FC=gfortran", "libs", "netlib", "shared"
    system "make", "PREFIX=#{prefix}", "install"

    lib.install_symlink shared_library("libopenblas") => shared_library("libblas")
    lib.install_symlink shared_library("libopenblas") => shared_library("liblapack")
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include <stdlib.h>
      #include <math.h>
      #include "cblas.h"

      int main(void) {
        int i;
        double A[6] = {1.0, 2.0, 1.0, -3.0, 4.0, -1.0};
        double B[6] = {1.0, 2.0, 1.0, -3.0, 4.0, -1.0};
        double C[9] = {.5, .5, .5, .5, .5, .5, .5, .5, .5};
        cblas_dgemm(CblasColMajor, CblasNoTrans, CblasTrans,
                    3, 3, 2, 1, A, 3, B, 3, 2, C, 3);
        for (i = 0; i < 9; i++)
          printf("%lf ", C[i]);
        printf("\\n");
        if (fabs(C[0]-11) > 1.e-5) abort();
        if (fabs(C[4]-21) > 1.e-5) abort();
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lopenblas",
                   "-o", "test"
    system "./test"
  end
end
