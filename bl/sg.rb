$sg_games = $mongo.collection('sg_games')
$sg = $sampling_game = $mongo.collection('sampling_game')
$sg_moves = $mongo.collection('sg_moves')

def get_box_val(box_num,phase)
  [10,20].sample
end

def record_sg_move(data)
  rd = data
  rd[:user_id] = sesh[:user_id]
  rd['_id'] = nice_id
  $sg_moves.add(rd)
end

get '/sg_admin' do
  erb :'/sg/sg_admin', default_layout 
end

get '/sg/clear' do  
  $sg_games.delete_many
  {msg: 'ok'}
end

get '/sg' do
  erb :'/sg/home', default_layout  
end

get '/sg/intro' do
  $sg_games.delete_many
  erb :'sg/intro', default_layout
end

get '/sg/game' do
  sesh[:user_id] = pr[:user_id]
  game = $sg_games.update_id(pr[:game_id], {}, {upsert: true})
  user_ids = (game['user_ids'] || []).push(sesh[:user_id]).uniq.compact.sort
  if !game['round'] 
    $sg_games.update_id(pr[:game_id], {cur_turn: user_ids[0], round: 0, turn: 0, chosen_buttons: [], users_chosen: []})
  end
  
  $sg_games.update_id(pr[:game_id], {user_ids: user_ids})
  erb :'/sg/sg_game', default_layout
end

#game has user_ids, turn_id, round_num.
get '/sg/state' do  
  game = $sg_games.get(pr[:game_id])
  game['round'] ||= 0 
  game
end

get '/sg/move' do
  game  = $sg_games.get(pr[:game_id])
  turn  = game[:turn]+1
  round = game[:round]
  phase = pr[:phase] == 'choose' ? 'choose' : 'sample' 
  chosen_buttons = game['chosen_buttons']
  user_ids = game['user_ids']

  users_chosen = game['users_chosen']
  if pr[:phase] == 'choose'
    chosen_buttons.push(pr[:box]) 
    users_chosen += [sesh[:user_id]]    
  end

  remaining_users = user_ids - users_chosen
  
  val = get_box_val(pr[:box],phase)

  if remaining_users.size == 0
    turn  = 0 
    round = round+1
    chosen_buttons = []
    users_chosen = [] 
    cur_turn = user_ids[0]
  else 
    cur_turn = remaining_users[turn % remaining_users.size]  
  end

  game = $sg_games.update_id(pr[:game_id], {turn: turn, round: round, chosen_buttons: chosen_buttons,cur_turn: cur_turn, users_chosen: users_chosen})
  record_sg_move(game)
  {val: phase+" "+val.to_s, game: game}
end