# A one-time code for logging in without the authenticator app. Only its bcrypt hash is stored.
class RecoveryCode < ApplicationRecord
  belongs_to :user
end
