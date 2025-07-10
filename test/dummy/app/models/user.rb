class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  # Include CCCUX functionality
  include Cccux::UserConcern
  
  # Associations
  has_many :posts, dependent: :destroy
  
  # Validations

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  
  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def display_name
    full_name.presence || email
  end
  
  # CCCUX role methods (these come from the concern)
  # has_role?(role_name)
  # add_role(role_name)
  # remove_role(role_name)
  # roles
  # etc.
end 