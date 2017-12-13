$ex2 = $ex2results = $mongo.collection('ex2results')

T=6
E=7
ShowUp=1
PaySign='$'
ExchangeRate=5
MinimalPay=0.75

get '/ex2' do
  erb :'ex2/home', default_layout
end

get '/ex2/instructions' do
  session.clear 
  erb :'ex2/instructions', default_layout
end

get '/ex2/instructions_part2' do
  erb :'ex2/instructions_part2', default_layout
end

get '/ex2/start' do
  sesh[:subject_number] = pr[:subject_number].to_i || 1 
  
  if sesh[:subject_number] < 500
    group_num = ['a','b'].sample
  elsif sesh[:subject_number] < 1000
    group_num = ['c','d'].sample
  elsif sesh[:subject_number] < 1500
    group_num = ['e','f'].sample
  end

  sesh[:group_num] = group_num
  sesh[:flip] = [true,false].sample #if "flipped" then the left-hand side distribution will be for the right-hand side.
  
  sesh[:down] = [true,false].sample
  sesh[:colors] = ['lightblue','lightyellow','lightpink','purple'].sample(2)
  redirect '/ex2/step'
end

get '/ex2/step' do
  erb :'ex2/step', default_layout  
end

get '/ex2/part2' do
  sesh[:part2] = true
  erb :'ex2/step', locals: {part2: true}, layout: :layout
end 

def get_vals(group_num, flip)

  rand_prob = rand

  if group_num == 'a'
    left = -2
    right = (rand_prob < 0.1) ? -20 : 0
  elsif group_num == 'b'
    left = 2
    right = (rand_prob < 0.1) ? 20 : 0
  elsif group_num == 'c'    
    left = -2 
    right = (rand_prob < 0.1) ? 20 : 0
  elsif group_num == 'd'
    left = 0
    if (rand_prob < 0.05) 
      right = 10
    elsif (rand_prob >= 0.05) && (rand_prob < 0.1)
      right = -10
    else 
      right = 0
    end
  elsif group_num == 'e'    
    left = 2
    right = (rand_prob < 0.1) ? 20 : 0
  elsif group_num == 'f'    
    left = 0
    if (rand_prob < 0.05) 
      right = 10
    elsif (rand_prob >= 0.05) && (rand_prob < 0.1)
      right = -10
    else 
      right = 0
    end
  end

  if flip
    temp = left; left = right; right = temp
  end

  return left, right
end


get '/ex2/click' do 
  cur_step  = pr[:stepNum].to_i
  next_step = cur_step+1

  left, right = get_vals(sesh[:group_num], sesh[:flip])
  res = {left: left, right: right, stepNum: next_step}.hwia
  val = res[pr[:side]]
  
  if (sesh[:part2])
    res['done'] = true if cur_step >= T
    sesh[:moves_part2] ||= {}
    sesh[:moves_part2][cur_step] = [pr[:side],val]  
  else 
    sesh[:moves] ||= {}
    sesh[:moves][cur_step] = [pr[:side],val]  
    res['gotoPart2'] = true if cur_step >= E
  end
  
  res
end

get '/ex2/done' do
  user_actions = sesh.to_h.hwia
  
  random_part = [:moves,:moves_part2].sample
  random_move = user_actions[random_part].to_a.sample

  data = {
    user_actions: user_actions,
    random_part: (random_part == :moves) ? 1 : 2,
    random_move: random_move
  }
  $ex2results.update_id(sesh[:subject_number].to_s,data,{upsert:true})

  erb :'ex2/done', locals: {data: data}, layout: :layout
end

get '/ex2/results/?:id?' do  
  erb :'ex2/results', layout: :layout
end