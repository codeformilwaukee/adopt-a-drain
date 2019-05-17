User.where(email: 'john@example.com').first_or_initialize.tap do |user|
  user.first_name = 'John'
  user.last_name = 'Doe'
  user.password = 'password'
  user.save!
end

User.where(email: 'admin@example.com').first_or_initialize.tap do |user|
  user.first_name = 'Jane'
  user.last_name = 'Doe'
  user.password = 'password'
  user.admin = true
  user.save!
end

drain = Thing.new(name: "600 E Greenfield Ave, Milwaukee", lat: 42.9980238995142, lng: -87.8919006529653, system_use_code: "STORM", priority: false)
drain.save!
drain = Thing.new(name: "730 N Old World 3rd St, Milwaukee", lat: 43.0395624298661, lng: -87.9140865979326, system_use_code: "STORM", priority: false)
drain.save!
drain = Thing.new(name: "1671 N Marshall St, Milwaukee", lat: 43.0523156560191, lng: -87.901244986548, system_use_code: "STORM", priority: false)
drain.save!
