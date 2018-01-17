$sg_games = $mongo.collection('sg_games')
$sg = $sampling_game = $mongo.collection('sampling_game')
$sg_moves = $mongo.collection('sg_moves')

def get_box_val(round_num,opt_num,phase)
  $sg_values ||= SimpleSpreadsheet::Workbook.read("sg_values.xlsx") 
  table = $sg_values

  col_offset_from_excel_start = 3
  ev_offset_from_opt_start= 5
  ev_col = col_offset_from_excel_start + (ev_offset_from_opt_start * opt_num)

  plow_offset_from_ev   = -1
  low_offset_from_ev    = -2
  phigh_offset_from_ev  = -3
  high_offset_from_ev   = -4
  
  row_offset_from_excel_start = 2
  row = round_num + row_offset_from_excel_start

  if phase == 'sample' 
    phigh  = table.cell(row,ev_col+phigh_offset_from_ev)
    vhigh  = table.cell(row,ev_col+high_offset_from_ev)
    vlow   = table.cell(row,ev_col+low_offset_from_ev)
    x      = rand
    if x < phigh
      res = vhigh
    else 
      res = vlow
    end
  else  # phase == 'choose'      
    res = table.cell(row,ev_col)
  end

  res
rescue 
  -1 
end

def record_sg_move(data)
  rd = data
  rd[:user_id] = sesh[:user_id]
  rd['_id'] = nice_id
  $sg_moves.add(rd)
end

def get_btns_order
  [1,2,3,4].shuffle
end

def get_random_roles(round_num = 0)
  all = [1,2,3,4]
  lca = all.sample(2)
  lcb = all - lca
  [all,lca,lcb].rotate(round_num)
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
  #$sg_games.delete_many
  sesh.clear  
  erb :'sg/intro', default_layout
end

get '/sg/instructions' do
  [:user_id, :age, :gender, :game_id].each {|field| sesh[field] = pr[field] }
  erb :'sg/instructions', default_layout
end

get '/sg/game' do
  [:user_id, :age, :gender, :game_id].each {|field| sesh[field] ||= pr[field] }
  game_id = sesh[:game_id] || pr[:game_id]
  
  game = $sg_games.update_id(game_id, {}, {upsert: true})
  user_ids = (game['user_ids'] || []).push(sesh[:user_id]).uniq.compact.sort
  rounds_order = (0..89).to_a.shuffle
  if !game['round'] 
    $sg_games.update_id(game_id, {cur_turn: user_ids[0], round: 0, turn: 0, chosen_buttons: [], users_chosen: [], roles: get_random_roles(0), btns_order: get_btns_order, rounds_order: rounds_order})
  end
  
  $sg_games.update_id(game_id, {user_ids: user_ids})

  erb :'/sg/sg_game', default_layout
end

#game has user_ids, turn_id, round_num.
get '/sg/state' do
  game = $sg_games.get(sesh[:game_id])
  game['game_id'] = game['_id']
  game['round'] ||= 0 
  game['game_over'] = game['round'] > get_setting(:sampling_game_nrounds).to_i - 1
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
  opt_num = game[:btns_order][pr[:box].to_i-1]
  row_num = game[:rounds_order][round]
  val = get_box_val(row_num,opt_num,phase)

  if remaining_users.size == 0
    turn           = 0 
    round          = round+1    
    chosen_buttons = []
    users_chosen   = []
    btns_order     = get_btns_order
    cur_turn       = user_ids[0]
    roles          = get_random_roles(round)    
  else 
    cur_turn = remaining_users[turn % remaining_users.size]  
    roles    = game['roles']
  end

  game = $sg_games.update_id(pr[:game_id], {turn: turn, round: round, chosen_buttons: chosen_buttons,cur_turn: cur_turn, users_chosen: users_chosen, roles: roles})

  record_sg_move(game)
  {val: val.to_s, game: game}
end

get '/sg/game_over' do
  erb :'sg/game_over', default_layout
end