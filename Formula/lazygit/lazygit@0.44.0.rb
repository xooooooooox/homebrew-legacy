class LazygitAT0440 < Formula
  desc "Simple terminal UI for git commands"
  homepage "https://github.com/jesseduffield/lazygit/"
  url "https://github.com/jesseduffield/lazygit/archive/refs/tags/v0.44.0.tar.gz"
  sha256 "6cf617510127892f3ede2aea767ce725197902418ef7087c1cf0e91f06d00a16"
  license "MIT"
  head "https://github.com/jesseduffield/lazygit.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/xooooooooox/homebrew-legacy/releases/download/formula-lazygit@0.44.0"
    sha256 cellar: :any_skip_relocation, monterey: "39aa2782989ffd6c32b1d089a07cb967d1b5b57dbd8197dff48ee8b69cbfbff3"
  end

  depends_on "go" => :build

  def install
    ldflags = "-X main.version=#{version} -X main.buildSource=homebrew"
    system "go", "build", "-mod=vendor", *std_go_args(ldflags:)
  end

  test do
    system "git", "init", "--initial-branch=main"

    output = shell_output("#{bin}/lazygit log 2>&1", 1)
    assert_match "errors.errorString terminal not cursor addressable", output

    assert_match version.to_s, shell_output("#{bin}/lazygit -v")
  end
end
