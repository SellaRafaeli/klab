$ex2 = $ex2results = $mongo.collection('ex2results')

T=200
E=100
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
  sesh[:subject_number] = pr[:subject_number]
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

get '/ex2/click' do 
  cur_step  = pr[:stepNum].to_i
  next_step = cur_step+1

  res = {left: rand(1000).to_s, right: rand(10).to_s, stepNum: next_step}.hwia
  val = res[pr[:side]]
  
  if (sesh[:part2])
    res['done'] = true if cur_step >= 2
    sesh[:moves_part2] ||= {}
    sesh[:moves_part2][cur_step] = [pr[:side],val]  
  else 
    sesh[:moves] ||= {}
    sesh[:moves][cur_step] = [pr[:side],val]  
    res['gotoPart2'] = true if cur_step >= 1
  end
  
  res
end

get '/ex2/done' do
  user_actions = sesh.to_h.hwia
  random1 = user_actions[:moves].to_a.sample[1][1]
  random2 = user_actions[:moves_part2].to_a.sample[1][1]
  random = [random1,random2].sample

  data = {
    user_actions: user_actions,
    random_move: random
  }
  $ex2results.update_id(sesh[:subject_number].to_s,data,{upsert:true})

  erb :'ex2/done', locals: {data: data}, layout: :layout
end

get '/ex2/results/?:id?' do  
  erb :'ex2/results', layout: :layout
end