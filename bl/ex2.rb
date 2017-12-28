require 'csv'

$ex2 = $ex2results = $mongo.collection('ex2results')

if $prod
  T=200
  E=100
else
  T=3
  E=3
end
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

get '/ex2/all_payments' do
  content_type 'application/csv'
  attachment 'payoffs.csv'
  csv_string = CSV.generate do |csv|
    csv << ["prolific_id", "payoff"]
    $ex2results.all.each {|r| csv << ["#{r['_id']}", "#{r['zzz']}"]}
  end  
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
  sesh[:subject_number] = pr[:subject_number].to_i 
  sesh[:age]            = pr[:age].to_i
  sesh[:gender]         = pr[:gender]
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
  z = ['+10','-10'].sample
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
    rare_asked = -20
    # right = -20
  elsif group_num == 2
    left = 2
    right = (rand_prob < 0.1) ? 20 : 0
    rare_asked = 20
    # right = 20
  else # group_num == 3
    left = 0
    if (rand_prob < 0.05) 
      right = 10
      rare_asked = 10
    elsif (rand_prob >= 0.05) && (rand_prob < 0.1)
      right = -10
      rare_asked = -10
    else 
      rare_asked = 10
      right = 0
    end
    # right = -10
  end

  if flip
    temp = left; left = right; right = temp
  end

  return left, right, group_num, rare_asked
end

get '/ex2/estimate' do 
  sesh[:estimates] ||= []
  sesh[:estimates].push(pr[:estimate])
  {msg: "ok"}
end

get '/ex2/click' do 
  cur_step  = sesh[:stepNum].to_i
  next_step = sesh[:stepNum] = sesh[:stepNum].to_i+1

  left, right, problem_num, rare_asked = get_vals(sesh[:group_num], sesh[:flip], cur_step)
  res = {left: left, right: right, stepNum: next_step}.hwia
  val = res[pr[:side]]
  other_side = (pr[:side] == 'left') ? 'right' : 'left'
  is_top = (cur_step % 2 == 0) ? 1 : 0
  p_rare_asked = (problem_num == 3) ? 0.05 : 0.1
  risky = ((pr[:side] == 'right') && sesh[:flip]) || ((pr[:side] == 'left') && !sesh[:flip])
  risky = risky ? 1 : 0
  estimate = pr[:estimate].to_f / 100 
  estimation_score = (1-(estimate.to_f-p_rare_asked)**2).round(2)

  if !sesh[:part2]
    rare_asked = 'n/a'
    p_rare_asked= 'n/a'
    estimate='n/a'
    estimation_score='n/a'
  end

  move_data = {
    condition: sesh[:group_num].to_i % 3,
    problem_num: problem_num,
    top: is_top,
    safe_right: !!sesh[:flip],
    trial: cur_step+1,
    choice_side: pr[:side],
    risk: risky,
    payoff: val,
    forgone: res[other_side],
    rare_asked: rare_asked,
    p_rare_asked: p_rare_asked,
    estimation: estimate,
    estimation_score: estimation_score
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

# <!-- 
# XXX is the payoff the participant obtained in the one trial randomly selected (out of all 300 trails) divided by ExchangeRate.
# For example (assuming ExchangeRate=5), if trial number 2 was randomly selected, the obtained payoff in this trial was +20 so XXX=4.

# YYY=EstimationScore the participant obtained in the one randomly selected estimation (out of trials 201-300).
# For example, if the estimation trial that was randomly selected was trial 202, EstimationScore at this trial was 0.99 so YYY=0.99

# ZZZ=ShowUp+XXX+YYY.
# In the example above (assuming ShowUp=1), ZZZ=4.99 
# So the sentence will be 
# “…your final payment is 4.99 $.”

# Important! There should be another variable MinimalPay, so that if ZZZ<MinimalPay then ZZZ=MinimalPay
#  -->

get '/ex2/done' do
  #bp
  user_actions = sesh.to_h.hwia
  
  random_part = [:moves,:moves_part2].sample
  random_part = :moves
  random_move = user_actions[random_part].to_a.sample
  random_move = user_actions[random_part].to_a[1]
  

  random_estimate = random_part2 = user_actions[:moves_part2].to_a.sample[1][2]['estimation_score'] rescue rand(100)

  data = {
    user_actions: user_actions,
    random_part: (random_part == :moves) ? 1 : 2,
    random_move: random_move
  }

  data[:rand_payoff] = data[:random_move][1][1] / ExchangeRate.to_f rescue 0
  
  xxx = data[:rand_payoff]
  yyy = random_estimate
  zzz = xxx + yyy + ShowUp
  if zzz < MinimalPay 
    zzz = MinimalPay
  end

  data[:yyy] = yyy
  data[:zzz] = zzz.round(2)
  $ex2results.update_id(sesh[:subject_number].to_s,data,{upsert:true})

  erb :'ex2/done', locals: {data: data}, layout: :layout
end

get '/ex2/results/?:id?' do  
  erb :'ex2/results', layout: :layout
end