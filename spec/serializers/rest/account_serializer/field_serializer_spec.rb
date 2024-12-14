# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::AccountSerializer::FieldSerializer do
  subject { serialized_record_json(field, described_class) }

  let(:default_datetime) { DateTime.new(2024, 11, 28, 16, 20, 0) }
  let(:user)    { Fabricate(:user) }
  let(:account) { user.account }

  context 'when verified_at is populated' do
    let(:field) { Account::Field.new(account, 'name' => 'Foo', 'value' => 'Bar', 'verified_at' => default_datetime) }

    it 'parses as RFC 3339 datetime' do
      expect { DateTime.rfc3339(subject['verified_at']) }.to_not raise_error
    end
  end
end
