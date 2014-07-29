require "spec_helper"

describe Gitlab::Git::Diff do
  let(:repository) { Gitlab::Git::Repository.new(TEST_REPO_PATH) }

  before do
    @raw_diff_hash = {
      diff: 'Hello world',
      new_path: 'temp.rb',
      old_path: 'test.rb',
      a_mode: '100644',
      b_mode: '100644',
      new_file: false,
      renamed_file: true,
      deleted_file: false,
    }

    @grit_diff = double('Grit::Diff', @raw_diff_hash)
  end

  describe :new do
    context 'init from grit' do
      before do
        @diff = Gitlab::Git::Diff.new(@raw_diff_hash)
      end

      it { @diff.to_hash.should == @raw_diff_hash }
    end

    context 'init from hash' do
      before do
        @diff = Gitlab::Git::Diff.new(@grit_diff)
      end

      it { @diff.to_hash.should == @raw_diff_hash }
    end
  end

  describe :between do
    let(:diffs) { Gitlab::Git::Diff.between(repository, 'feature', 'master') }
    subject { diffs }

    it { should be_kind_of Array }
    its(:size) { should eq(1) }

    context :diff do
      subject { diffs.first }

      it { should be_kind_of Gitlab::Git::Diff }
      its(:new_path) { should == 'files/ruby/feature.rb' }
      its(:diff) { should include '+class Feature' }
    end
  end

  describe :file_modes do
    context :submodule do
      let(:diffs) do
        Gitlab::Git::Diff.between(repository,
                                  '5937ac0a7beb003549fc5fd26fc247adbce4a52e',
                                  '570e7b2abdd848b95f2f578043fc23bd6f6fd24d')
      end
      subject { diffs[1] }

      its(:a_mode) { should == "160000" }
    end
  end
end
