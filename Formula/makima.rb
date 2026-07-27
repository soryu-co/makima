# Homebrew formula for the makima CLI.
#
# Installs the prebuilt release archive rather than building from source: the
# workspace is ~650 crates, and a from-source formula would put a multi-minute
# compile in front of every `brew install`.
#
#   brew tap soryu-co/makima https://github.com/soryu-co/makima
#   brew trust soryu-co/makima      # newer Homebrew requires this for 3rd-party taps
#   brew install makima
#
# The `brew trust` step is not optional on current Homebrew: without it the
# install fails with "Refusing to load formula ... from untrusted tap", which
# reads like a broken formula rather than a policy prompt.
#
# The tap IS the public repo, so this file must be mirrored to it — see the
# `Formula/**` path filter in .github/workflows/sync-public-repo.yml. Without
# that, `brew tap` resolves to a repo with no formulae and fails opaquely.
#
# Bumping: run `sh/update-formula.sh <tag>`. It reads the real assets and
# computes their checksums; Homebrew verifies every download against them, so a
# hand-edited sha256 is a formula that refuses to install.
class Makima < Formula
  desc "Self-hosted daemon orchestration and terminal coding harness"
  homepage "https://github.com/soryu-co/makima"
  version "0.6.9"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/soryu-co/makima/releases/download/v0.6.9/makima-v0.6.9-macos-arm64.tar.gz"
      sha256 "6149143d7154824576066e557d2e286748d9d814c2f5692fa40c8029f5ceb361"
    end
    on_intel do
      url "https://github.com/soryu-co/makima/releases/download/v0.6.9/makima-v0.6.9-macos-x86_64.tar.gz"
      sha256 "517d8c433400de7bfc6586d95ebcaf52afc39fa49bbae73d3b0a059b80b0a5d3"
    end
  end

  # Linux stays on 0.6.8 deliberately: v0.6.9 was built by hand because
  # GitHub Actions is disabled on the account, and the Linux cross-build could
  # not be completed on an arm64 machine. Pointing this at a v0.6.9 asset that
  # does not exist would 404 on every Linux install; serving the last good
  # build is strictly better. Revert to a single version once CI can run.
  on_linux do
    on_intel do
      url "https://github.com/soryu-co/makima/releases/download/v0.6.8/makima-v0.6.8-linux-x86_64.tar.gz"
      sha256 "13adeeb3e74b77d9829a1f23366f3901e1ac8226ce9f993a05074f4d0f8c3507"
    end
  end

  def install
    # Each archive contains a single `makima` binary at its root.
    bin.install "makima"
  end

  test do
    # The usual failure for a downloaded-binary formula is an architecture
    # mismatch, which shows up immediately as a failure to exec.
    assert_match "makima", shell_output("#{bin}/makima --help 2>&1", 0)
  end
end
