$ex2 = $ex2results = $mongo.collection('ex2results')

T=5
E=7
ShowUp=1
PaySign='$'
ExchangeRate=5
MinimalPay=0.75

get '/ex2_info' do
  {
    T: T, E: E, show_up: ShowUp, pay_sign: PaySign, minimal_pay: MinimalPay
  }
end

get '/ex2' do
  erb :'ex2/home', default_layout
end

get '/ex2/instructions' do
  session.clear 
  erb :'ex2/instructions', default_layout
end

get '/ex2/instructions_part2' do
  sesh[:stepNum] = 0
  erb :'ex2/instructions_part2', default_layout
end

get '/ex2/start' do
  sesh[:subject_number] = pr[:subject_number].to_i || 1 
  group_num = [12,21,13,31,23,32].sample
  sesh[:group_num] = group_num
  sesh[:flip] = [true,false].sample #if "flipped" then the left-hand side distribution will be for the right-hand side.
  
  #sesh[:down] = [true,false].sample
  sesh[:colors] = ['lightblue','lightyellow','lightpink','purple'].shuffle
  redirect '/ex2/step'
end

get '/ex2/step' do
  erb :'ex2/step', default_layout  
end

get '/ex2/part2' do
  sesh[:part2] = true
  erb :'ex2/step', locals: {part2: true}, layout: :layout
end 

def potential_risky_val(group_num, cur_step)
  group_num = sub_group_num(group_num, cur_step)
  z = '+10'
  z = '-20' if group_num == 1
  z = '20' if group_num == 2
  return z.to_s
end

def sub_group_num(group_num, cur_step)
  if (cur_step.to_i) % 2 == 0
    group_num = group_num / 10
  else 
    group_num = group_num % 10
  end
end

def get_vals(group_num, flip, cur_step)
  rand_prob = rand

  group_num = sub_group_num(group_num, cur_step)

  if group_num == 1
    left = -2
    right = (rand_prob < 0.1) ? -20 : 0
    # right = -20
  elsif group_num == 2
    left = 2
    right = (rand_prob < 0.1) ? 20 : 0
    # right = 20
  else # group_num == 3
    left = 0
    if (rand_prob < 0.05) 
      right = 10
    elsif (rand_prob >= 0.05) && (rand_prob < 0.1)
      right = -10
    else 
      right = 0
    end
    # right = -10
  end

  if flip
    temp = left; left = right; right = temp
  end

  return left, right
end

get '/ex2/estimate' do 
  sesh[:estimates] ||= []
  sesh[:estimates].push(pr[:estimate])
  {msg: "ok"}
end

get '/ex2/click' do 
  cur_step  = sesh[:stepNum].to_i
  next_step = sesh[:stepNum] = sesh[:stepNum].to_i+1

  left, right = get_vals(sesh[:group_num], sesh[:flip], cur_step)
  res = {left: left, right: right, stepNum: next_step}.hwia
  val = res[pr[:side]]
  
  if (sesh[:part2])
    res['done'] = true if next_step >= E
    sesh[:moves_part2] ||= {}
    sesh[:moves_part2][cur_step] = [pr[:side],val]  
  else 
    sesh[:moves] ||= {}
    sesh[:moves][cur_step] = [pr[:side],val]  
    res['gotoPart2'] = true if next_step >= T
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

  data[:rand_payoff] = data[:random_move][1][1] 
  $ex2results.update_id(sesh[:subject_number].to_s,data,{upsert:true})

  erb :'ex2/done', locals: {data: data}, layout: :layout
end

get '/ex2/results/?:id?' do  
  erb :'ex2/results', layout: :layout
end