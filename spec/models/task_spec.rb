require "rails_helper"

RSpec.describe Task, type: :model do
  describe "database constraints" do
    it "rejects null title and status even when model validation is bypassed" do
      [ { title: nil, status: "todo" }, { title: "Task", status: nil } ].each do |attributes|
        expect { described_class.insert_all!([ attributes ]) }
          .to raise_error(ActiveRecord::NotNullViolation)
      end
      expect(described_class.count).to eq(0)
    end

    it "rejects an empty title even when model validation is bypassed" do
      expect { described_class.insert_all!([ { title: "", status: "todo" } ]) }
        .to raise_error(ActiveRecord::StatementInvalid)
      expect(described_class.count).to eq(0)
    end

    it "rejects unknown status even when model validation is bypassed" do
      expect { described_class.insert_all!([ { title: "Task", status: "paused" } ]) }
        .to raise_error(ActiveRecord::StatementInvalid)
      expect(described_class.count).to eq(0)
    end
  end
end
