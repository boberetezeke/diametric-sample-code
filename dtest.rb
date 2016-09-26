puts "before require"
require 'bundler'
Bundler.require

#require_relative "lib/clj"

if ARGV.size < 1
  puts "usage: [-c] database_name"
  exit
else
  create = false
  if ARGV.size  == 2 && ARGV[0]  == "-c"
    create = true
    database_name = ARGV[1]
  elsif ARGV.size  ==  1
    database_name = ARGV[0]
  else
    puts "error: invalid arguments"
    puts "usage: [-c] database_name"
  end
  puts "database_name = #{database_name}"
  puts "create = #{create.inspect}"
end

uri = 'datomic:mem://sample'
#uri = "datomic:free://localhost:4334/#{database_name}"

puts "before exit"

Diametric::Persistence.establish_base_connection({:uri=>uri})
puts "before exit2"

conn = Diametric::Persistence::Peer.connect


=begin
res = Diametric::Persistence::Peer.q("[:find ?entity :where [?entity :person/name]]", conn.db)
puts "query result = #{res.inspect}"
res.each do |r|
  puts "r = #{r.inspect}"
  entity = conn.db.entity(r.first)
  puts "entity = #{entity.inspect}"
  entity.keys.each do |key|
    puts "key = #{key}"
    puts "value = #{entity[key]}"
  end
end
exit
=end

module Color
  def self.mixin(mod)
    mod.attribute :color, String, prefix: :common
  end
end

class Person
  include Diametric::Entity
  include Diametric::Persistence::Peer

  attribute :name, String, index: true
  attribute :size, String, index: true

  #attribute :color, String, prefix: :common
  mixin Color

  #attribute :simulation_run, Ref

  #attribute :birthday, DateTime
  #attribute :awesomeness, Boolean, doc: "Is this person awesome?"
end

#Person.include(Diametric::Entity)
#Person.include(Diametric::Persistence::Peer)
#Person.attribute :name, String, index: true
#Person.attribute :size, String, index: true
#Person.attribute :common, String, prefix: 'common'

class SimulationRun
  include Diametric::Entity
  include Diametric::Persistence::Peer

  attribute :name, String, index: true
  #attribute :birthday, DateTime
  #attribute :awesomeness, Boolean, doc: "Is this person awesome?"
end

class SimulationRunRef
  include Diametric::Entity
  include Diametric::Persistence::Peer

  attribute :ref, Ref
end

class Audit
  include Diametric::Entity
  include Diametric::Persistence::Peer

  attribute :time_stamp, Integer

end

if create
  Person.create_schema.get
  SimulationRun.create_schema.get
  SimulationRunRef.create_schema.get
  Audit.create_schema.get

  puts "in main, Person schema = #{Person.schema.inspect}"
  puts "in main, SimulationRun schema = #{SimulationRun.schema.inspect}"

=begin
  #map = conn.transact([{ :"db/id" => Diametric::Persistence::Peer.tempid(:"db.part/user", -1000001), :"container/name" => 'Steve' } ]).get
  map = conn.transact([
      {
        :"db/id" => Diametric::Persistence::Peer.tempid(:"db.part/user", -1000001),
        :"simulation_run/name" => Time.now.to_s
      }
     ]).get

  simulation_run = SimulationRun.first
  puts "simulation_run = #{simulation_run.inspect}"
  puts "simulation_run.dbid = #{simulation_run.dbid}"

  map = conn.transact([
      {
        :"db/id" => Diametric::Persistence::Peer.tempid(:"db.part/user", -1000000),
        :"person/name" => "Joe",
        :"person/size" => "small"
      },
      {
        :"db/id" => Diametric::Persistence::Peer.tempid(:"db.part/user", -1000001),
        :"simulation_run_ref/ref" => simulation_run.dbid.to_i
      }
     ]).get

  puts "# of people = #{Diametric::Query.new(Person, nil, true).all.size}"
=end
  p = Person.new(name: 'Steve', size: 'small', color: 'blue')
  s = SimulationRun.new(name: 'Test')
  a = Audit.new(time_stamp: 0)

  conn.transaction do
    p.save
    s.save
    a.save
  end

=begin
  puts "---- before save simulation_run"
  s.save

  puts "---- before save person"
  p.simulation_run = s
  p.save

  puts "---- before update person"
  p.name = 'Angie'
  p.save
=end

end

#binding.pry
#exit

=begin
time = Time.now
#basis = conn.basis_t
map = conn.transact([{:"db/id" => Diametric::Persistence::Peer.tempid(:"db.part/user", -1000000), :"person/name" => "Joe"}])
map2 = map.get
puts "to_s = #{map2.to_s}"
puts "# of names = #{Diametric::Query.new(Person, nil, true).all.size}"

#past_db = conn.db.as_of(after_1st.hex)
#past_db = conn.db.as_of(basis)
past_db = conn.db.as_of(time)
puts "# of names = #{Diametric::Query.new(Person, past_db, true).all.size}"
=end

def all_history(conn, entity)
  res = Diametric::Persistence::Peer.q(
    "[" +
      ":find ?e ?a ?v ?tx ?added ?time_stamp " +
      ":in $ ?e " +
      ":where " +
        "[?e ?a ?v ?tx ?added] " +
        "[_ :audit/time_stamp ?time_stamp ?tx]"  +
      "] " +
    "]",
    conn.db.history, entity
  )
end

=begin
(defn all-history-with-attr-names
  "Return all e/a/v/tx/added for e"
  [db e]
  (sort-by #(nth % 3)
           (into []
                 (d/q '[:find ?e ?attr_name ?v ?tx ?added
                        :in $db $dbh ?e
                        :where
                        [$dbh ?e ?a ?v ?tx ?added]
                        [$db ?a :db/ident ?attr_name]]
                      db (d/history db)
                      e))))
=end
def all_history_with_attr_names(conn, entity)
  res = Diametric::Persistence::Peer.q(
    "[" +
      ":find ?e ?attr_name ?v ?tx ?added ?time_stamp " +
      ":in $db, $dbh, ?e " +
      ":where " +
        "[$dbh ?e ?a ?v ?tx ?added] "  +
        "[$dbh _ :audit/time_stamp ?time_stamp ?tx] "  +
        "[$db ?a :db/ident ?attr_name]"  +
      "] " +
    "]",
    conn.db, conn.db.history, entity
  )
  res.sort_by {|x| x[3]}
end

def versions(conn, entity)
  res = Diametric::Persistence::Peer.q(
    "[:find ?tx :in $ ?e :where [?e _ _ ?tx]]", conn.db.history, entity
  )
  display_results("beforer as of", res)
  res.map {|r| h = {}; e = conn.db.as_of(r.first).entity(entity); e.keys.each{|k| h[k] = e[k]}; h }
=begin
  res.map do |ary|
    puts "ary = #{ary.inspect}"
    entity = conn.db.entity(ary.first)
    puts "entity = #{entity.inspect}"
    #conn.db.as_of(ary), entity)
  end
=end
end
=begin
(defn simulation-history
  [simulation_run db]
  (sort-by #(nth % 1)
           (into []
                 (d/q '[:find ?e ?tx2 ?attr_name ?v ?added
                        :in $db $dbh ?simulation_run
                        :where
                        [$db ?e :simulation_run_ref/ref ?simulation_run]
                        [$db ?a :db/ident ?attr_name]
                        [$dbh ?e ?a ?v ?tx2 ?added]]
                      db (d/history db) simulation_run))))
=end

def simulation_history(db, simulation_run)
  res = Diametric::Persistence::Peer.q(
    "[:find ?e ?tx2 ?attr_name ?v ?added " +
         ":in $db $dbh ?simulation_run " +
         ":where " +
         "[$db ?e :simulation_run_ref/ref ?simulation_run] " +
         "[$db ?a :db/ident ?attr_name] " +
         "[$dbh ?e ?a ?v ?tx2 ?added]] ",
         db, db.history, simulation_run)
  res.sort_by{|r| r[1]}
end

def display_results(desc, res)
  puts "-------------- #{desc} -------------------"
  res.each do |r|
    puts "r = #{r.inspect}"
  end
end

puts "-------------- All People -------------------"
query = Diametric::Query.new(Person).where(color: 'blue')
query.each do |ary|
  puts "ary: #{ary.inspect}"
  person = Person.reify(ary.first)
  puts "name: #{person.name}"
  puts "size: #{person.size}"
  puts "color: #{person.color}"
  #simulation_run = SimulationRun.reify(person.simulation_run)
  #puts "simulation_run: #{simulation_run.name}"

  person.color = "pink"
  conn.transaction do
    person.save
  end

  audit = Audit.new(time_stamp: 1)
  person.size = nil

  conn.transaction do
    person.save
    audit.save
  end

  person.name = "Fred"
  person.color = "orange"
  audit = Audit.new(time_stamp: 2)

  conn.transaction do
    person.save
    audit.save
  end
end

puts "-------------- All SimulationRuns -------------------"
query = Diametric::Query.new(SimulationRun)
query.each do |ary|
  puts "ary = #{ary.inspect}"
  simulation_run = SimulationRun.reify(ary.first)
  puts "simulation_run: #{simulation_run.name}"
end

#person = 17592186045433
person = Person.first.dbid.to_i
simulation_run = SimulationRun.first.dbid.to_i
display_results("all people", Diametric::Query.new(Person))
display_results("all history of Fred", all_history(conn, person))
display_results("all history of Fred with attr names" , all_history_with_attr_names(conn, person))
display_results("versions of Fred", versions(conn, person))
display_results("history of simulation", simulation_history(conn.db, simulation_run))

puts "------------------------------------------"

puts "basis-t = #{conn.db.basis_t}"
=begin
res = Diametric::Persistence::Peer.q(
  "[:find ?entity ?person_name ?person_size ?entity2 ?simulation_name " +
     ":where " +
       "[?entity :person/name ?person_name ?tx]" +
       "[?entity :person/size ?person_size ?tx]" +
       "[?entity2 :simulation_run/name ?simulation_name ?tx]" +

       #{}"[?entity :person/name ?person_name 13194139534328]" +
       #{}"[?entity :person/size ?person_size 13194139534328]" +
       #{}"[?entity2 :simulation_run/name ?simulation_name 13194139534328]" +

       #}"[?entity :person/name         ?person_name         ?tx]" +
       #"[?tx     :simulation_run/name ?simulation_run_name]" +
     "" +
  "]",
  conn.db)
res.each do |r|
  puts "r = #{r.inspect}"
end
=end
#puts "parsed expression: #{Clojure.parse(map2.to_s).inspect}"


=begin
person = Person.new
person.name = "Fred"
person.save
=end



exit
