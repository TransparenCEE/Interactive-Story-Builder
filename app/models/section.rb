class Section < ActiveRecord::Base
  include TranslationOverride

  translates :title

  has_many :section_translations, :dependent => :destroy
  belongs_to :story
  has_one :content, dependent: :destroy
  has_one :slideshow, dependent: :destroy
  # has_one :asset,     
  #   :conditions => "asset_type = #{Asset::TYPE[:section_audio]}",    
  #   foreign_key: :item_id,
  #   dependent: :destroy

  has_one :embed_medium, dependent: :destroy
  has_many :media, :order => 'position', dependent: :destroy
  has_one :youtube, dependent: :destroy
  acts_as_list scope: :story

  # accepts_nested_attributes_for :asset, :reject_if => lambda { |c| c[:asset].blank? }
  accepts_nested_attributes_for :section_translations

  # attr_accessor :delete_audio

  TYPE = {content: 1, media: 2, slideshow: 3, embed_media: 4, youtube: 5}
  ICONS = {
    content: 'i-content-b', 
    media: 'i-fullscreen-b', 
    slideshow: 'i-slideshow-b', 
    embed_media: 'i-embed-b',
    youtube: 'i-youtube-b'

  }

  #################################
  # settings to clone story
  amoeba do
    enable
    clone [:section_translations, :content, :media, :slideshow, :embed_medium, :youtube]
  end

  #################################
  ## Validations
  validates :story_id, :presence => true
  validates :type_id, :presence => true, :inclusion => { :in => TYPE.values }  

  # #################################
  # ## Callbacks
  # before_save :check_delete_audio

  # # if delete_audio flag set, then delete the audio asset
  # def check_delete_audio
  #   logger.debug "///////////// check_delete_audio start"
  #   logger.debug "///////////// delete_audio = #{delete_audio.present? && delete_audio.to_bool}; asset present = #{self.asset.present?}"
  #   if delete_audio.present? && delete_audio.to_bool == true && self.asset.present?
  #     logger.debug "///////////// - deleting audio!"
  #     self.asset.destroy
  #   end
  # end  


  #################################

  def to_json(options={})
    options[:except] ||= [:created_at, :updated_at]
    super(options)
  end

  def get_icon
    key = get_str_type
    if key.present?
      ICONS[key]
    end
  end

  def get_str_type
  	 TYPE.keys[TYPE.values.index(self.type_id)]
  end

  ##############################
  ## shortcut methods to get to asset objects in translation
  ##############################
  # create model variable @asset to store the asset record for later use without having to call the db again
  @asset = nil

  def asset
    if @asset.present?
      return @asset
    else
      x = self.section_translations.where(:locale => self.current_locale).first
      if x.present?
        @asset = x.asset
        return @asset
      end
    end
  end

  def asset_exists?
    asset.present? && asset.file.exists?
  end     

  #################################

  # get the translation record for the given locale
  # if it does not exist, build a new one if wanted
  def with_translation(locale, build_if_missing=true)
    @local_translations ||= {}
    if @local_translations[locale].blank?
      x = self.section_translations.where(:locale => locale).first
      if x.blank? && build_if_missing
        x = self.section_translations.build(locale: locale)
      end

      @local_translations[locale] = x
    end
    return @local_translations[locale]
  end

  ##############################

  def content?
  	 TYPE[:content] == self.type_id	
  end
  def media?
   	 TYPE[:media] == self.type_id	
  end
  def slideshow?
     TYPE[:slideshow] == self.type_id 
  end
  def embed_media?
     TYPE[:embed_media] == self.type_id 
  end
    def youtube?
     TYPE[:youtube] == self.type_id 
  end


  def ok?
    if content?
      return (self.content.present? && self.content.text.present?)
    elsif media?        
        exists = []
        self.media.each_with_index do |m,m_i|
          if m.present?
            if m.media_type == Medium::TYPE[:image]
              exists << m.image_exists?                                
            elsif m.media_type == Medium::TYPE[:video]
              exists << (m.image_exists? && m.video_exists?)
            end          
          else
            exists << false
          end
        end
        return !exists.include?(false)
    elsif slideshow?
      return self.slideshow.present? && self.slideshow.assets.present?
    elsif embed_media?
      return self.embed_medium.present? && self.embed_medium.code.present?
   elsif youtube?
      return self.youtube.present? && self.youtube.code.present?
    end
  end
end
