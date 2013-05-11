# == Schema Information
#
# Table name: user_device_maps
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  device_id  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class UserDeviceMap < ActiveRecord::Base
  attr_accessible :device_id, :user_id
end
