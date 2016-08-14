require 'test_helper'

class Sword < Asha::Model

  attribute :title
  attribute :description

  set :abilities

  set :owners do |e|
    e.sorted = true
  end

end

class Ability < Asha::Model

  attribute :name

end

class Owner < Asha::Model

  attribute :name

end


describe Asha::Set do

  let(:params) do
    {title: "Heartsbane"}
  end

  let(:sword) do
    Sword.new(params).save
  end

  it "should respond to ':all?'" do
    # ateam = Asha::Set.new()
    expect(Asha::Set.new()).must_respond_to :all?
  end

  it "should handle 'regular' sets" do
    sword.save
    ability1 = Ability.new(name: "Dragon Slayer").save
    ability2 = Ability.new(name: "White walker killer").save

    db = Minitest::Mock.new
    db.expect(:sadd, true, [sword.abilities.id, ability1.id])
    db.expect(:sadd, true, [sword.abilities.id, ability2.id])

    sword.abilities.stub("db", db) do
      sword.abilities << ability1
      sword.abilities << ability2
    end
  end

  it "should add objects as members only when redis returns succes" do
    ability1 = Ability.new(name: "Dragon Slayer").save
    ability2 = Ability.new(name: "White walker killer").save

    db = Minitest::Mock.new
    db.expect(:sadd, false, [sword.abilities.id, ability1.id])
    db.expect(:sadd, true, [sword.abilities.id, ability2.id])

    sword.abilities.stub("db", db) do
      sword.abilities << ability1
      sword.abilities << ability2
    end

    assert_includes(sword.abilities, ability2)
    refute_includes(sword.abilities, ability1)
  end

  it "should handle 'sorted' sets" do

    owner1 = Owner.new(name: "Eddard Stark").save
    owner2 = Owner.new(name: "Jon Snow").save

    db = Minitest::Mock.new
    db.expect(:zadd, true, [sword.owners.id, Fixnum, owner1.id])
    db.expect(:zadd, false, [sword.owners.id, Fixnum, owner2.id])

    sword.owners.stub("db", db) do
      sword.owners << owner1
      sword.owners << owner2
    end

 end

  it "should add objects as members only when redis returns succes" do

    owner1 = Owner.new(name: "Eddard Stark").save
    owner2 = Owner.new(name: "Jon Snow").save

    db = Minitest::Mock.new
    db.expect(:zadd, true, [sword.owners.id, Fixnum, owner1.id])
    db.expect(:zadd, false, [sword.owners.id, Fixnum, owner2.id])

    sword.owners.stub("db", db) do
      sword.owners << owner1
      sword.owners << owner2
    end

    assert_includes(sword.owners, owner1)
    refute_includes(sword.owners, owner2)
 end

end
