$sg_games = $mongo.collection('sg_games')
$sg = $sampling_game = $mongo.collection('sampling_game')

get '/sg' do
  redirect '/sg/intro'  
end

get '/sg/intro' do
  $sg_games.delete_many
  erb :'sg/intro', default_layout
end

get '/sg/game' do
  sesh[:user_id] = pr[:user_id]
  game = $sg_games.update_id(pr[:game_id], {round: 0, turn: 0}, {upsert: true})
  user_ids = (game['user_ids'] || []).push(sesh[:user_id]).uniq.compact.sort
  $sg_games.update_id(pr[:game_id], {user_ids: user_ids, chosen_buttons: []})
  erb :'/sg/sg_game', default_layout
end

#game has user_ids, turn_id, round_num.
get '/sg/state' do  
  game = $sg_games.get(pr[:game_id])
  game['round'] ||= 0 
  game
end

get '/sg/move' do
  game = $sg_games.get(pr[:game_id])
  turn  = game[:turn]+1
  round = game[:round]
  chosen_buttons = game['chosen_buttons']
  chosen_buttons.push(pr[:box]) if pr[:phase] == 'choose'

  if turn >= game[:user_ids].size 
    turn  = 0 
    round = round+1
  else 
    
  end
  $sg_games.update_id(pr[:game_id], {turn: turn, round: round, chosen_buttons: chosen_buttons})
  
  {val: rand(10000)}
end