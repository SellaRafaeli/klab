before do
  x=1
#  bp
  z=2
end

# $sesh = $mongo.collection('sesh')

# $cur_sesh = {}

# def sesh
#   $cur_sesh
# end

# before do #on the way in - load the session from DB 
#   user_id = session[:user_id]
#   $cur_sesh = $sesh.get(user_id) || {}
# end

# after do #on the way out - save the session to DB
#   user_id = session[:user_id]
#   $sesh.update_id(user_id, $cur_sesh)
# end

#require 'rack/session/abstract/id'

# configure do
#     use Rack::Session::Pool, :key => 'session_id'
#   end
# session.options[:cookie_only] = false
# session.options[:defer] = true


NUM_CELLS        = 12 # 12
NUM_GAMES        = G = 2 #4
NUM_ROUNDS       = R = $prod ? 20 : 3
TRIALS_PER_ROUND = old_T = $prod ? 12 : 3
COINSIGN         = '$'
SHOWUP           = 1.6
EXCHANGE_RATIO   = 30
F                = 2

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
  }.hwia
end

def get_games_order
  subject_number    = sesh[:user_data][:subject_number].to_i
  game_combinations = [[1,2],[1,3],[1,4],[1,5],[1,6]]
  spot              = subject_number % game_combinations.size
  games             = game_combinations[spot]
  games
end

def save_data_to_db
  subj_num = sesh['user_data']['subject_number']
  data     = sesh.to_h.just('user_data','moves','game_lengths','game_random_rounds_chosen','game_payments_for_random_round_chosen','final_payment_str')  
  $togu.update_id(subj_num, data, upsert: true)
end

def get_cell_val(val1, probability1, val2)
  (rand < probability1) ? val1 : val2
end

def explore_cell(type)
  data = sesh[:consts]
  mh, c, pmh, ml = data[:MH], data[:C], data[:PMH], data[:ML]
  h, ph, l = data[:H], data[:PH], data[:L]
  if type.to_s == 'giveup'
    val_type = get_cell_val(:MH, pmh, :ML)
  else #type.to_s == 'try'
    val_type = get_cell_val(:H, ph, :L)
  end
end

def compute_feedback(game_num, type, existing_type, key_type)
  #guidance_val (f)
  feedback = 0
  if (game_num==2 && type.to_s=='giveup')
    feedback = -F
  elsif (game_num == 3 && existing_type && key_type== :L)
    feedback = -F
  elsif (game_num==4 && ((existing_type && key_type== :L) || (type.to_s=='giveup')))
    feedback = -F
  elsif (game_num==5 && !existing_type && type.to_s=='try')
    feedback = F
  elsif (game_num==6 && type.to_s=='try')
    feedback = F
  end
  feedback
end

def set_new_game
  sesh[:order]            = sesh[:order]+1
  game_num = sesh[:g]     = sesh[:games][sesh[:order]]
  round    = sesh[:round_number]     = 1
  sesh[:moves]["#{game_num}"]  = {}
  sesh[:moves]["#{game_num}"]["#{round}"] = []    
end

get '/togu/subjects' do
  protected!
  erb :'/togu/subjects', default_layout
end

get '/togu/subject_results/:id' do
  erb :'/togu/subject_results', default_layout
end

namespace '/togu' do 
  get '' do
    erb :'togu/consent', default_layout
  end

  get '/' do
    erb :'togu/consent', default_layout
  end

  get '/info' do
    session.clear
    erb :'togu/subject_number', default_layout
  end

  post '/start' do    
    $cur_sesh = {}
    sesh[:user_data] = params.just(:sex,:age,:prolific_id,:education,:income,:income_type,:location)
    session[:user_id] = sesh[:user_data]['subject_number'] = user_id = ($togu.count+1).to_s
    $togu.update_id(user_id, {}, upsert: true)
    sesh[:consts]    = togu_default_consts
    sesh[:games]     = get_games_order
    sesh[:moves]     = {}
    sesh[:order]     = -1
    sesh[:should_flip_order] = rand > 0.5 
    set_new_game
    
    erb :'togu/general_instructions', default_layout
  end

  get '/click_cell' do   

    type, key    = params[:type].to_s, params[:key].to_s
    existing_type= sesh[:cur_game_payoffs][type][key] 
    new_type     = explore_cell(type) if !existing_type
    key_type     = existing_type || new_type
    cell_val     = togu_default_consts[key_type]

    explore_cost = sesh[:consts][:C]
    val          = existing_type ? cell_val : cell_val - explore_cost

    sesh[:cur_game_payoffs][type][key] = key_type
    game_num               = sesh[:g]

    val_before_feedback = val
    feedback = compute_feedback(game_num, type, existing_type, key_type)
    
    val+=feedback

    md_key_type = ((key_type.in?([:H,:MH])) ? 1 : 0)
    md_explore  = (!existing_type ? 1 : 0)
    md_cost     = (existing_type ? 1 : 0)
    md_give_up  = (type.to_s == 'giveup' ? 1 : 0)
    md_explore_l= ((md_give_up == 0) && (md_explore == 1) && (md_key_type == 0)) ? 1 : 0 
    md_exploit_l= ((md_give_up == 0) && (md_explore == 0) && (md_key_type == 0)) ? 1 : 0 

    move_data = {
      key: key, 
      order: sesh[:order]+1, 
      g: sesh[:g], 
      r: sesh[:round_number], 
      t: params[:trial_number], 
      give_up: md_give_up,
      #type: type, 
      is_explore: md_explore, 
      orig_key_type: key_type, #:H, :MH, etc
      key_type: md_key_type,
      explore_l: md_explore_l,
      exploit_l: md_exploit_l,
      key_number: key.to_i,
      key_val: cell_val,      
      cost: md_cost,
      pay_no_feedback: val_before_feedback,
      feedback: feedback,     
      final_pay: val,
      val: val, 
      # val_before_feedback: val_before_feedback,
    }

    round= sesh[:round_number]
    sesh[:moves]["#{game_num}"]["#{round}"].push(move_data)
    {val: val, map: sesh[:cur_game_payoffs]}
  end

  get '/game_instructions' do    
    erb :'togu/game_instructions', default_layout
  end

  get '/game' do    
    sesh[:game_lengths]   ||= []
    sesh[:time_started]     = Time.now if sesh[:round_number] == 1
    sesh[:cur_game_payoffs] = {'giveup' => {}, 'try' => {}}.hwia
    erb :'togu/game', default_layout
  end

  get '/between_rounds' do
    sesh[:round_number] = sesh[:round_number]+1    
    sesh[:cur_game_payoffs] = {'giveup' => {}, 'try' => {}}.hwia
    redirect '/togu/next_game' if (sesh[:round_number] > NUM_ROUNDS) 
    
    sesh[:moves]["#{sesh[:g]}"]["#{sesh[:round_number]}"] = []

    erb :'togu/between_rounds', default_layout
  end

  get '/next_game' do
    sesh[:time_finished] = Time.now
    game_time = ((sesh[:time_finished]-sesh[:time_started])/60.0).round(2)
    sesh[:game_lengths].push(game_time)
    redirect '/togu/last_payment' if (sesh[:g] >= NUM_GAMES) 
    set_new_game
    erb :'togu/between_games', default_layout
  end

  get '/end_games' do
    erb :'togu/end_games', default_layout
  end

  get '/last_payment' do
    sesh[:time_finished] = Time.now   
    num_games = sesh[:moves].values #for future sella

    game_one                  = sesh[:moves].values[0]
    game_one_random_round_num = rand(game_one.values.size)
    game_one_rand_round       = game_one.values[game_one_random_round_num]
    game_one_rand_round_sum   = game_one_rand_round.mapo(:val).sum.to_f

    game_two                  = sesh[:moves].values[1]
    game_two_random_round_num = rand(game_two.values.size)
    game_two_rand_round       = game_two.values[game_two_random_round_num]
    game_two_rand_round_sum   = game_two_rand_round.mapo(:val).sum.to_f

    sum       =  game_one_rand_round_sum + game_two_rand_round_sum

    final_payment = [sum, SHOWUP].max

    sesh[:game_random_rounds_chosen] = [game_one_random_round_num+1,game_two_random_round_num+1]
    sesh[:game_payments_for_random_round_chosen] = [game_one_rand_round_sum,game_two_rand_round_sum]


    

    z = erb :'togu/last_payment', default_layout.merge(locals: {rand_round_from_game_one: game_one_random_round_num, rand_round_from_game_two: game_two_random_round_num, sum: sum})
    sesh[:final_payment_str] = z

    save_data_to_db
    z
  end

  get '/delete_all' do
    protected!
    $togu.delete_many
    redirect '/'
  end
end