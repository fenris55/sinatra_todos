require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

def load_list(id)
  list = session[:lists].find { |list | list[:id] == id }
  return list if list 

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end



helpers do
  def list_complete?(list)
    list[:todos].size.positive? && remaining_todos(list).zero?
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def list_size(list)
    list[:todos].size
  end

  def remaining_todos(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def next_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
  end

  def next_element_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# get all lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# return error message if name is invalid, return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# create new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect "/lists"
  end
end

# view a single todo list
get '/lists/:id' do
  id = params[:id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# edit name of an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# update new name of existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# remove list from lists
post '/lists/:id/destroy' do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = 'The list has been deleted.'
  if env["HTML_X_REQUESTED_WITH"] =="XMLHttpRequest"
    "/lists"
  else
    redirect '/lists'
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo name must be between 1 and 100 characters.'
  end
end

# add a new todo
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }
    
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# delete a single todo
post '/lists/:list_id/todos/:id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject!{ |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# update status of todo
post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == 'true'
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo_completed = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# mark all todos as done
post '/list/:id/complete_all' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end

set :session_secret, SecureRandom.hex(32)
