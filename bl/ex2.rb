$ex2 = $ex2results = $mongo.collection('ex2results')

T=5
E=7
# T=200 
# E=100
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
  sesh[:colors] = ['lightblue','lightyellow','fuchsia','orange'].shuffle

  redirect '/ex2/step'
end

get '/ex2/step' do
  #return erb :'ex2/step', locals: {part2: true}, layout: :layout
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

  return left, right, group_num
end

get '/ex2/estimate' do 
  sesh[:estimates] ||= []
  sesh[:estimates].push(pr[:estimate])
  {msg: "ok"}
end

# ID, age, gender (1=male; 0=female), condition (1/2/3), problem (1/2/3), top (1=top; 0=bottom), SafeRight (1=the safe option is to the right; 0=else), trial, ChoiceSide (left=L; right=R), risk (1=risky key was selected; 0=safe key was selected), payoff, forgone, RareAsked (the rare outcome that the participant was asked to estimate its probability to occur), PrareAsked (probability to get the rare outcome), Estimation (the value that was typed in the text box divided by 100. For example if 50 was typed, then Estimation=0.5), EstimationScore [the calculation is as follows: EstimationScore=1-(Estimation-PrareAsked)^2]

# So after this screen the line that should be written is (assuming ID=1, age=26, gender=female, estimation=50):

# 1, 26, 0, 1, 2, 0, 0, 201, R, 1, 20, 2, 20, 0.1, 0.5, 0.84 

get '/ex2/click' do 
  cur_step  = sesh[:stepNum].to_i
  next_step = sesh[:stepNum] = sesh[:stepNum].to_i+1

  left, right, problem_num = get_vals(sesh[:group_num], sesh[:flip], cur_step)
  res = {left: left, right: right, stepNum: next_step}.hwia
  val = res[pr[:side]]
  other_side = (pr[:side] == 'left') ? 'right' : 'left'
  is_top = (cur_step % 2 == 0) ? 1 : 0
  move_data = {
    condition: sesh[:group_num].to_i % 3,
    problem_num: problem_num,
    top: is_top,
    safe_right: !!sesh[:flip],
    trial: cur_step+1,
    choice_side: pr[:side],
    risk: 'n/a',
    payoff: val,
    forgone: res[other_side],
    rare_asked: 'n/a',
    p_rare_asked: 'n/a',
    estimation: 'tbd',
    estimation_score: 'tbd'
  }
  
  if (sesh[:part2])
    res['done'] = true if next_step >= E
    sesh[:moves_part2] ||= {}
    sesh[:moves_part2][cur_step] = [pr[:side],val,move_data]  
  else 
    sesh[:moves] ||= {}
    sesh[:moves][cur_step] = [pr[:side],val,move_data]  
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