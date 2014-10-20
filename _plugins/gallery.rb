require 'rake'

module Test

  class Magick
    class << self
      include Rake::FileUtilsExt

      def generate_thumbnail(src, dst, width, height, force = false)
        return if (!force) && File.exists?(dst)
        mkdir_p(File.dirname(dst))
        sh('convert',
          '-define', "jpeg:size=#{Integer(width)*2}x#{Integer(height)*2}",
          src,
          '-thumbnail', "#{Integer(width)}x#{Integer(height)}^",
          '-gravity', 'center',
          '-extent', "#{Integer(width)}x#{Integer(height)}",
          '-quality', '80',
          '-strip',
          '-colorspace', 'rgb',
          '-filter', 'Lanczos',
          dst
        )
      end

      def generate_video_thumbnail(src, dst, overlay, width, height, force = false)
        return if (!force) && File.exists?(dst)
        mkdir_p(File.dirname(dst))
        sh('convert',
          '-define', "jpeg:size=#{Integer(width)*2}x#{Integer(height)*2}",
          src,
          '-thumbnail', "#{Integer(width)}x#{Integer(height)}^",
          '-gravity', 'center',
          '-extent', "#{Integer(width)}x#{Integer(height)}",
          '-quality', '80',
          '-strip',
          '-colorspace', 'rgb',
          '-filter', 'Lanczos',
          '-write', 'mpr:orig',
          '+delete', 'mpr:orig',
          overlay,
          '-gravity', 'SouthWest',
          '-composite',
          dst
        )
      end

      def generate_resized(src, dst, size, force = false)
        return if (!force) && File.exists?(dst)
        mkdir_p(File.dirname(dst))
        sh('convert',
          src,
          '-resize', "#{Integer(size)}x#{Integer(size)}>",
          '-quality', '80',
          '-strip',
          '-colorspace', 'rgb',
          '-filter', 'Lanczos',
          dst
        )
      end
    end
  end

  class GalleryObject

    attr_reader :site_root, :relative_name, :parent

    def initialize(site_root, relative_name, parent = nil)
      @site_root = site_root
      @relative_name = relative_name
      @parent = parent
      @full_name = File.join(@site_root, @relative_name)
    end

    def page(site, nodata = false)
      TheOnlyGalleryObjectPage.new(site, self, nodata)
    end

    def static_file(site)
      Jekyll::StaticFile.new(site, site_root, dir, base_name) if image? || video?
    end

    def url(site)
      page(site, true).url
    end

    def variant(size, force = false)
      fail 'variants are only for images' unless image?
      base = "variant_#{size}_#{File.basename(@full_name)}.jpg"
      rel = File.join(File.dirname(@relative_name), 'resized', base)
      full = File.join(@site_root, rel)
      Test::Magick.generate_resized(@full_name, full, size, force)
      self.class.new(@site_root, rel)
    end

    def thumbnail(size, force = false)
      fail 'thumbnails are only for images' unless image?
      base = "thumbnail_#{size}_#{File.basename(@full_name)}.jpg"
      rel = File.join(File.dirname(@relative_name), 'resized', base)
      full = File.join(@site_root, rel)
      if video_object
        overlay = File.join(File.dirname(__FILE__), 'overlay.png')
        Test::Magick.generate_video_thumbnail(@full_name, full, overlay, size, size, force)
      else
        Test::Magick.generate_thumbnail(@full_name, full, size, size, force)
      end
      self.class.new(@site_root, rel)
    end

    def static_files_resized(site, force = false)
      if image?
        [
          thumbnail(200, force).static_file(site),
          variant(1280, force).static_file(site),
        ]
      end
    end

    def pages(site)
      [page(site)] + (directories + media).map {|p| p.pages(site)}.flatten
    end

    def static_files(site, force = false)
      st = []
      st << static_file(site)
      st << static_files_resized(site, force)
      st << thumbnail_object.static_files(site) if video?
      st.flatten.compact + (directories + media).map {|p| p.static_files(site, force)}.flatten
    end


    def index_object
      children.select(&:index?).first
    end

    def index?
      exists? && File.basename(relative_name_no_ext) == 'index'
    end

    def exists?
      File.exists?(@full_name)
    end

    def dir
      File.dirname(@relative_name)
    end

    def base_name
      File.basename(@relative_name)
    end

    def directory?
      exists? && File.directory?(@full_name)
    end

    def image?
      exists? &&
        File.extname(@full_name) =~ /\.(png|jpe?g)$/i
    end

    def video?
      exists? &&
        File.extname(@full_name) =~ /\.(flv|mp4)$/i
    end

    def all_images
      images + directories.map{|d| d.all_images}.flatten
    end

    def media?
      (image? && video_object.nil?) || (video? && thumbnail_object)
    end

    def video_object
      fail "Not an image #{@relative_name}" unless image?
      related_object_with_ext(%w(mp4 flv MP4 FLV))
    end

    def thumbnail_object
      fail "Not a video #{@relative_name}" unless video?
      related_object_with_ext(%w(jpg jpeg png JPG JPEG PNG))
    end

    def related_object_with_ext(extenstions)
      extenstions.
        map{|ext| "#{relative_name_no_ext}.#{ext}"}.
        map{|rel_name| self.class.new(@site_root, rel_name)}.
        select(&:exists?).first
    end

    def relative_name_no_ext
      @relative_name.split('.')[0..-2].join('.')
    end

    def media_prev
      idx = @parent.media.find_index(self) - 1
      return nil if idx < 0
      @parent.media[idx]
    end

    def media_next
      idx = @parent.media.find_index(self) + 1
      return nil if idx >= @parent.media.count
      @parent.media[idx]
    end

    def images
      children.select(&:image?)
    end

    def media
      children.select(&:media?)
    end

    def videos
      children.select(&:video?)
    end

    def directories
      children.select(&:directory?)
    end

    def children
      #fail "Not a directory #{@relative_name}" unless directory?
      return [] unless directory?
      Dir.entries(@full_name).
        reject{|entry| entry =~ /^\./}.
        reject{|entry| entry == 'resized'}.sort.
        map{|entry| self.class.new(@site_root, File.join(@relative_name, entry), self)}
    end
  end

  class OverriddenPage < Jekyll::Page
    def initialize(site, base, dir, name)
      @original_name = name
      @original_dir = dir
      super(site, base, custom_dir, custom_name)
    end

    private

    def custom_template
      fail 'has to be overridden'
    end

    def custom_jekyll_page
      @custom_jekyll_page ||= Jekyll::Page.new(
        @site,
        @site.source,
        File.dirname(custom_template),
        File.basename(custom_template)
      )
    end

    def read_yaml(*args)
      self.data = custom_data.merge(custom_jekyll_page.data)
      self.content = custom_jekyll_page.content
    end

    def custom_data
      {}
    end

    def custom_dir
      @original_dir
    end

    def custom_name
      @original_name
    end
  end

  class TheOnlyGalleryObjectPage < OverriddenPage
    def initialize(site, gallery_object, nodata = false)
      @gallery_object = gallery_object
      @nodata = nodata
      super(site, gallery_object.site_root, nil, nil)
    end

    private

    def custom_name
      if @gallery_object.directory?
        'index.html'
      else
        "#{@gallery_object.base_name}.html"
      end
    end

    def custom_dir
      if @gallery_object.directory?
        File.join(@gallery_object.dir, @gallery_object.base_name)
      else
        @gallery_object.dir
      end
    end

    def custom_template
      file = if @gallery_object.directory?
        if @gallery_object.index_object
          File.join('_galleries/karola',@gallery_object.index_object.relative_name)
        else
          '_layouts/gallery-index.html'
        end
      elsif @gallery_object.video?
          '_layouts/gallery-single-video.html'
      elsif @gallery_object.image?
          '_layouts/gallery-single-image.html'
      else
        fail "Unknown page type #{@gallery_object.base_name}"
      end
    end

    def custom_data
      return {
        'title' => @gallery_object.base_name,
      } if @nodata

      {
        'title' => @gallery_object.base_name,
        'media' => @gallery_object.media.map do |m|
          thumbnail = m.video? ? m.thumbnail_object : m
          # require 'pry';binding.pry
          {
            'name' => m.base_name,
            'thumbnail_url' => thumbnail.thumbnail(200).static_file(site).destination(''),
            'page_url' => m.url(site)
          }
        end,
        'galleries' => @gallery_object.directories.map do |d|
          thumbnail = d.all_images.sample
          {
            'title' => d.page(site).data['title'],
            'name' => d.base_name,
            'thumbnail_url' => thumbnail.thumbnail(200).static_file(site).destination(''),
            'page_url' => d.url(site)
          }
        end,
      }.tap do |data|
        parents = []
        parent = @gallery_object.parent
        while parent
          parents << {
            'page_url' => parent.url(site),
            'title' => parent.page(site, true).data['title']
          } if parent.parent
          parent = parent.parent
        end
        data['parents'] = parents.reverse
        if @gallery_object.video?
          data.merge!(
            'video_url' => @gallery_object.static_file(site).destination(''),
            'image_url' => @gallery_object.thumbnail_object.variant(1280).static_file(site).destination('')
          )
        elsif @gallery_object.image?
          data.merge!(
            'image_url' => @gallery_object.variant(1280).static_file(site).destination(''),
            'fullsize_image_url' => @gallery_object.static_file(site).destination('')
          )
        end
      end
    end
  end


  class Generator < Jekyll::Generator
    def generate(site)
      go = GalleryObject.new(File.join(site.source, '_galleries/karola'), '.')
      go.pages(site).each do |p|
        site.pages << p
      end
      go.static_files(site).each do |s|
        site.static_files << s
      end
    end
  end
end
