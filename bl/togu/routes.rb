def togu_default_consts
  {
    C: 1,
    L: 1,
    ML: 1,
    H: 11,
    PH: 0.1,
    MH: 2,
    PMH: 0.5,
    F: 2
  }
end

def get_game_order
  if session[:user_data][:subject_number].to_i % 2 == 1
    games = [1] + [2,3,4].shuffle
  else
    games = [1] + [2,5,6].shuffle
  end
  games
end

def get_cell_val(val1, probability1, val2)
  (rand < probability1) ? val1 : val2
end

def explore_cell(type)
  data = sesh[:consts]
  mh, c, pmh, ml = data[:MH], data[:C], data[:PMH], data[:ML]
  h, ph, l = data[:H], data[:PH], data[:L]
  if type.to_sym == :giveup
    val = get_cell_val(mh-c, pmh, ml-c)
  else 
    val = get_cell_val(h-c, ph, l-c)
  end
end

namespace '/togu' do 
  get '' do
    erb :'togu/subject_number', default_layout
  end

  get '/' do
    erb :'togu/subject_number', default_layout
  end

  post '/start' do
    session[:user_data] = params.just(:subject_number,:sex,:age)
    session[:consts]    = togu_default_consts
    session[:games]     = get_game_order
    session[:g]         = 1
    session[:cur_game_payoffs] = {giveup: {}, try: {}}.hwia
    erb :'togu/general_instructions', default_layout
  end

  get '/click_cell' do    
    type, key    = params[:type], params[:key]
    existing_val = session[:cur_game_payoffs][type][key] 
    explore_cost = session[:consts][:C]
    val = existing_val || explore_cell(type) + explore_cost
    session[:cur_game_payoffs][type][key] = val
    {val: val}
  end

  get '/game_instructions' do
    erb :'togu/game_instructions', default_layout
  end

  get '/game' do
    erb :'togu/game', default_layout
  end

  get '/between_rounds' do
    erb :'togu/between_rounds', default_layout
  end

  get '/between_games' do
    erb :'togu/between_games', default_layout
  end

  get '/end_games' do
    erb :'togu/end_games', default_layout
  end
end