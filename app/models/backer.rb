# coding: utf-8
class Backer < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::DateHelper
  belongs_to :project
  belongs_to :user
  belongs_to :reward
  has_many :payment_logs
  has_one :payment_detail
  has_many :dynamic_values
  validates_presence_of :project, :user, :value
  validates_numericality_of :value, :greater_than_or_equal_to => 0.00
  validate :reward_must_be_from_project
  scope :anonymous, where(:anonymous => true)
  scope :not_anonymous, where(:anonymous => false)
  scope :confirmed, where(:confirmed => true)
  scope :not_confirmed, where(:confirmed => false)
  scope :pending, where(:confirmed => false)
  scope :display_notice, where(:display_notice => true)
  scope :can_refund, where(:can_refund => true)
  scope :within_refund_deadline, where("date(current_timestamp) <= date(created_at + interval '180 days')")
  after_create :define_key, :define_payment_method
  #attr_protected :confirmed
  accepts_nested_attributes_for :dynamic_values

  def define_key
    self.update_attributes({ key: Digest::MD5.new.update("#{self.id}###{self.created_at}###{Kernel.rand}").to_s })
  end

  def define_payment_method
    self.update_attributes({ payment_method: 'MoIP' })
  end

  def price_in_cents
    (self.value * 100).round
  end

  before_save :confirm?

  def confirm?
    if confirmed and confirmed_at.nil?
      self.confirmed_at = Time.now
      self.display_notice = true
    end
  end

  def confirm!
    self.confirmed = true
    self.confirmed_at = Time.now
    self.save
    notify_confirmation
  end

  def reward_must_be_from_project
    return unless reward
    errors.add(:reward, I18n.t('backer.reward_must_be_from_project')) unless reward.project == project
  end

  validate :value_must_be_at_least_rewards_value

  def value_must_be_at_least_rewards_value
    return unless reward
    errors.add(:value, I18n.t('backer.value_must_be_at_least_rewards_value', :minimum_value => reward.display_minimum)) unless value >= reward.minimum_value
  end

  validate :should_not_back_if_maximum_backers_been_reached, :on => :create

  def should_not_back_if_maximum_backers_been_reached
    return unless reward and reward.maximum_backers and reward.maximum_backers > 0
    errors.add(:reward, I18n.t('backer.should_not_back_if_maximum_backers_been_reached')) unless reward.backers.confirmed.count < reward.maximum_backers
  end

  def display_value
    number_to_currency value, :unit => "EUR", :precision => 0, :delimiter => '.'
  end

  def display_total_paid
    number_to_currency total_paid, :unit => "EUR", :precision => 0, :delimiter => '.'
  end

  def display_confirmed_at
    I18n.l(confirmed_at.to_date) if confirmed_at
  end

  def platform_fee(fee=7.5)
    (value.to_f * fee)/100
  end

  def display_platform_fee(fee=7.5)
    number_to_currency platform_fee(fee), :unit => "EUR", :precision => 2, :delimiter => '.'
  end

  def payment_service_fee
    (payment_detail || build_payment_detail.update_from_service).service_tax_amount.to_f
  end

  def moip_value
    "%0.0f" % (value * 100)
  end

  def cancel_refund_request!
    raise I18n.t('credits.cannot_cancel_refund_reques') unless self.requested_refund
    raise I18n.t('credits.refund.refunded') if self.refunded
    raise I18n.t('credits.refund.no_credits') unless self.user.credits >= self.value
    self.update_attributes({ requested_refund: false })
    self.user.update_attributes({ credits: (self.user.credits + self.value) })
  end

  def refund_deadline
    created_at + 180.days
  end

  def as_json(options={})
    json_attributes = {
      :id => id,
      :anonymous => anonymous,
      :confirmed => confirmed,
      :confirmed_at => display_confirmed_at,
      :value => display_value,
      :user => user.as_json(options.merge(:anonymous => anonymous)),
      :display_value => nil,
      :reward => nil
    }
    if options and options[:can_manage]
      json_attributes.merge!({
        :display_value => display_value,
        :reward => reward
      })
    end
    if options and options[:include_project]
      json_attributes.merge!({:project => project})
    end
    if options and options[:include_reward]
      json_attributes.merge!({:reward => reward})
    end
    json_attributes
  end

  protected
  def notify_confirmation
    text = I18n.t('notifications.backers.to_backer.text',
                  :backer_name => user.display_name,
                  :backer_value => display_value,
                  :reward => "#{reward.description if reward}",
                  :city => project.category.name,
                  :date => project.when_long,
                  :project_link => Rails.application.routes.url_helpers.project_url(project, :host => I18n.t('site.host')),
                  :project_name => project.name,
                  :user_name => project.user.display_name,
                  :user_email => project.user.email)
    Notification.create! :user => user,
                         :email_subject => I18n.t('notifications.backers.to_backer.subject', :project => project.name),
                         :email_text => text,
                         :text => text
    text_project_owner = I18n.t('notifications.backers.to_project_owner.text',
                                :backer_name => user.display_name,
                                :backer_email => user.email,
                                :backer_value => display_value,
                                :reward => "#{reward.description if reward}",
                                :project_link => Rails.application.routes.url_helpers.project_url(project, :host => I18n.t('site.host')),
                                :project_name => project.name)
    Notification.create! :user => project.user,
                         :email_subject => I18n.t('notifications.backers.to_project_owner.subject', :backer_name => user.display_name),
                         :email_text => text_project_owner,
                         :text => text_project_owner
  end
end
