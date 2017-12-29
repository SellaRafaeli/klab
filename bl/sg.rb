$sg = $sampling_game = $mongo.collection('sampling_game')

get '/sg' do
  erb :sg, default_layout
end

get '/sg/state' do
  {val: rand(10000)}
end

get '/sg/move' do
  {val: rand(10000)}
end