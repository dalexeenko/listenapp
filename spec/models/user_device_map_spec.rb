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

require 'spec_helper'

describe UserDeviceMap do
  pending "add some examples to (or delete) #{__FILE__}"
end
