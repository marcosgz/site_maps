# frozen_string_literal: true

module SiteMaps::Sitemap
  class URL
    extend Forwardable

    DEFAULTS = {
      changefreq: "weekly",
      priority: 0.5
    }.freeze

    attr_reader :attributes

    def initialize(link, **attributes)
      @attributes = DEFAULTS.merge(attributes)
      @attributes[:loc] = link
      @attributes[:alternates] = SiteMaps::Primitives::Array.wrap(@attributes[:alternates])
      @attributes[:videos] = SiteMaps::Primitives::Array.wrap(@attributes[:videos])
      @attributes[:images] = SiteMaps::Primitives::Array.wrap(@attributes[:images])
      if (video = @attributes.delete(:video))
        @attributes[:videos].concat(SiteMaps::Primitives::Array.wrap(video))
      end
      if (alternate = @attributes.delete(:alternate))
        @attributes[:alternates].concat(SiteMaps::Primitives::Array.wrap(alternate))
      end
      if (image = @attributes.delete(:image))
        @attributes[:images].concat(SiteMaps::Primitives::Array.wrap(image))
      end
      @attributes[:images] = @attributes[:images][0...SiteMaps::MAX_LENGTH[:images]]
    end

    def [](key)
      attributes[key]
    end

    def to_xml
      return @to_xml if defined?(@to_xml)

      builder = ::Builder::XmlMarkup.new
      builder.url do
        builder.loc self[:loc]
        builder.lastmod w3c_date(self[:lastmod]) if self[:lastmod]
        builder.expires w3c_date(self[:expires]) if self[:expires]
        builder.changefreq self[:changefreq].to_s if self[:changefreq]
        builder.priority format_float(self[:priority]) if self[:priority]

        if news?
          news_data = self[:news]
          builder.news :news do
            builder.news :publication do
              builder.news :name, news_data[:publication_name].to_s if news_data[:publication_name]
              builder.news :language, news_data[:publication_language].to_s if news_data[:publication_language]
            end

            builder.news :access, news_data[:access].to_s if news_data[:access]
            builder.news :genres, news_data[:genres].to_s if news_data[:genres]
            builder.news :publication_date, w3c_date(news_data[:publication_date]) if news_data[:publication_date]
            builder.news :title, news_data[:title].to_s if news_data[:title]
            builder.news :keywords, news_data[:keywords].to_s if news_data[:keywords]
            builder.news :stock_tickers, news_data[:stock_tickers].to_s if news_data[:stock_tickers]
          end
        end

        self[:images].each do |image|
          builder.image :image do
            builder.image :loc, image[:loc]
            builder.image :caption, image[:caption].to_s if image[:caption]
            builder.image :geo_location, image[:geo_location].to_s if image[:geo_location]
            builder.image :title, image[:title].to_s if image[:title]
            builder.image :license, image[:license].to_s if image[:license]
          end
        end

        self[:videos].each do |video|
          builder.video :video do
            builder.video :thumbnail_loc, video[:thumbnail_loc].to_s
            builder.video :title, video[:title].to_s
            builder.video :description, video[:description].to_s
            builder.video :content_loc, video[:content_loc].to_s if video[:content_loc]
            if video[:player_loc]
              loc_attributes = {allow_embed: yes_or_no_with_default(video[:allow_embed], true)}
              loc_attributes[:autoplay] = video[:autoplay].to_s if video[:autoplay]
              builder.video :player_loc, video[:player_loc].to_s, loc_attributes
            end
            builder.video :duration, video[:duration].to_s if video[:duration]
            builder.video :expiration_date, w3c_date(video[:expiration_date]) if video[:expiration_date]
            builder.video :rating, format_float(video[:rating]) if video[:rating]
            builder.video :view_count, video[:view_count].to_s if video[:view_count]
            builder.video :publication_date, w3c_date(video[:publication_date]) if video[:publication_date]
            video[:tags]&.each { |tag| builder.video :tag, tag.to_s }
            builder.video :tag, video[:tag].to_s if video[:tag]
            builder.video :category, video[:category].to_s if video[:category]
            builder.video :family_friendly, yes_or_no_with_default(video[:family_friendly], true) if video.has_key?(:family_friendly)
            builder.video :gallery_loc, video[:gallery_loc].to_s, title: video[:gallery_title].to_s if video[:gallery_loc]
            builder.video :price, video[:price].to_s, prepare_video_price_attribs(video) if video[:price]
            if video[:uploader]
              builder.video :uploader, video[:uploader].to_s, video[:uploader_info] ? {info: video[:uploader_info].to_s} : {}
            end
            builder.video :live, yes_or_no_with_default(video[:live], true) if video.has_key?(:live)
            builder.video :requires_subscription, yes_or_no_with_default(video[:requires_subscription], true) if video.has_key?(:requires_subscription)
          end
        end

        self[:alternates].each do |alternate|
          rel = alternate[:nofollow] ? "alternate nofollow" : "alternate"
          attributes = {rel: rel, href: alternate[:href].to_s}
          attributes[:hreflang] = alternate[:lang].to_s if alternate[:lang]
          attributes[:media] = alternate[:media].to_s if alternate[:media]
          builder.xhtml :link, attributes
        end

        unless self[:mobile].nil?
          builder.mobile :mobile
        end

        if self[:pagemap].is_a?(Hash) && (pagemap = self[:pagemap]).any?
          builder.pagemap :PageMap do
            SiteMaps::Primitives::Array.wrap(pagemap[:dataobjects]).each do |dataobject|
              builder.pagemap :DataObject, type: dataobject[:type].to_s, id: dataobject[:id].to_s do
                SiteMaps::Primitives::Array.wrap(dataobject[:attributes]).each do |attribute|
                  builder.pagemap :Attribute, attribute[:value].to_s, name: attribute[:name].to_s
                end
              end
            end
          end
        end
      end
      @to_xml = builder << "\n"
    end

    def news?
      self[:news].is_a?(Hash) && self[:news].any?
    end

    def bytesize
      to_xml.bytesize
    end

    private

    def_delegator SiteMaps::Sitemap::Normalizer, :format_float
    def_delegator SiteMaps::Sitemap::Normalizer, :yes_or_no
    def_delegator SiteMaps::Sitemap::Normalizer, :yes_or_no_with_default
    def_delegator SiteMaps::Sitemap::Normalizer, :w3c_date
  end
end
