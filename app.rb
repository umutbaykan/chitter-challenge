require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'bcrypt'
require_relative 'lib/user'
require_relative 'lib/post'
require_relative 'helpers/helpers'

class ChitterApplication < Sinatra::Base
  enable :sessions
  helpers ApplicationHelpers

  configure do
    Time::DATE_FORMATS[:chitter] = "%F / %H:%M"
    register Sinatra::Flash
    register Sinatra::Reloader
    register Sinatra::ActiveRecordExtension
  end

  before do   
    if session[:user_id]
      @current_user = User.find(session[:user_id])
    end
  end

  get '/' do
    @posts = Post.includes(:children, :user)
             .order(created_at: :desc)
             .order("children_posts.created_at": :asc)
             .all
    erb :index
  end

  get '/login' do
    erb :login
  end

  post '/login' do
    username, plaintext_password = params[:username], params[:password]
    return_to_page_with_error("login", "Invalid input") unless validate(username, plaintext_password)
    user = User.find_by(username: username)
    return_to_page_with_error("login", "Invalid username or password") if user.nil? || BCrypt::Password.new(user.password_digest) != plaintext_password
    session[:user_id] = user.id
    return redirect('/')
  end

  get '/create_post' do
    ask_for_login
    erb :create_post
  end

  post '/create_post' do
    ask_for_login
    return_to_page_with_error("create_post", "Invalid input") unless validate(params[:content])
    create_post(current_time = params[:created_at])
    return redirect('/')
  end

  get '/reply/:id' do
    ask_for_login
    @original_post = Post.joins(:user).find(params[:id])
    erb :create_reply
  end

  post '/reply/:id' do
    ask_for_login
    return_to_page_with_error("reply/#{params[:id]}", "Invalid input") unless validate(params[:content])
    create_post(params[:id])
    return redirect('/')
  end
    
  get '/register' do
    erb :register
  end

  post '/register' do
    username, password, email, real_name = params[:username], params[:password], params[:email], params[:real_name]
    return_to_page_with_error("register", "Invalid input") unless validate(username, password, email, real_name)
    return_to_page_with_error("register", "Username or e-mail already exists!") if !!User.find_by(username: username) || !!User.find_by(email: email)
    new_user = User.new
    encrypted_password = BCrypt::Password.create(password)
    new_user.username, new_user.password, new_user.email, new_user.real_name = username, encrypted_password, email, real_name
    new_user.save
    session[:user_id] = new_user.id
    return redirect('/')
  end

  get '/logout' do
    session.clear
    return redirect('/')
  end

  not_found do
    erb :not_found
  end
end
