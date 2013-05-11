# == Schema Information
#
# Table name: devices
#
#  id          :integer          not null, primary key
#  device_guid :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Device < ActiveRecord::Base
  attr_accessible :device_guid
end
