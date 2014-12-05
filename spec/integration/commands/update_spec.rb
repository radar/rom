require 'spec_helper'

require 'ostruct'

describe 'Commands / Update' do
  include_context 'users and tasks'

  subject(:users) { rom.commands.users }

  before do
    UserValidator = Class.new do
      ValidationError = Class.new(ROM::CommandError)

      def self.call(params)
        raise ValidationError, ":email is required" unless params[:email]
      end
    end

    setup.relation(:users) do
      def all(criteria)
        restrict(criteria)
      end

      def by_name(name)
        restrict(name: name)
      end
    end

    setup.commands(:users) do
      define(:update) do
        input Hash
        validator UserValidator
      end
    end

  end

  it 'update tuples on successful validation' do
    result = users.try {
      update(:all, name: 'Jane').set(email: 'jane.doe@test.com')
    }

    expect(result).to match_array([{ name: 'Jane', email: 'jane.doe@test.com' }])
  end

  it 'returns validation object with errors on failed validation' do
    result = users.try { update(:all, name: 'Jane').set(email: nil) }

    expect(result.error).to be_instance_of(ValidationError)
    expect(result.error.message).to eql(':email is required')

    expect(rom.relations.users.restrict(name: 'Jane')).to match_array([
      { name: 'Jane', email: 'jane@doe.org' }
    ])
  end

  describe '"result" option' do

    it 'returns a single tuple when set to :one' do
      setup.commands(:users) do

        define(:update_one, type: :update) do
          input Hash
          validator Proc.new {}
          result :one
        end

      end

      result = users.try {
        update_one(:by_name, 'Jane').set(email: 'jane.doe@test.com')
      }

      expect(result.value).to eql(name: 'Jane', email: 'jane.doe@test.com')
    end

    it 'allows only valid result types' do
      expect {

        setup.commands(:users) do
          define(:create_one, type: :create) do
            input Hash
            validator Proc.new {}
            result :invalid_type
          end
        end
        setup.finalize

      }.to raise_error(ArgumentError, /create command result/)
    end

  end

end