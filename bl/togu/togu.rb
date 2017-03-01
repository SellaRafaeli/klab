NUM_CELLS        = 2 # 12
NUM_GAMES        = G = 2
NUM_ROUNDS       = R = 2 #20
TRIALS_PER_ROUND = T = 2 #12number of trials per round.
COINSIGN         = '$'
SHOWUP           = 1.0
EXCHANGE_RATIO   = 0.5

$togu = $mongo.collection('togu')

def togu_default_consts
  {
    C: 1,
    L: 1,
    ML: 1,
    H: 11,
    PH: 0.1,
    MH: 2,
    PMH: 0.5,
    F: 2,
  }
end

def get_games_order
  if session[:user_data][:subject_number].to_i % 2 == 1
    games = [1] + [2,3,4].shuffle
  else
    games = [1] + [2,5,6].shuffle
  end
  games
end

def save_data_to_db
  subj_num = sesh['user_data']['subject_number']
  data     = sesh.to_h.just('user_data','moves')  
  $togu.update_id(subj_num, data, upsert: true)
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

def set_new_game
  sesh[:order]            = sesh[:order]+1
  game_num = sesh[:g]     = sesh[:games][sesh[:order]]
  round    = sesh[:round_number]     = 1
  sesh[:moves]["game-#{game_num}"]  = {}
  sesh[:moves]["game-#{game_num}"]["round-#{round}"] = []
  sesh[:cur_game_payoffs] = {giveup: {}, try: {}}.hwia
end

get '/togu/subjects' do
  erb :'/togu/subjects', default_layout
end

get '/togu/subject_results/:id' do
  erb :'/togu/subject_results', default_layout
end

namespace '/togu' do 
  get '' do
    erb :'togu/subject_number', default_layout
  end

  get '/' do
    erb :'togu/subject_number', default_layout
  end

  post '/start' do
    sesh.clear
    sesh[:user_data] = params.just(:subject_number,:sex,:age)
    sesh[:consts]    = togu_default_consts
    sesh[:games]     = get_games_order
    sesh[:moves]     = {}
    sesh[:order]     = -1
    set_new_game
    
    erb :'togu/general_instructions', default_layout
  end

  get '/click_cell' do    
    type, key    = params[:type], params[:key]
    existing_val = sesh[:cur_game_payoffs][type][key] 
    explore_cost = sesh[:consts][:C]
    val = existing_val || explore_cell(type) + explore_cost
    sesh[:cur_game_payoffs][type][key] = val

    game_num               = sesh[:g]
    move = {type: type, key: key, val: val}
    round= sesh[:round_number]
    sesh[:moves]["game-#{game_num}"]["round-#{round}"].push(move)
    {val: val}
  end

  get '/game_instructions' do
    erb :'togu/game_instructions', default_layout
  end

  get '/game' do
    erb :'togu/game', default_layout
  end

  get '/between_rounds' do
    sesh[:round_number] = sesh[:round_number]+1    
    redirect '/togu/next_game' if (sesh[:round_number] > NUM_ROUNDS) 
    
    sesh[:moves]["game-#{sesh[:g]}"]["round-#{sesh[:round_number]}"] = []
    erb :'togu/between_rounds', default_layout
  end

  get '/next_game' do
    redirect '/togu/last_payment' if (sesh[:g] > NUM_GAMES) 
    set_new_game
    erb :'togu/between_games', default_layout
  end

  get '/end_games' do
    erb :'togu/end_games', default_layout
  end

  get '/last_payment' do
    save_data_to_db
    rand_game = sesh[:moves].keys.sample
    rand_round= sesh[:moves][rand_game].keys.sample
    sum       = sesh[:moves][rand_game][rand_round].mapo(:val).sum.to_f
    erb :'togu/last_payment', default_layout.merge(locals: {rand_game: rand_game, rand_round: rand_round, sum: sum}) 
  end
end