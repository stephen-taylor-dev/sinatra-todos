require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Get a list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Edit an existing todo list page
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# update existing todo list
post "/lists/:list_id/" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete list of todos
post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo = params[:todo].strip

  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo, completed: false }
    session[:success] = "Todo was added"
    redirect "lists/#{@list_id}"
  end
  # erb :list, layout: :layout ?? Why does this work
end

# Delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i

  list[:todos].delete_at(todo_id)
  session[:success] = "The todo item has been deleted."
  redirect "/lists/#{@list_id}"
end

# Set status of task
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  completed = params[:completed] == "true"

  list[:todos][todo_id][:completed] = completed
  session[:success] = "The todo item has been updated."

  redirect "/lists/#{@list_id}"
end

post "/lists/:list_id/complete" do
  @list_id = params[:list_id].to_i
  list = session[:lists][@list_id]

  list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed"

  redirect "/lists/#{@list_id}"
end




# Return an error message if list name is invalid. Return nil if valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique"
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

helpers do
  def list_complete?(list)
    return false if list[:todos].empty?
    todos_remaining(list) == 0
  end

  def todos_count(list)
    list[:todos].size  
  end

  def todos_remaining(list)
    list[:todos].select {|todo| !todo[:completed] }.size
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  # def sort_items(items, &block)
  #   incomplete_items = {}
  #   complete_items = {}

  #   items.each_with_index do |item, index|
  #     incomplete_items, complete_items = yield(item, index)
  #   end

  #   incomplete_items.each(&block)
  #   complete_items.each(&block)
  # end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition {|list| list_complete?(list)}

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition {|todo| todo[:completed]}

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end