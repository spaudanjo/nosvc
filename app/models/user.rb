# coding: utf-8
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable#, :validatable

  delegate  :display_name, :display_image, :short_name,
            :medium_name, :display_credits, :display_total_of_backs, :display_image_large,
            :to => :decorator

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email,
                  :password,
                  :password_confirmation,
                  :remember_me,
                  :name,
                  :nickname,
                  :bio,
                  :image_url,
                  :newsletter,
                  :full_name,
                  :address_street,
                  :address_number,
                  :address_complement,
                  :address_neighbourhood,
                  :address_city,
                  :address_state,
                  :address_zip_code,
                  :phone_number,
                  :cpf,
                  :locale,
                  :twitter,
                  :facebook_link,
                  :other_link,
                  :credits,
                  :admin

  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include Rails.application.routes.url_helpers
  extend ActiveSupport::Memoizable

  validates_presence_of :provider, :uid
  validates_uniqueness_of :uid, :scope => :provider
  validates_length_of :bio, :maximum => 140
  validates :email, :email => true, :allow_nil => true, :allow_blank => true
  #validates :name, :presence => true, :if => :is_devise?

  validates_presence_of     :email, :if => :is_devise?
  validates_uniqueness_of   :email, :scope => :provider, :if => :is_devise?
  validates_presence_of     :password, :if => :password_required?
  validates_confirmation_of :password, :if => :password_required?
  validates_length_of       :password, :within => 6..128, :allow_blank => true

  has_many :backs, :class_name => "Backer"
  has_many :projects
  has_many :led_projects, :class_name => "Project", :foreign_key => "leader_id"
  has_many :updates
  has_many :notifications
  has_many :secondary_users, :class_name => 'User', :foreign_key => :primary_user_id
  has_one :user_total
  has_and_belongs_to_many :manages_projects, :join_table => "projects_managers", :class_name => 'Project'
  belongs_to :primary, :class_name => 'User', :foreign_key => :primary_user_id, :primary_key => :id
  scope :primary, :conditions => ["primary_user_id IS NULL"]
  scope :backers, :conditions => ["id IN (SELECT DISTINCT user_id FROM backers WHERE confirmed)"]
  scope :most_backeds, ->{
    joins(:backs).select(
    <<-SQL
      users.id,
      users.name,
      users.email,
      count(backers.id) as count_backs
    SQL
    ).
    where("backers.confirmed is true").
    order("count_backs desc").
    group("users.name, users.id, users.email")
  }
  #before_save :store_primary_user
  before_save :fix_twitter_user, :fix_facebook_link, :fix_other_link
  scope :by_email, ->(email){ where('email ~* ?', email) }
  scope :by_payer_email, ->(email){  where('EXISTS(SELECT true FROM backers JOIN payment_details ON backers.id = payment_details.backer_id WHERE backers.user_id = users.id AND payment_details.payer_email ~* ?)', email) }
  scope :by_name, ->(name){ where('name ~* ?', name) }
  scope :by_id, ->(id){ where('id = ?', id) }
  scope :by_key, ->(key){ where('EXISTS(SELECT true FROM backers WHERE backers.user_id = users.id AND backers.key ~* ?)', key) }
  scope :has_credits, joins(:user_total).where('user_totals.credits > 0 OR users.credits > 0')
  scope :has_credits_difference, joins(:user_total).where('coalesce(user_totals.credits, 0) <> coalesce(users.credits, 0)')
  before_save :fix_twitter_user

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    where(conditions).where(:provider => 'devise').first
  end

  def self.backer_totals
    connection.select_one(
      self.scoped.
        joins(:user_total).
        select('count(DISTINCT user_id) as users, count(*) as backers, sum(user_totals.sum) as backed, sum(user_totals.credits) as credits, sum(users.credits) as credits_table').
        to_sql
    ).reduce({}){|memo,el| memo.merge({ el[0].to_sym => BigDecimal.new(el[1] || '0') }) }
  end

  def decorator
    UserDecorator.new(self)
  end

  def admin?
    admin
  end

  def credits
    user_total ? user_total.credits : 0.0
  end

  def facebook_id
    provider == 'facebook' && uid || secondary_users.where(provider: 'facebook').first && secondary_users.where(provider: 'facebook').first.uid
  end

  def to_param
    return "#{self.id}" unless self.display_name
    "#{self.id}-#{self.display_name.parameterize}"
  end

  def self.find_with_omni_auth(provider, uid)
    u = User.find_by_provider_and_uid(provider, uid)
    return nil unless u
    u.primary.nil? ? u : u.primary
  end

  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid = auth["uid"]
      user.name = auth["info"]["name"]
      user.email = auth["info"]["email"]
      user.email = auth["extra"]["user_hash"]["email"] if auth["extra"] and auth["extra"]["raw_info"] and user.email.nil?
      user.nickname = auth["info"]["nickname"]
      user.bio = auth["info"]["description"][0..139] if auth["info"]["description"]
      user.image_url = auth["info"]["image"] if auth["info"]["image"]
      user.locale = I18n.locale.to_s
    end
  end

  def recommended_project
    # It returns the project that have the biggest amount of backers
    # that contributed to the last project the user contributed that has common backers.
    backs.confirmed.order('confirmed_at DESC').each do |back|
      project = ActiveRecord::Base.connection.execute("SELECT count(*), project_id FROM backers b JOIN projects p ON b.project_id = p.id WHERE p.expires_at > current_timestamp AND p.id NOT IN (SELECT project_id FROM backers WHERE confirmed AND user_id = #{id}) AND b.user_id in (SELECT user_id FROM backers WHERE confirmed AND project_id = #{back.project.id.to_i}) GROUP BY 2 ORDER BY 1 DESC LIMIT 1")
      return Project.find(project[0]["project_id"]) unless project.count == 0
    end
    nil
  end
  memoize :recommended_project

  def backer?
    backs.confirmed.not_anonymous.count > 0
  end

  def total_backs
    backs.confirmed.not_anonymous.count
  end

  def backs_text
    if total_backs == 2
      I18n.t('user.backs_text.two')
    elsif total_backs > 1
      I18n.t('user.backs_text.many', :total => (total_backs-1))
    else
      I18n.t('user.backs_text.one')
    end
  end

  def remember_me_hash
    Digest::MD5.new.update("#{self.provider}###{self.uid}").to_s
  end

  def as_json(options={})

    json_attributes = {}

    if not options or (options and not options[:anonymous])
      json_attributes.merge!({
        :id => id,
        :name => display_name,
        :short_name => short_name,
        :medium_name => medium_name,
        :image => display_image,
        :total_backs => total_backs,
        :backs_text => backs_text,
        :url => user_path(self),
        :city => address_city,
        :state => address_state
      })
    end

    if options and options[:can_manage]
      json_attributes.merge!({
        :email => email
      })
    end

    json_attributes

  end

  def is_devise?
    provider == 'devise'
  end

  def twitter_link
    "http://twitter.com/#{self.twitter}"
  end

  def merge_into!(new_user)
    self.primary = new_user
    new_user.credits += self.credits
    self.credits = 0
    self.backs.update_all :user_id => new_user.id
    self.projects.update_all :user_id => new_user.id
    self.notifications.update_all :user_id => new_user.id
    self.save
    new_user.save
  end

  protected
  def fix_twitter_user
    self.twitter.gsub! /http(s)?:\/\/(www.)?twitter.com\//, '' if self.twitter
    self.twitter.gsub! /@/, '' if self.twitter
  end

  def fix_facebook_link
    unless !self.facebook_link.nil? and self.facebook_link[0..7] =~ /http(s)?:\/\//
      self.facebook_link = "https://#{self.facebook_link}" if self.facebook_link.present?
    end
  end

  def fix_other_link
    unless !self.other_link.nil? and self.other_link[0..7] =~ /http(s)?:\/\//
      self.other_link = "http://#{self.other_link}" if self.other_link.present?
    end
  end

  def password_required?
    provider == 'devise' && (!persisted? || !password.nil? || !password_confirmation.nil?)
  end

  # Returns a Gravatar URL associated with the email parameter
  def gravatar_url params=''
    return unless email
    "http://gravatar.com/avatar/#{Digest::MD5.new.update(email)}.jpg?default=#{image_url or "#{I18n.t('site.base_url')}/assets/user.png"}#{params}"
  end

end
