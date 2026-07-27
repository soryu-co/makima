# Homebrew formula for the makima CLI.
#
# Installs the prebuilt release archive rather than building from source: the
# workspace is ~650 crates, and a from-source formula would put a multi-minute
# compile in front of every `brew install`.
#
#   brew tap soryu-co/makima https://github.com/soryu-co/makima
#   brew install makima
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
  version "0.6.8"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/soryu-co/makima/releases/download/v0.6.8/makima-v0.6.8-macos-arm64.tar.gz"
      sha256 "f99b8f04f4f516cc4936c74b81e115e83a6c4935e122a219ced684578d7e290d"
    end
    on_intel do
      url "https://github.com/soryu-co/makima/releases/download/v0.6.8/makima-v0.6.8-macos-x86_64.tar.gz"
      sha256 "7554053e75849b19392d3c492f9dd6d1f07f1625611b282c631913c41089e7aa"
    end
  end

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
