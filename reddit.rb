%w{sinatra sinatra/flash data_mapper haml sinatra/reloader omniauth-twitter}.each { |lib| require lib}

use OmniAuth::Builder do
  provider :twitter, 'C7uRLNAIj6IgLbkka9Mbw', '8m1FoCgdjQ2e5CYA2bwymR5wuKWPyf4NxIE4F5MIE'
end

DataMapper::setup(:default,"sqlite3://#{Dir.pwd}/example.db")

class Link
  include DataMapper::Resource
  property :id, Serial
  property :session, String, :required => true 
  property :presenter, Text, :required => true #, :format => :url 
  property :points, Integer, :default => 0
  property :created_at, Time

  has n, :votes

  attr_accessor :score

  def calculate_score
  	time_elapsed = (Time.now - self.created_at) / 3600
   	self.score = ((self.points-1) / (time_elapsed+2)**1.8).real
  end

  def self.all_sorted_desc
    self.all.each { |item| item.calculate_score }.sort { |a,b| a.score <=> b.score }.reverse
  end
end

class Vote
  include DataMapper::Resource
  property :id, Serial
  property :username, String
  property :created_at, Time

  belongs_to :link

  validates_uniqueness_of :username, :scope => :link_id, :message => "You have already voted for this link."
end

DataMapper.finalize.auto_upgrade!

configure do
  enable :sessions
end
 
helpers do
  def admin?
    session[:admin]
  end

  def link_to(url,text=url,opts={})
    attributes = ""
    opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
    "<a href=\"#{url}\" #{attributes}>#{text}</a>"
  end
end
 
get '/login' do
  redirect to("/auth/twitter")
end

get '/auth/twitter/callback' do
  env['omniauth.auth'] ? session[:admin] = true : halt(401,'Not Authorized')
  session[:admin] = true
  session[:username] = env['omniauth.auth']['info']['name']
  flash[:login] = "Hi #{session[:username]}"
  redirect "/"
end

get '/auth/failure' do
  params[:message]
end
 
get '/logout' do
  session[:admin] = nil
  flash[:logout] = "You are now logged out"
  redirect back
end

get '/' do 
	@links = Link.all :order => :id.desc
  haml :index
end

get '/hot' do
	@links = Link.all_sorted_desc
	haml :index	
end

post '/' do
  Link.create(:session => params[:session], :presenter => params[:presenter], :created_at => Time.now)
  redirect back
end

#put '/:id/vote/:type' do 
#  if params[:type].to_i.abs == 1
#    l = Link.get params[:id]
#    l.update(:points => l.points + params[:type].to_i)
#  end
#  redirect back
#end 

put '/:id/vote/:type' do
  if session[:admin] 
    if params[:type].to_i.abs == 1
      l = Link.get params[:id]
      if l.votes.new(:username => session[:username]).save
        l.update(:points => l.points + params[:type].to_i)
      else
        flash[:overdone] = "Sorry, you've already voted for this one."
      end
    end
  else
    flash[:vote] = "You need to log in to vote."
  end
  redirect back
end 

__END__

@@ layout
%html
  %head
    %link(rel="stylesheet" href="/css/bootstrap.css")
    %link(rel="stylesheet" href="/css/style.css")
  %body
    .container
      #main
        .title #vBrownBag Tech Talk Voting
        .options  
          %a{:href => ('/')} New 
          | 
          %a{:href => ('/hot')} Hot
          |
          - if session[:admin]
            = link_to '/logout', 'Logout'
          - else
            = link_to '/login', 'Log in with Twitter'
        = yield

@@ index
#links-list 
  -@links.each do |l| 
    .row
      .span3
        %span.span
          %form{:action => "#{l.id}/vote/1", :method => "post"}
            %input{:type => "hidden", :name => "_method", :value => "put"}
            %input{:type => "submit", :value => "⇡"}
        %span.points
          #{l.points}
        %span.span
          %form{:action => "#{l.id}/vote/-1", :method => "post"}
            %input{:type => "hidden", :name => "_method", :value=> "put"}
            %input{:type => "submit", :value => "⇣"}        
      .span6
        %span.link-title
          %p #{l.session} | #{l.presenter}

#add-link
  %form{:action => "/", :method => "post"}
    %input{:type => "text", :name => "session", :placeholder => "Session"}
    %input{:type => "text", :name => "presenter", :placeholder => "Presenter"}
    %input{:type => "submit", :value => "Submit"} 
