# Gitlab::Git::Diff is a wrapper around native Grit::Diff object
# We dont want to use grit objects inside app/
# It helps us easily migrate to rugged in future
module Gitlab
  module Git
    class Diff
      class TimeoutError < StandardError; end

      attr_accessor :raw_diff

      # Diff properties
      attr_accessor :old_path, :new_path, :a_mode, :b_mode, :diff, :hunks

      # Stats properties
      attr_accessor  :new_file, :renamed_file, :deleted_file

      class << self
        def between(repo, head, base, *paths)
          # Only show what is new in the source branch compared to the target branch, not the other way around.
          # The linex below with merge_base is equivalent to diff with three dots (git diff branch1...branch2)
          # From the git documentation: "git diff A...B" is equivalent to "git diff $(git-merge-base A B) B"
          common_commit = repo.merge_base_commit(head, base)

          repo.diff(common_commit, head, *paths).map do |diff|
            Gitlab::Git::Diff.new(diff)
          end
        rescue Grit::Git::GitTimeout
          raise TimeoutError.new("Diff.between exited with timeout")
        end
      end

      def initialize(raw_diff)
        raise "Nil as raw diff passed" unless raw_diff

        if raw_diff.is_a?(Hash)
          init_from_hash(raw_diff)
        elsif raw_diff.is_a?(Rugged::Patch)
          init_from_rugged(raw_diff)
        else
          #TODO remove this will be great
          init_from_grit(raw_diff)
        end
      end

      def serialize_keys
        @serialize_keys ||= %w(diff new_path old_path a_mode b_mode new_file renamed_file deleted_file).map(&:to_sym)
      end

      def to_hash
        hash = {}

        keys = serialize_keys

        keys.each do |key|
          hash[key] = send(key)
        end

        hash
      end

      def submodule?
        #TODO NOTE FIXME added submodules a_mode is nil in grit
        a_mode == "160000" || b_mode == "160000"
      end

      private

      def init_from_grit(grit)
        @raw_diff = grit

        serialize_keys.each do |key|
          send(:"#{key}=", grit.send(key))
        end
      end

      def init_from_hash(hash)
        raw_diff = hash.symbolize_keys

        serialize_keys.each do |key|
          send(:"#{key}=", raw_diff[key.to_sym])
        end
      end

      def init_from_rugged(rugged_patch)
        delta = rugged_patch.delta
        self.old_path = delta.old_file[:path]
        self.new_path = delta.new_file[:path]
        self.a_mode = delta.old_file[:mode].to_s(8)
        self.b_mode = delta.new_file[:mode].to_s(8)
        self.new_file = delta.added?
        self.deleted_file = delta.deleted?
        self.renamed_file = !new_file && !deleted_file
        self.hunks = rugged_patch.hunks
      end
    end
  end
end

