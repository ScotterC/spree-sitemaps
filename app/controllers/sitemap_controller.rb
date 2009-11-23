class SitemapController < Spree::BaseController
  def index
    config
    @root_taxons = Taxonomy.all.map &:root
    respond_to do |format|
      format.html { }
      format.xml  { render :layout => false, :template => 'sitemap/index.xml.erb' }
      format.text { render :text => [""].concat(Product.all.map {|p| product_path p}).map {|l| @public_dir + l}.join("\x0a") }
    end
  end

  def taxon_and_subtaxons(taxon)
    taxon_attributes = taxon.attributes
    taxon_attributes.delete("vectors")
    taxon_attributes["permalink"] = "/t/"+taxon_attributes["permalink"]
    [taxon_attributes, taxon.children.map{|t| taxon_and_subtaxons(t)} ]
  end

  def categories
    @result = Taxonomy.all.map do |taxonomy|
      taxon_and_subtaxons(taxonomy.root)
    end

    respond_to do |format|
      format.html { }
      format.text { render :layout => false, :text => YAML.dump(@result) }
      format.yaml { render :layout => false, :text => YAML.dump(@result) }
      format.json { render :layout => false, :text => JSON.dump(@result) }
    end
  end

  def products
    taxon_ids = params[:category_ids] && params[:category_ids].split(",")
    query    = params[:query]
    limit    = params[:limit].to_i
    order    = params[:order]
    offset   = params[:offset].to_i
    order = nil if order !~ /\w+ (asc|desc)/i

    if taxon_ids &&
      @result = Product.available.taxons_id_in_tree_any(taxon_ids)
    elsif query
      @result = Product.available.scoped_by_tsearch(query)
    else
      @result = Product.available
    end
    @result = @result.all(:limit => limit, :order => order, :offset => offset)
    
    @result.map!{|p|
      a = p.attributes;
      a.delete("vectors");
      a["permalink"] = "/products/"+a["permalink"];
      if p.images.first
        a["image_url"] = {}
        {
          :mini => '48x48>',
          :small => '100x100>',
          :product => '240x240>',
          :large => '600x600>'
        }.each_pair do |size, res|
          a["image_url"][res.chop] =  p.images.first.attachment.url(size)
        end
      end
      a['default_variant_id'] = p.default_variant.id
      a["price"] = p.price
      a
    }

    respond_to do |format|
      format.html { }
      format.text { render :layout => false, :text => YAML.dump(@result) }
      format.yaml { render :layout => false, :text => YAML.dump(@result) }
      format.json { render :layout => false, :text => JSON.dump(@result) }
    end
  end

  # showing the sitemap of a specific taxon, to cut down on sitemap size
  def show
    config
    @taxon = Taxon.find_by_permalink(params[:id].join("/") + "/")
    
    if @taxon.nil?
      render :nothing => true, :status => "404 Not Found" and return
    end

    respond_to do |format|
      format.html { }
      format.xml  { render :layout => false, :template => 'sitemap/show.xml.erb' }
      format.text { render :text => @taxon.products.map(&:name).join('\n') }		##?
    end
  end

  def home
    config
    respond_to do |format|
      format.xml  { render :layout => false, :template => 'sitemap/home.xml.erb' }
    end
  end

  private
  def config
    # not using :site_url because localhost etc is more useful in dev mode
    @public_dir = url_for( :controller => '/' ).sub(%r|/\s*$|, '')

    # only show a product once in the whole sitemap
    @allow_duplicates = false # TODO: config setting

    # default to this to avoid penalties for lack of changes
    @change_freq = 'monthly'
  end


end
