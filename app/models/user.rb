# frozen_string_literal: true
# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  email                     :string           default(""), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  encrypted_password        :string           default(""), not null
#  reset_password_token      :string
#  reset_password_sent_at    :datetime
#  remember_created_at       :datetime
#  sign_in_count             :integer          default(0), not null
#  current_sign_in_at        :datetime
#  last_sign_in_at           :datetime
#  current_sign_in_ip        :inet
#  last_sign_in_ip           :inet
#  admin                     :boolean          default(FALSE), not null
#  confirmation_token        :string
#  confirmed_at              :datetime
#  confirmation_sent_at      :datetime
#  unconfirmed_email         :string
#  locale                    :string
#  encrypted_otp_secret      :string
#  encrypted_otp_secret_iv   :string
#  encrypted_otp_secret_salt :string
#  consumed_timestep         :integer
#  otp_required_for_login    :boolean          default(FALSE), not null
#  last_emailed_at           :datetime
#  otp_backup_codes          :string           is an Array
#  filtered_languages        :string           default([]), not null, is an Array
#  account_id                :integer          not null
#  disabled                  :boolean          default(FALSE), not null
#  moderator                 :boolean          default(FALSE), not null
#  invite_id                 :integer
#

class User < ApplicationRecord
  include Settings::Extend

  ACTIVE_DURATION = 14.days

  devise :two_factor_authenticatable,
         otp_secret_encryption_key: ENV['OTP_SECRET']

  devise :two_factor_backupable,
         otp_number_of_backup_codes: 10

  devise :registerable, :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  belongs_to :account, inverse_of: :user, required: true
  belongs_to :invite, counter_cache: :uses
  accepts_nested_attributes_for :account

  has_many :applications, class_name: 'Doorkeeper::Application', as: :owner

  validates :locale, inclusion: I18n.available_locales.map(&:to_s), if: :locale?
  validates_with BlacklistedEmailValidator, if: :email_changed?

  scope :recent, -> { order(id: :desc) }
  scope :admins, -> { where(admin: true) }
  scope :moderators, -> { where(moderator: true) }
  scope :staff, -> { admins.or(moderators) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :inactive, -> { where(arel_table[:current_sign_in_at].lt(ACTIVE_DURATION.ago)) }
  scope :active, -> { confirmed.where(arel_table[:current_sign_in_at].gteq(ACTIVE_DURATION.ago)).joins(:account).where(accounts: { suspended: false }) }
  scope :matches_email, ->(value) { where(arel_table[:email].matches("#{value}%")) }
  scope :with_recent_ip_address, ->(value) { where(arel_table[:current_sign_in_ip].eq(value).or(arel_table[:last_sign_in_ip].eq(value))) }

  before_validation :sanitize_languages

  # This avoids a deprecation warning from Rails 5.1
  # It seems possible that a future release of devise-two-factor will
  # handle this itself, and this can be removed from our User class.
  attribute :otp_secret

  has_many :session_activations, dependent: :destroy

  delegate :auto_play_gif, :default_sensitive, :unfollow_modal, :boost_modal, :delete_modal,
           :reduce_motion, :system_font_ui, :noindex, :theme,
           :wide_columns,
           to: :settings, prefix: :setting, allow_nil: false

  attr_accessor :invite_code

  def confirmed?
    confirmed_at.present?
  end

  def staff?
    admin? || moderator?
  end

  def role
    if admin?
      'admin'
    elsif moderator?
      'moderator'
    else
      'user'
    end
  end

  def role?(role)
    case role
    when 'user'
      true
    when 'moderator'
      staff?
    when 'admin'
      admin?
    else
      false
    end
  end

  def disable!
    update!(disabled: true,
            last_sign_in_at: current_sign_in_at,
            current_sign_in_at: nil)
  end

  def enable!
    update!(disabled: false)
  end

  def confirm
    new_user = !confirmed?

    super
    update_statistics! if new_user
  end

  def confirm!
    new_user = !confirmed?

    skip_confirmation!
    save!
    update_statistics! if new_user
  end

  def promote!
    if moderator?
      update!(moderator: false, admin: true)
    elsif !admin?
      update!(moderator: true)
    end
  end

  def demote!
    if admin?
      update!(admin: false, moderator: true)
    elsif moderator?
      update!(moderator: false)
    end
  end

  def disable_two_factor!
    self.otp_required_for_login = false
    otp_backup_codes&.clear
    save!
  end

  def active_for_authentication?
    super && !disabled?
  end

  def setting_default_privacy
    settings.default_privacy || (account.locked? ? 'private' : 'public')
  end

  def token_for_app(a)
    return nil if a.nil? || a.owner != self
    Doorkeeper::AccessToken
      .find_or_create_by(application_id: a.id, resource_owner_id: id) do |t|

      t.scopes = a.scopes
      t.expires_in = Doorkeeper.configuration.access_token_expires_in
      t.use_refresh_token = Doorkeeper.configuration.refresh_token_enabled?
    end
  end

  def activate_session(request)
    session_activations.activate(session_id: SecureRandom.hex,
                                 user_agent: request.user_agent,
                                 ip: request.remote_ip).session_id
  end

  def exclusive_session(id)
    session_activations.exclusive(id)
  end

  def session_active?(id)
    session_activations.active? id
  end

  def web_push_subscription(session)
    session.web_push_subscription.nil? ? nil : session.web_push_subscription.as_payload
  end

  def invite_code=(code)
    self.invite  = Invite.find_by(code: code) unless code.blank?
    @invite_code = code
  end

  protected

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  private

  def sanitize_languages
    filtered_languages.reject!(&:blank?)
  end

  def update_statistics!
    BootstrapTimelineWorker.perform_async(account_id)
    ActivityTracker.increment('activity:accounts:local')
  end
end
