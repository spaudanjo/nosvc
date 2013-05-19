# coding: utf-8
class Reward < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  include ERB::Util
  belongs_to :project
  has_many :backers
  validates_presence_of :minimum_value, :description
  validates_numericality_of :minimum_value, :greater_than_or_equal_to => 0.00
  validates_numericality_of :maximum_backers, :only_integer => true, :greater_than => 0, :allow_nil => true
  scope :remaining, where("maximum_backers IS NULL OR (maximum_backers IS NOT NULL AND (SELECT COUNT(*) FROM backers WHERE confirmed AND reward_id = rewards.id) < maximum_backers)")
  scope :not_expired, where("expires_at >= current_timestamp OR expires_at IS NULL")
  scope :public, -> { where('private = ? or private IS NULL', false) }
  scope :not_public, -> { where(:private => true) }
  scope :with_token, ->(token) { where(:token => token) }

  before_save :set_token

  def sold_out?
    maximum_backers and backers.confirmed.count >= maximum_backers
  end
  def expired?
    return false unless expires_at
    expires_at < Time.now
  end
  def display_expires_at
    return false unless expires_at
    I18n.l(expires_at.to_date)
  end
  def remaining
    return nil unless maximum_backers
    maximum_backers - backers.confirmed.count
  end
  def display_remaining
    I18n.t('reward.display_remaining', :remaining => remaining)
  end
  def display_maximum_backers
    I18n.t('reward.display_maximum_backers', :maximum => maximum_backers)
  end
  def name
    if maximum_backers
      if sold_out?
        status = "<div class='sold_out'>#{I18n.t('reward.sold_out')}</div>"
      else
        status = "<div class='remaining'>#{display_remaining.html_safe}</div>"
      end
    else
      status = "<div class='unlimited'>#{I18n.t('reward.unlimited')}</div>"
    end
    maximum_backers_html = "#{status}<div class='expires_at'><span>#{I18n.t('until')}</span> #{display_expires_at || project.display_expires_at}</div><div class='clearfix'></div>"

    "<div class='left'><div class='reward_minimum_value'>#{minimum_value > 0 ? display_minimum : I18n.t('reward.free')}</div><div class='reward_description'>#{h description}</div>#{'<div class="sold_out">' + I18n.t('reward.sold_out') + '</div>' if sold_out?}</div><div class='right'>#{maximum_backers_html}</div><div class='clear'></div>".html_safe
  end
  def display_minimum
    number_to_currency minimum_value, :unit => 'EUR', :precision => 2, :delimiter => '.'
  end
  def short_description
    truncate description, :length => 35
  end
  def medium_description
    truncate description, :length => 65
  end
  def as_json(options={})
    {
      :id => id,
      :display_with_label => I18n.t('projects.rewards.reward_title', :minimum => display_minimum),
      :display_minimum => display_minimum,
      :description => description,
      :short_description => short_description,
      :medium_description => medium_description
    }
  end

  private
  def set_token
    self.token ||= SecureRandom::hex(30) if self.private == true
  end
end
